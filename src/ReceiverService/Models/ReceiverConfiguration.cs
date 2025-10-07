using System.Text.Json;

namespace ReceiverService.Models
{
    public class ReceiverConfiguration
    {
        public int Id { get; set; }
        public string ConfigName { get; set; } = string.Empty;
        public string TopicPattern { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string MessageFormat { get; set; } = "JSON";
        public string? FieldMappingJson { get; set; }
        public int QoS { get; set; } = 1;
        public bool Enabled { get; set; } = true;

        public List<TopicTableMapping> TableMappings { get; set; } = new();

        public Dictionary<string, string>? GetFieldMapping()
        {
            if (string.IsNullOrWhiteSpace(FieldMappingJson))
                return null;

            return JsonSerializer.Deserialize<Dictionary<string, string>>(FieldMappingJson);
        }
    }

    public class TopicTableMapping
    {
        public int Id { get; set; }
        public string TargetSchema { get; set; } = "dbo";
        public string TargetTable { get; set; } = string.Empty;
        public string InsertMode { get; set; } = "Direct"; // Direct, StoredProc, View
        public string? StoredProcName { get; set; }
        public string? ColumnMappingJson { get; set; }
        public string? FilterCondition { get; set; }
        public bool Enabled { get; set; } = true;
        public int Priority { get; set; } = 0;
        public bool ContinueOnError { get; set; } = true;

        public Dictionary<string, string>? GetColumnMapping()
        {
            if (string.IsNullOrWhiteSpace(ColumnMappingJson))
                return null;

            return JsonSerializer.Deserialize<Dictionary<string, string>>(ColumnMappingJson);
        }
    }

    public class MqttSettings
    {
        public string BrokerAddress { get; set; } = "localhost";
        public int BrokerPort { get; set; } = 1883;
        public string? ClientId { get; set; }
        public string? Username { get; set; }
        public string? Password { get; set; }
        public bool CleanSession { get; set; } = true;
        public int ReconnectDelay { get; set; } = 5; // seconds
    }
}
