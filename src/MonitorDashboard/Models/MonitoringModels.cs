namespace MonitorDashboard.Models;

public class SystemStatus
{
    public bool ReceiverConnected { get; set; }
    public bool PublisherConnected { get; set; }
    public int ActiveSubscriptions { get; set; }
    public int MonitoredTables { get; set; }
    public DateTime LastUpdate { get; set; } = DateTime.UtcNow;
}

public class ReceiverStatus
{
    public int ConfigCount { get; set; }
    public List<TopicSubscription> Subscriptions { get; set; } = new();
    public List<RecentMessage> RecentMessages { get; set; } = new();
    public MessageStatistics Statistics { get; set; } = new();
}

public class TopicSubscription
{
    public string ConfigName { get; set; } = string.Empty;
    public string TopicPattern { get; set; } = string.Empty;
    public bool IsEnabled { get; set; }
    public int TableMappingCount { get; set; }
}

public class RecentMessage
{
    public int Id { get; set; }
    public string Topic { get; set; } = string.Empty;
    public string ConfigName { get; set; } = string.Empty;
    public DateTime ReceivedAt { get; set; }
    public bool Success { get; set; }
    public int TablesAffected { get; set; }
    public string? ErrorMessage { get; set; }
}

public class MessageStatistics
{
    public int TotalToday { get; set; }
    public int SuccessToday { get; set; }
    public int FailedToday { get; set; }
    public int TotalAllTime { get; set; }
    public double SuccessRate => TotalToday > 0 ? (double)SuccessToday / TotalToday * 100 : 0;
}

public class PublisherStatus
{
    public int MonitoredTableCount { get; set; }
    public List<TableMonitor> TableMonitors { get; set; } = new();
    public List<RecentPublication> RecentPublications { get; set; } = new();
    public PublicationStatistics Statistics { get; set; } = new();
}

public class TableMonitor
{
    public string TableName { get; set; } = string.Empty;
    public string Topic { get; set; } = string.Empty;
    public bool IsEnabled { get; set; }
    public int PollingIntervalSeconds { get; set; }
}

public class RecentPublication
{
    public int Id { get; set; }
    public string TableName { get; set; } = string.Empty;
    public string Topic { get; set; } = string.Empty;
    public DateTime PublishedAt { get; set; }
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
}

public class PublicationStatistics
{
    public int TotalToday { get; set; }
    public int SuccessToday { get; set; }
    public int FailedToday { get; set; }
    public int TotalAllTime { get; set; }
    public double SuccessRate => TotalToday > 0 ? (double)SuccessToday / TotalToday * 100 : 0;
}

public class MessageFlowEvent
{
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string Type { get; set; } = string.Empty; // "received" or "published"
    public string Topic { get; set; } = string.Empty;
    public string? TargetTable { get; set; }
    public bool Success { get; set; }
    public string? Details { get; set; }
}
