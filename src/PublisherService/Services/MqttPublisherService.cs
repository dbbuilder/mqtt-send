using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Extensions.ManagedClient;
using Polly;
using Polly.Retry;
using System.Text;

namespace PublisherService.Services
{
    public class MqttPublisherService : IDisposable
    {
        private readonly IManagedMqttClient _mqttClient;
        private readonly ILogger<MqttPublisherService> _logger;
        private readonly AsyncRetryPolicy _retryPolicy;
        private bool _isConnected;

        public MqttPublisherService(
            IConfiguration configuration,
            ILogger<MqttPublisherService> logger)
        {
            _logger = logger;

            var mqttSettings = configuration.GetSection("MqttSettings");
            var brokerAddress = mqttSettings["BrokerAddress"] ?? "localhost";
            var brokerPort = int.Parse(mqttSettings["BrokerPort"] ?? "1883");
            var username = mqttSettings["Username"];
            var password = mqttSettings["Password"];
            var baseClientId = mqttSettings["ClientId"] ?? "PublisherService";

            // Make ClientId unique by appending process ID to prevent conflicts
            var clientId = $"{baseClientId}-{Environment.ProcessId}";

            logger.LogInformation("MQTT ClientId: {ClientId}", clientId);

            var options = new ManagedMqttClientOptionsBuilder()
                .WithAutoReconnectDelay(TimeSpan.FromSeconds(5))
                .WithClientOptions(new MqttClientOptionsBuilder()
                    .WithTcpServer(brokerAddress, brokerPort)
                    .WithClientId(clientId)
                    .WithCredentials(username, password)
                    .WithProtocolVersion(MQTTnet.Formatter.MqttProtocolVersion.V500)
                    .WithCleanSession()
                    .Build())
                .Build();

            _mqttClient = new MqttFactory().CreateManagedMqttClient();

            _mqttClient.ConnectedAsync += async e =>
            {
                _isConnected = true;
                _logger.LogInformation("Connected to MQTT broker at {BrokerAddress}:{BrokerPort}", brokerAddress, brokerPort);
                await Task.CompletedTask;
            };

            _mqttClient.DisconnectedAsync += async e =>
            {
                _isConnected = false;
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
                else
                {
                    _logger.LogDebug("MQTT message sent successfully to topic {Topic}", e.ApplicationMessage?.ApplicationMessage?.Topic);
                }
                await Task.CompletedTask;
            };

            _retryPolicy = Policy
                .Handle<Exception>()
                .WaitAndRetryAsync(
                    retryCount: 3,
                    sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
                    onRetry: (exception, timeSpan, retryCount, context) =>
                    {
                        _logger.LogWarning(
                            exception,
                            "Retry {RetryCount} after {Delay}s due to {ExceptionMessage}",
                            retryCount,
                            timeSpan.TotalSeconds,
                            exception.Message);
                    });

            _mqttClient.StartAsync(options).Wait();
        }

        public bool IsConnected => _isConnected;

        public async Task<bool> PublishMessageAsync(
            string monitorId,
            string messageContent,
            Guid correlationId,
            CancellationToken cancellationToken)
        {
            if (!_isConnected)
            {
                _logger.LogWarning("Cannot publish message - not connected to MQTT broker");
                return false;
            }

            var topic = $"monitor/{monitorId}/messages";

            try
            {
                return await _retryPolicy.ExecuteAsync(async () =>
                {
                    var message = new MqttApplicationMessageBuilder()
                        .WithTopic(topic)
                        .WithPayload(messageContent)
                        .WithQualityOfServiceLevel(MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce)
                        .WithRetainFlag(false)
                        .WithCorrelationData(Encoding.UTF8.GetBytes(correlationId.ToString()))
                        .Build();

                    await _mqttClient.EnqueueAsync(message);

                    _logger.LogInformation(
                        "Published message to topic {Topic} with CorrelationId {CorrelationId}",
                        topic,
                        correlationId);

                    return true;
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Failed to publish message to topic {Topic} after all retries. CorrelationId: {CorrelationId}",
                    topic,
                    correlationId);

                return false;
            }
        }

        public void Dispose()
        {
            _mqttClient?.StopAsync().Wait();
            _mqttClient?.Dispose();
        }
    }
}
