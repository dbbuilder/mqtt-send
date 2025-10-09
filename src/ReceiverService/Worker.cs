using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Extensions.ManagedClient;
using ReceiverService.Models;
using ReceiverService.Services;
using Microsoft.Data.SqlClient;
using System.Text.Json;
using System.Data;

namespace ReceiverService
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IConfiguration _configuration;
        private IManagedMqttClient _mqttClient = null!;
        private List<ReceiverConfiguration> _receiverConfigs = new();
        private readonly int _configCheckIntervalSeconds = 30;

        public Worker(ILogger<Worker> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("MQTT Receiver started at: {Time}", DateTimeOffset.UtcNow);
            _logger.LogInformation("Auto-reload enabled - checking for config changes every {Interval}s", _configCheckIntervalSeconds);

            // Load configuration and initialize MQTT client
            await LoadConfigurationAsync(stoppingToken);
            await InitializeMqttClientAsync(stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Monitor for configuration changes
                    var currentConfigCount = _receiverConfigs.Count;
                    var configChanged = await MonitorConfigurationChangesAsync(currentConfigCount, stoppingToken);

                    if (configChanged)
                    {
                        _logger.LogInformation("Configuration changed - reloading...");

                        // Unsubscribe from all current topics
                        await UnsubscribeAllTopicsAsync();

                        // Reload configuration
                        await LoadConfigurationAsync(stoppingToken);

                        // Resubscribe to new topics
                        await SubscribeToConfiguredTopicsAsync();

                        _logger.LogInformation("Configuration reload complete");
                    }

                    await Task.Delay(TimeSpan.FromSeconds(_configCheckIntervalSeconds), stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in config monitoring loop");
                    await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                }
            }

            // Cleanup
            if (_mqttClient != null && _mqttClient.IsConnected)
            {
                await _mqttClient.StopAsync();
            }
        }

        private async Task LoadConfigurationAsync(CancellationToken cancellationToken)
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge")
                ?? throw new InvalidOperationException("Connection string 'MqttBridge' not found");

            _logger.LogInformation("Loading receiver configurations from database...");

            using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            using var command = new SqlCommand("MQTT.GetActiveReceiverConfigs", connection);
            command.CommandType = CommandType.StoredProcedure;

            _receiverConfigs.Clear();

            using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var config = new ReceiverConfiguration
                {
                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                    ConfigName = reader.GetString(reader.GetOrdinal("ConfigName")),
                    TopicPattern = reader.GetString(reader.GetOrdinal("TopicPattern")),
                    Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? null : reader.GetString(reader.GetOrdinal("Description")),
                    MessageFormat = reader.GetString(reader.GetOrdinal("MessageFormat")),
                    FieldMappingJson = reader.IsDBNull(reader.GetOrdinal("FieldMappingJson")) ? null : reader.GetString(reader.GetOrdinal("FieldMappingJson")),
                    QoS = reader.GetByte(reader.GetOrdinal("QoS")),
                    Enabled = reader.GetBoolean(reader.GetOrdinal("Enabled"))
                };

                // Parse table mappings JSON
                var tableMappingsJson = reader.IsDBNull(reader.GetOrdinal("TableMappingsJson"))
                    ? null
                    : reader.GetString(reader.GetOrdinal("TableMappingsJson"));

                if (!string.IsNullOrWhiteSpace(tableMappingsJson))
                {
                    config.TableMappings = JsonSerializer.Deserialize<List<TopicTableMapping>>(tableMappingsJson) ?? new();
                }

                _receiverConfigs.Add(config);
            }

            _logger.LogInformation("Loaded {Count} receiver configuration(s)", _receiverConfigs.Count);

            foreach (var config in _receiverConfigs)
            {
                _logger.LogInformation("  - {Name}: Topic='{Pattern}', Mappings={MappingCount}",
                    config.ConfigName, config.TopicPattern, config.TableMappings.Count);
            }
        }

        private async Task InitializeMqttClientAsync(CancellationToken cancellationToken)
        {
            var mqttSettings = _configuration.GetSection("MqttSettings").Get<MqttSettings>()
                ?? new MqttSettings();

            _logger.LogInformation("Connecting to MQTT broker at {Broker}:{Port}", mqttSettings.BrokerAddress, mqttSettings.BrokerPort);

            var factory = new MqttFactory();
            _mqttClient = factory.CreateManagedMqttClient();

            var options = new ManagedMqttClientOptionsBuilder()
                .WithAutoReconnectDelay(TimeSpan.FromSeconds(mqttSettings.ReconnectDelay))
                .WithClientOptions(new MqttClientOptionsBuilder()
                    .WithClientId(mqttSettings.ClientId ?? $"MqttReceiver-{Guid.NewGuid():N}")
                    .WithTcpServer(mqttSettings.BrokerAddress, mqttSettings.BrokerPort)
                    .WithCleanSession(mqttSettings.CleanSession)
                    .Build())
                .Build();

            // Set up message handler
            _mqttClient.ApplicationMessageReceivedAsync += OnMessageReceivedAsync;

            _mqttClient.ConnectedAsync += async e =>
            {
                _logger.LogInformation("Connected to MQTT broker");
                await SubscribeToConfiguredTopicsAsync();
            };

            _mqttClient.DisconnectedAsync += e =>
            {
                _logger.LogWarning("Disconnected from MQTT broker: {Reason}", e.Reason);
                return Task.CompletedTask;
            };

            await _mqttClient.StartAsync(options);
        }

        private async Task SubscribeToConfiguredTopicsAsync()
        {
            foreach (var config in _receiverConfigs)
            {
                var topic = config.TopicPattern;
                var qos = (MQTTnet.Protocol.MqttQualityOfServiceLevel)config.QoS;

                await _mqttClient.SubscribeAsync(topic, qos);
                _logger.LogInformation("Subscribed to topic: '{Topic}' (QoS: {QoS})", topic, qos);
            }
        }

        private async Task UnsubscribeAllTopicsAsync()
        {
            foreach (var config in _receiverConfigs)
            {
                await _mqttClient.UnsubscribeAsync(config.TopicPattern);
                _logger.LogInformation("Unsubscribed from topic: '{Topic}'", config.TopicPattern);
            }
        }

        private async Task<bool> MonitorConfigurationChangesAsync(int currentConfigCount, CancellationToken cancellationToken)
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge")!;

            using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            using var command = new SqlCommand("MQTT.GetReceiverConfigCount", connection);
            command.CommandType = CommandType.StoredProcedure;

            var newCount = (int)(await command.ExecuteScalarAsync(cancellationToken) ?? 0);

            if (newCount != currentConfigCount)
            {
                _logger.LogWarning("Configuration change detected: {OldCount} configs -> {NewCount} configs",
                    currentConfigCount, newCount);
                return true;
            }

            return false;
        }

        private async Task OnMessageReceivedAsync(MqttApplicationMessageReceivedEventArgs e)
        {
            try
            {
                var topic = e.ApplicationMessage.Topic;
                var payload = System.Text.Encoding.UTF8.GetString(e.ApplicationMessage.PayloadSegment);

                _logger.LogInformation("====================================");
                _logger.LogInformation("RECEIVED MQTT MESSAGE");
                _logger.LogInformation("Topic: {Topic}", topic);
                _logger.LogInformation("Payload: {Payload}", payload);
                _logger.LogInformation("====================================");

                // Find matching configurations
                var matchingConfigs = _receiverConfigs
                    .Where(c => TopicMatches(topic, c.TopicPattern))
                    .ToList();

                if (matchingConfigs.Count == 0)
                {
                    _logger.LogWarning("No matching configuration found for topic: {Topic}", topic);
                    return;
                }

                // Process each matching configuration
                foreach (var config in matchingConfigs)
                {
                    await ProcessMessageForConfigAsync(config, topic, payload);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing MQTT message");
            }
        }

        private async Task ProcessMessageForConfigAsync(ReceiverConfiguration config, string topic, string payload)
        {
            _logger.LogInformation("Processing message with config: {ConfigName}", config.ConfigName);

            long messageId = 0;
            try
            {
                // Log message receipt to ReceivedMessages table
                await using var connection = new SqlConnection(_configuration.GetConnectionString("MqttBridge"));
                await connection.OpenAsync();

                // Insert initial tracking record
                var insertCmd = new SqlCommand(@"
                    INSERT INTO MQTT.ReceivedMessages (ReceiverConfigId, Topic, Payload, QoS, ReceivedAt, Status)
                    OUTPUT INSERTED.Id
                    VALUES (@ConfigId, @Topic, @Payload, @QoS, GETUTCDATE(), 'Processing')",
                    connection);
                insertCmd.Parameters.AddWithValue("@ConfigId", config.Id);
                insertCmd.Parameters.AddWithValue("@Topic", topic);
                insertCmd.Parameters.AddWithValue("@Payload", payload);
                insertCmd.Parameters.AddWithValue("@QoS", config.QoS);

                var result = await insertCmd.ExecuteScalarAsync();
                messageId = result != null ? Convert.ToInt64(result) : 0;

                // Process the message
                var messageProcessor = new MessageProcessor(
                    _logger,
                    _configuration.GetConnectionString("MqttBridge")!
                );

                var successCount = await messageProcessor.ProcessMessageAsync(config, topic, payload);

                // Update tracking record with success
                var updateCmd = new SqlCommand(@"
                    UPDATE MQTT.ReceivedMessages
                    SET ProcessedAt = GETUTCDATE(),
                        Status = 'Success',
                        TargetTablesProcessed = @Count
                    WHERE Id = @Id",
                    connection);
                updateCmd.Parameters.AddWithValue("@Id", messageId);
                updateCmd.Parameters.AddWithValue("@Count", successCount);
                await updateCmd.ExecuteNonQueryAsync();

                _logger.LogInformation("Message processed successfully to {Count} table(s)", successCount);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing message");

                // Update tracking record with failure
                if (messageId > 0)
                {
                    try
                    {
                        await using var connection = new SqlConnection(_configuration.GetConnectionString("MqttBridge"));
                        await connection.OpenAsync();

                        var updateCmd = new SqlCommand(@"
                            UPDATE MQTT.ReceivedMessages
                            SET ProcessedAt = GETUTCDATE(),
                                Status = 'Failed',
                                ErrorMessage = @Error
                            WHERE Id = @Id",
                            connection);
                        updateCmd.Parameters.AddWithValue("@Id", messageId);
                        updateCmd.Parameters.AddWithValue("@Error", ex.Message);
                        await updateCmd.ExecuteNonQueryAsync();
                    }
                    catch (Exception logEx)
                    {
                        _logger.LogError(logEx, "Error updating failure status in ReceivedMessages");
                    }
                }

                throw;
            }
        }

        private bool TopicMatches(string actualTopic, string pattern)
        {
            // Simple MQTT topic matching
            // + matches a single level
            // # matches multiple levels

            var actualParts = actualTopic.Split('/');
            var patternParts = pattern.Split('/');

            int i = 0, j = 0;

            while (i < actualParts.Length && j < patternParts.Length)
            {
                if (patternParts[j] == "#")
                {
                    return true; // # matches everything remaining
                }
                else if (patternParts[j] == "+" || patternParts[j] == actualParts[i])
                {
                    i++;
                    j++;
                }
                else
                {
                    return false;
                }
            }

            return i == actualParts.Length && j == patternParts.Length;
        }
    }
}
