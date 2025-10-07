using PublisherService.Data;
using PublisherService.Services;

namespace PublisherService
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IServiceProvider _serviceProvider;
        private readonly MqttPublisherService _mqttPublisher;
        private readonly IConfiguration _configuration;
        private readonly int _pollingIntervalSeconds;
        private readonly int _batchSize;
        private readonly int _maxRetryAttempts;

        public Worker(
            ILogger<Worker> logger,
            IServiceProvider serviceProvider,
            MqttPublisherService mqttPublisher,
            IConfiguration configuration)
        {
            _logger = logger;
            _serviceProvider = serviceProvider;
            _mqttPublisher = mqttPublisher;
            _configuration = configuration;

            var publisherSettings = configuration.GetSection("PublisherSettings");
            _pollingIntervalSeconds = int.Parse(publisherSettings["PollingIntervalSeconds"] ?? "5");
            _batchSize = int.Parse(publisherSettings["BatchSize"] ?? "100");
            _maxRetryAttempts = int.Parse(publisherSettings["MaxRetryAttempts"] ?? "3");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Publisher Worker started at: {Time}", DateTimeOffset.UtcNow);
            _logger.LogInformation(
                "Configuration - PollingInterval: {PollingInterval}s, BatchSize: {BatchSize}, MaxRetryAttempts: {MaxRetryAttempts}",
                _pollingIntervalSeconds,
                _batchSize,
                _maxRetryAttempts);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessPendingMessagesAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in Publisher Worker main loop");
                }

                await Task.Delay(TimeSpan.FromSeconds(_pollingIntervalSeconds), stoppingToken);
            }

            _logger.LogInformation("Publisher Worker stopped at: {Time}", DateTimeOffset.UtcNow);
        }

        private async Task ProcessPendingMessagesAsync(CancellationToken cancellationToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<MessageDbContext>();

            var pendingMessages = await dbContext.GetPendingMessagesAsync(_batchSize, cancellationToken);

            if (pendingMessages.Count == 0)
            {
                _logger.LogDebug("No pending messages found");
                return;
            }

            _logger.LogInformation("Processing {Count} pending messages", pendingMessages.Count);

            var successCount = 0;
            var failureCount = 0;

            foreach (var message in pendingMessages)
            {
                if (cancellationToken.IsCancellationRequested)
                    break;

                try
                {
                    var published = await _mqttPublisher.PublishMessageAsync(
                        message.MonitorId,
                        message.MessageContent,
                        message.CorrelationId,
                        cancellationToken);

                    if (published)
                    {
                        await dbContext.UpdateMessageStatusAsync(
                            message.MessageId,
                            "Published",
                            null,
                            false,
                            cancellationToken);

                        successCount++;
                        _logger.LogDebug(
                            "Message {MessageId} published successfully to monitor {MonitorId}",
                            message.MessageId,
                            message.MonitorId);
                    }
                    else
                    {
                        var newRetryCount = message.RetryCount + 1;
                        var newStatus = newRetryCount >= _maxRetryAttempts ? "Failed" : "Pending";
                        var errorMessage = $"Failed to publish message (Retry {newRetryCount}/{_maxRetryAttempts})";

                        await dbContext.UpdateMessageStatusAsync(
                            message.MessageId,
                            newStatus,
                            errorMessage,
                            true,
                            cancellationToken);

                        failureCount++;

                        if (newStatus == "Failed")
                        {
                            _logger.LogError(
                                "Message {MessageId} failed permanently after {RetryCount} attempts",
                                message.MessageId,
                                newRetryCount);
                        }
                        else
                        {
                            _logger.LogWarning(
                                "Message {MessageId} will be retried ({RetryCount}/{MaxRetryAttempts})",
                                message.MessageId,
                                newRetryCount,
                                _maxRetryAttempts);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(
                        ex,
                        "Error processing message {MessageId}",
                        message.MessageId);

                    await dbContext.UpdateMessageStatusAsync(
                        message.MessageId,
                        "Pending",
                        ex.Message,
                        true,
                        cancellationToken);

                    failureCount++;
                }
            }

            _logger.LogInformation(
                "Batch complete - Success: {SuccessCount}, Failures: {FailureCount}",
                successCount,
                failureCount);
        }
    }
}
