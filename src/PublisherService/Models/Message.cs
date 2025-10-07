namespace PublisherService.Models
{
    public class Message
    {
        public long MessageId { get; set; }
        public string MonitorId { get; set; } = string.Empty;
        public string MessageContent { get; set; } = string.Empty;
        public int Priority { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? ProcessedDate { get; set; }
        public string Status { get; set; } = string.Empty;
        public int RetryCount { get; set; }
        public string? ErrorMessage { get; set; }
        public Guid CorrelationId { get; set; }
    }
}
