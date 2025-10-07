namespace MultiTablePublisher.Models
{
    public class SourceTableConfiguration
    {
        public List<SourceTable> Sources { get; set; } = new();
        public GlobalSettings Global_Settings { get; set; } = new();
    }

    public class SourceTable
    {
        public string Name { get; set; } = string.Empty;
        public bool Enabled { get; set; }
        public string TableName { get; set; } = string.Empty;
        public string Schema { get; set; } = "dbo";
        public string Description { get; set; } = string.Empty;
        public TrackingConfig Tracking { get; set; } = new();
        public QueryConfig Query { get; set; } = new();
        public MqttConfig Mqtt { get; set; } = new();
        public Dictionary<string, string> FieldMapping { get; set; } = new();
    }

    public class TrackingConfig
    {
        public string Method { get; set; } = "tracking_table";
        public string TrackingTable { get; set; } = "MqttSentRecords";
    }

    public class QueryConfig
    {
        public string PrimaryKey { get; set; } = "Id";
        public string MonitorIdColumn { get; set; } = "MonitorId";
        public string WhereClause { get; set; } = "1=1";
        public string OrderBy { get; set; } = "CreatedAt ASC";
        public int BatchSize { get; set; } = 1000;
        public int PollingIntervalSeconds { get; set; } = 5;
    }

    public class MqttConfig
    {
        public string TopicPattern { get; set; } = string.Empty;
        public int Qos { get; set; } = 1;
        public bool Retain { get; set; } = false;
    }

    public class GlobalSettings
    {
        public bool Enable_Parallel_Processing { get; set; } = true;
        public int Max_Concurrent_Sources { get; set; } = 3;
        public string Connection_String { get; set; } = string.Empty;
        public string Mqtt_Broker { get; set; } = "localhost";
        public int Mqtt_Port { get; set; } = 1883;
    }
}
