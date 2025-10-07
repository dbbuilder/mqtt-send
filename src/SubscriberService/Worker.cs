using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Extensions.ManagedClient;
using System.Text;
using System.Text.Json;

namespace SubscriberService
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IConfiguration _configuration;
        private IManagedMqttClient? _mqttClient;
        private readonly string _monitorFilter;

        public Worker(ILogger<Worker> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;

            // Command line parameter takes precedence over appsettings
            _monitorFilter = configuration["MonitorFilter"]
                ?? configuration.GetSection("SubscriberSettings")["MonitorFilter"]
                ?? "+";
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Subscriber Worker started at: {Time}", DateTimeOffset.UtcNow);
            _logger.LogInformation("Monitor Filter: {MonitorFilter}", _monitorFilter);

            await InitializeMqttClientAsync(stoppingToken);

            // Keep the service running
            while (!stoppingToken.IsCancellationRequested)
            {
                await Task.Delay(1000, stoppingToken);
            }

            _logger.LogInformation("Subscriber Worker stopped at: {Time}", DateTimeOffset.UtcNow);
        }

        private async Task InitializeMqttClientAsync(CancellationToken cancellationToken)
        {
            var mqttSettings = _configuration.GetSection("MqttSettings");
            var brokerAddress = mqttSettings["BrokerAddress"] ?? "localhost";
            var brokerPort = int.Parse(mqttSettings["BrokerPort"] ?? "1883");
            var username = mqttSettings["Username"];
            var password = mqttSettings["Password"];

            // Allow ClientIdSuffix from command line, otherwise use config, otherwise use default
            var clientIdSuffix = _configuration["ClientIdSuffix"]
                ?? mqttSettings["ClientId"]?.Replace("SubscriberService-", "")
                ?? "SubscriberService";

            // Make ClientId unique by appending suffix and process ID to prevent conflicts
            var clientId = $"SubscriberService-{clientIdSuffix}-{Environment.ProcessId}";

            _logger.LogInformation("MQTT ClientId: {ClientId}", clientId);

            var options = new ManagedMqttClientOptionsBuilder()
                .WithAutoReconnectDelay(TimeSpan.FromSeconds(5))
                .WithClientOptions(new MqttClientOptionsBuilder()
                    .WithTcpServer(brokerAddress, brokerPort)
                    .WithClientId(clientId)
                    .WithCredentials(username, password)
                    .WithProtocolVersion(MQTTnet.Formatter.MqttProtocolVersion.V500)
                    .WithCleanSession(false)
                    .Build())
                .Build();

            _mqttClient = new MqttFactory().CreateManagedMqttClient();

            _mqttClient.ConnectedAsync += async e =>
            {
                _logger.LogInformation("Connected to MQTT broker at {BrokerAddress}:{BrokerPort}", brokerAddress, brokerPort);

                // Subscribe to data topics for specific monitor (data/+/monitorId matches data/tableA/1, data/tableB/1, etc)
                var topic = $"data/+/{_monitorFilter}";
                await _mqttClient.SubscribeAsync(topic);
                _logger.LogInformation("Subscribed to topic: {Topic}", topic);
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

            _mqttClient.ApplicationMessageReceivedAsync += async e =>
            {
                await ProcessMessageAsync(e.ApplicationMessage);
            };

            await _mqttClient.StartAsync(options);
        }

        private async Task ProcessMessageAsync(MqttApplicationMessage message)
        {
            try
            {
                var topic = message.Topic;
                var payload = Encoding.UTF8.GetString(message.PayloadSegment);
                var correlationId = message.CorrelationData != null
                    ? Encoding.UTF8.GetString(message.CorrelationData)
                    : "N/A";

                // Extract MonitorId and table from topic (format: data/{tablename}/{monitorid})
                var topicParts = topic.Split('/');
                var tableName = topicParts.Length > 1 ? topicParts[1] : "Unknown";
                var monitorId = topicParts.Length > 2 ? topicParts[2] : "Unknown";

                _logger.LogInformation(
                    "====================================");
                _logger.LogInformation(
                    "RECEIVED MESSAGE");
                _logger.LogInformation(
                    "Table: {TableName} | MonitorId: {MonitorId}",
                    tableName, monitorId);
                _logger.LogInformation(
                    "Topic: {Topic}",
                    topic);
                _logger.LogInformation(
                    "CorrelationId: {CorrelationId}",
                    correlationId);
                _logger.LogInformation(
                    "Payload: {Payload}",
                    payload);
                _logger.LogInformation(
                    "====================================");

                // Process the message content
                await ProcessMessageContentAsync(monitorId, payload, correlationId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing MQTT message");
            }
        }

        private async Task ProcessMessageContentAsync(string monitorId, string payload, string correlationId)
        {
            // This is where you would implement your business logic
            // Parse the complete record and extract all fields

            try
            {
                // Parse the JSON record
                using var jsonDoc = JsonDocument.Parse(payload);
                var root = jsonDoc.RootElement;

                _logger.LogInformation("");
                _logger.LogInformation(">>> PARSING COMPLETE RECORD <<<");
                _logger.LogInformation("------------------------------------");

                // Extract and display all fields from the record (using ToString() for safe parsing)
                if (root.TryGetProperty("RecordId", out var recordId))
                    _logger.LogInformation("  Record ID: {RecordId}", recordId.ToString());

                if (root.TryGetProperty("MonitorId", out var mid))
                    _logger.LogInformation("  Monitor ID: {MonitorId}", mid.ToString());

                if (root.TryGetProperty("SensorType", out var sensorType))
                    _logger.LogInformation("  Sensor Type: {SensorType}", sensorType.ToString());

                if (root.TryGetProperty("Value", out var value))
                    _logger.LogInformation("  Value: {Value}", value.ToString());

                if (root.TryGetProperty("Unit", out var unit))
                    _logger.LogInformation("  Unit: {Unit}", unit.ToString());

                if (root.TryGetProperty("Timestamp", out var timestamp))
                    _logger.LogInformation("  Timestamp: {Timestamp}", timestamp.ToString());

                if (root.TryGetProperty("Status", out var status))
                    _logger.LogInformation("  Status: {Status}", status.ToString());

                if (root.TryGetProperty("Location", out var location))
                    _logger.LogInformation("  Location: {Location}", location.ToString());

                if (root.TryGetProperty("SourceTable", out var sourceTable))
                    _logger.LogInformation("  Source Table: {SourceTable}", sourceTable.ToString());

                if (root.TryGetProperty("ProcessedAt", out var processedAt))
                    _logger.LogInformation("  Processed At: {ProcessedAt}", processedAt.ToString());

                _logger.LogInformation("------------------------------------");
                _logger.LogInformation(">>> RECORD PROCESSING COMPLETE <<<");
                _logger.LogInformation("");

                // Business logic examples:
                // - Check if Value exceeds AlertThreshold
                // - Store record in database
                // - Trigger alerts if Status is not "Active"
                // - Aggregate data by Location
                // etc.
            }
            catch (JsonException ex)
            {
                _logger.LogWarning("Failed to parse JSON payload: {Error}", ex.Message);
                _logger.LogInformation("Raw payload: {Payload}", payload);
            }

            // Simulate processing delay
            await Task.Delay(100);
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
