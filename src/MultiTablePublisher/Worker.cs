using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Extensions.ManagedClient;
using MultiTablePublisher.Models;
using MultiTablePublisher.Services;
using System.Text.Json;

namespace MultiTablePublisher
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IConfiguration _configuration;
        private SourceTableConfiguration _sourceConfig = null!;
        private IManagedMqttClient _mqttClient = null!;
        private int _configCheckIntervalSeconds = 30; // Check for config changes every 30 seconds

        public Worker(ILogger<Worker> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Multi-Table Publisher started at: {Time}", DateTimeOffset.UtcNow);
            _logger.LogInformation("Auto-restart enabled - checking for config changes every {Interval}s", _configCheckIntervalSeconds);

            // Load configuration first to get MQTT broker settings
            await LoadConfigurationAsync(stoppingToken);

            // Initialize MQTT client once with loaded configuration
            await InitializeMqttClientAsync(stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                // Reload source configuration for changes
                await LoadConfigurationAsync(stoppingToken);

                // Get enabled sources
                var enabledSources = _sourceConfig.Sources.Where(s => s.Enabled).ToList();

                _logger.LogInformation(
                    "Configuration loaded - Enabled sources: {Count}, Parallel processing: {Parallel}",
                    enabledSources.Count,
                    _sourceConfig.Global_Settings.Enable_Parallel_Processing);

                foreach (var source in enabledSources)
                {
                    _logger.LogInformation(
                        "  - {Name}: {Table} ({Batch} batch, {Interval}s interval)",
                        source.Name,
                        source.TableName,
                        source.Query.BatchSize,
                        source.Query.PollingIntervalSeconds);
                }

                // Create a linked token source for this processing cycle
                using var processingCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);

                // Start processing loop in background
                var processingTask = _sourceConfig.Global_Settings.Enable_Parallel_Processing
                    ? ProcessTablesInParallelAsync(enabledSources, processingCts.Token)
                    : ProcessTablesSequentiallyAsync(enabledSources, processingCts.Token);

                // Monitor for configuration changes
                var configChanged = await MonitorConfigurationChangesAsync(enabledSources.Count, processingCts.Token);

                if (configChanged)
                {
                    _logger.LogWarning("Configuration change detected - restarting with new configuration...");

                    // Cancel current processing
                    processingCts.Cancel();

                    try
                    {
                        // Wait for processing to complete (with timeout)
                        await Task.WhenAny(processingTask, Task.Delay(5000, stoppingToken));
                    }
                    catch (OperationCanceledException)
                    {
                        // Expected when canceling
                    }

                    _logger.LogInformation("Reloading configuration...");
                    // Loop will restart with new configuration
                }
                else
                {
                    // Normal shutdown
                    await processingTask;
                    break;
                }
            }

            _logger.LogInformation("Multi-Table Publisher stopped at: {Time}", DateTimeOffset.UtcNow);
        }

        private async Task<bool> MonitorConfigurationChangesAsync(int currentSourceCount, CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                await Task.Delay(TimeSpan.FromSeconds(_configCheckIntervalSeconds), cancellationToken);

                try
                {
                    // Check if configuration count has changed
                    var newCount = await GetActiveConfigurationCountAsync(cancellationToken);

                    if (newCount != currentSourceCount)
                    {
                        _logger.LogInformation(
                            "Configuration change detected: {OldCount} sources -> {NewCount} sources",
                            currentSourceCount,
                            newCount);
                        return true; // Configuration changed
                    }
                }
                catch (OperationCanceledException)
                {
                    // Normal cancellation
                    return false;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error checking configuration changes");
                }
            }

            return false; // No change, normal shutdown
        }

        private async Task<int> GetActiveConfigurationCountAsync(CancellationToken cancellationToken)
        {
            var connectionString = _sourceConfig.Global_Settings.Connection_String;

            using (var connection = new System.Data.SqlClient.SqlConnection(connectionString))
            {
                await connection.OpenAsync(cancellationToken);

                using (var command = new System.Data.SqlClient.SqlCommand("SELECT COUNT(*) FROM MQTT.SourceConfig WHERE Enabled = 1", connection))
                {
                    var count = (int)await command.ExecuteScalarAsync(cancellationToken);
                    return count;
                }
            }
        }

        private async Task LoadConfigurationAsync(CancellationToken cancellationToken)
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge")
                ?? "Server=localhost,1433;Database=MqttBridge;User Id=sa;Password=YourStrong@Passw0rd;Encrypt=False;TrustServerCertificate=True;MultipleActiveResultSets=True";

            _logger.LogInformation("Loading configuration from database: MqttSourceConfig");

            _sourceConfig = new SourceTableConfiguration
            {
                Global_Settings = new GlobalSettings
                {
                    Enable_Parallel_Processing = true,
                    Max_Concurrent_Sources = 10,
                    Connection_String = connectionString,
                    Mqtt_Broker = _configuration["MqttBroker"] ?? "localhost",
                    Mqtt_Port = int.Parse(_configuration["MqttPort"] ?? "1883")
                },
                Sources = new List<SourceTable>()
            };

            using (var connection = new System.Data.SqlClient.SqlConnection(connectionString))
            {
                await connection.OpenAsync(cancellationToken);

                using (var command = new System.Data.SqlClient.SqlCommand("MQTT.GetActiveConfigurations", connection))
                {
                    command.CommandType = System.Data.CommandType.StoredProcedure;

                    using (var reader = await command.ExecuteReaderAsync(cancellationToken))
                    {
                        while (await reader.ReadAsync(cancellationToken))
                        {
                            var fieldMappingJson = reader.GetString(reader.GetOrdinal("FieldMappingJson"));
                            var fieldMapping = JsonSerializer.Deserialize<Dictionary<string, string>>(fieldMappingJson)
                                ?? new Dictionary<string, string>();

                            var sourceTable = new SourceTable
                            {
                                Name = reader.GetString(reader.GetOrdinal("SourceName")),
                                Enabled = reader.GetBoolean(reader.GetOrdinal("Enabled")),
                                TableName = reader.GetString(reader.GetOrdinal("TableName")),
                                Schema = reader.GetString(reader.GetOrdinal("SchemaName")),
                                Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? "" : reader.GetString(reader.GetOrdinal("Description")),
                                Tracking = new TrackingConfig
                                {
                                    Method = "tracking_table",
                                    TrackingTable = "MqttSentRecords"
                                },
                                Query = new QueryConfig
                                {
                                    PrimaryKey = reader.GetString(reader.GetOrdinal("PrimaryKeyColumn")),
                                    MonitorIdColumn = reader.GetString(reader.GetOrdinal("MonitorIdColumn")),
                                    WhereClause = reader.IsDBNull(reader.GetOrdinal("WhereClause")) ? "1=1" : reader.GetString(reader.GetOrdinal("WhereClause")),
                                    OrderBy = reader.IsDBNull(reader.GetOrdinal("OrderByClause")) ? "CreatedAt ASC" : reader.GetString(reader.GetOrdinal("OrderByClause")),
                                    BatchSize = reader.GetInt32(reader.GetOrdinal("BatchSize")),
                                    PollingIntervalSeconds = reader.GetInt32(reader.GetOrdinal("PollingIntervalSeconds"))
                                },
                                Mqtt = new MqttConfig
                                {
                                    TopicPattern = reader.GetString(reader.GetOrdinal("TopicPattern")),
                                    Qos = reader.GetInt32(reader.GetOrdinal("QosLevel")),
                                    Retain = reader.GetBoolean(reader.GetOrdinal("RetainFlag"))
                                },
                                FieldMapping = fieldMapping
                            };

                            _sourceConfig.Sources.Add(sourceTable);
                        }
                    }
                }
            }

            _logger.LogInformation("Configuration loaded from database - {Count} sources found", _sourceConfig.Sources.Count);
        }

        private async Task InitializeMqttClientAsync(CancellationToken cancellationToken)
        {
            var broker = _sourceConfig.Global_Settings.Mqtt_Broker;
            var port = _sourceConfig.Global_Settings.Mqtt_Port;
            var clientId = $"MultiTablePublisher-{Environment.ProcessId}";

            _logger.LogInformation("Initializing MQTT client: {ClientId} -> {Broker}:{Port}", clientId, broker, port);

            var options = new ManagedMqttClientOptionsBuilder()
                .WithAutoReconnectDelay(TimeSpan.FromSeconds(5))
                .WithClientOptions(new MqttClientOptionsBuilder()
                    .WithTcpServer(broker, port)
                    .WithClientId(clientId)
                    .WithProtocolVersion(MQTTnet.Formatter.MqttProtocolVersion.V500)
                    .WithCleanSession()
                    .Build())
                .Build();

            _mqttClient = new MqttFactory().CreateManagedMqttClient();

            _mqttClient.ConnectedAsync += async e =>
            {
                _logger.LogInformation("Connected to MQTT broker at {Broker}:{Port}", broker, port);
                await Task.CompletedTask;
            };

            _mqttClient.DisconnectedAsync += async e =>
            {
                _logger.LogWarning("Disconnected from MQTT broker. Reason: {Reason}", e.Reason);
                await Task.CompletedTask;
            };

            _mqttClient.ConnectingFailedAsync += async e =>
            {
                _logger.LogError(e.Exception, "Failed to connect to MQTT broker");
                await Task.CompletedTask;
            };

            _mqttClient.ApplicationMessageProcessedAsync += async e =>
            {
                if (e.Exception != null)
                {
                    _logger.LogError(e.Exception, "Failed to send MQTT message");
                }
                await Task.CompletedTask;
            };

            await _mqttClient.StartAsync(options);
        }

        private async Task ProcessTablesInParallelAsync(List<SourceTable> sources, CancellationToken stoppingToken)
        {
            var tasks = new List<Task>();

            foreach (var source in sources)
            {
                var task = Task.Run(async () =>
                {
                    var loggerFactory = LoggerFactory.Create(builder => {
                        builder.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Information);
                        builder.AddSimpleConsole(options =>
                        {
                            options.SingleLine = true;
                            options.TimestampFormat = "HH:mm:ss ";
                        });
                    });
                    var tableLogger = loggerFactory.CreateLogger<TablePublisherService>();

                    var publisher = new TablePublisherService(
                        tableLogger,
                        source,
                        _sourceConfig.Global_Settings.Connection_String,
                        _mqttClient);

                    while (!stoppingToken.IsCancellationRequested)
                    {
                        await publisher.ProcessTableAsync(stoppingToken);
                        await Task.Delay(TimeSpan.FromSeconds(source.Query.PollingIntervalSeconds), stoppingToken);
                    }
                }, stoppingToken);

                tasks.Add(task);
            }

            await Task.WhenAll(tasks);
        }

        private async Task ProcessTablesSequentiallyAsync(List<SourceTable> sources, CancellationToken stoppingToken)
        {
            var loggerFactory = LoggerFactory.Create(builder => {
                builder.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Information);
                builder.AddSimpleConsole(options =>
                {
                    options.SingleLine = true;
                    options.TimestampFormat = "HH:mm:ss ";
                });
            });

            var publishers = sources.Select(source => new TablePublisherService(
                loggerFactory.CreateLogger<TablePublisherService>(),
                source,
                _sourceConfig.Global_Settings.Connection_String,
                _mqttClient)).ToList();

            while (!stoppingToken.IsCancellationRequested)
            {
                foreach (var publisher in publishers)
                {
                    if (stoppingToken.IsCancellationRequested)
                        break;

                    await publisher.ProcessTableAsync(stoppingToken);
                }

                // Use the shortest polling interval
                var minInterval = sources.Min(s => s.Query.PollingIntervalSeconds);
                await Task.Delay(TimeSpan.FromSeconds(minInterval), stoppingToken);
            }
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            if (_mqttClient != null)
            {
                await _mqttClient.StopAsync();
                _mqttClient.Dispose();
            }

            await base.StopAsync(cancellationToken);
        }
    }
}
