using System.Data;
using Microsoft.Data.SqlClient;
using System.Text;
using System.Text.Json;
using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Extensions.ManagedClient;
using MultiTablePublisher.Models;

namespace MultiTablePublisher.Services
{
    public class TablePublisherService
    {
        private readonly ILogger<TablePublisherService> _logger;
        private readonly SourceTable _sourceConfig;
        private readonly string _connectionString;
        private readonly IManagedMqttClient _mqttClient;

        public TablePublisherService(
            ILogger<TablePublisherService> logger,
            SourceTable sourceConfig,
            string connectionString,
            IManagedMqttClient mqttClient)
        {
            _logger = logger;
            _sourceConfig = sourceConfig;
            _connectionString = connectionString;
            _mqttClient = mqttClient;
        }

        public async Task ProcessTableAsync(CancellationToken cancellationToken)
        {
            try
            {
                // Build dynamic SQL to find unsent records
                var sql = BuildUnsentRecordsQuery();

                List<Dictionary<string, object>> records;

                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync(cancellationToken);

                    using (var command = new SqlCommand(sql, connection))
                    {
                        command.CommandTimeout = 30;
                        records = await ExecuteQueryAsync(command, cancellationToken);
                    }
                }

                if (records.Count == 0)
                {
                    _logger.LogDebug("[{TableName}] No unsent records found", _sourceConfig.Name);
                    return;
                }

                _logger.LogInformation("[{TableName}] Processing {Count} unsent records", _sourceConfig.Name, records.Count);

                // Publish each record to MQTT
                var successCount = 0;
                var failureCount = 0;

                foreach (var record in records)
                {
                    if (cancellationToken.IsCancellationRequested)
                        break;

                    try
                    {
                        // Map fields based on configuration
                        var mqttPayload = MapFieldsToPayload(record);

                        // Build topic with substitution
                        var topic = BuildTopic(record);

                        // Publish to MQTT
                        var correlationId = Guid.NewGuid();
                        var published = await PublishToMqttAsync(topic, mqttPayload, correlationId, cancellationToken);

                        if (published)
                        {
                            var primaryKeyValue = record[_sourceConfig.Query.PrimaryKey].ToString();
                            await MarkRecordAsSentAsync(primaryKeyValue!, topic, correlationId, cancellationToken);
                            successCount++;
                        }
                        else
                        {
                            failureCount++;
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "[{TableName}] Error publishing record", _sourceConfig.Name);
                        failureCount++;
                    }
                }

                _logger.LogInformation(
                    "[{TableName}] Batch complete - Success: {Success}, Failures: {Failures}",
                    _sourceConfig.Name, successCount, failureCount);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[{TableName}] Error processing table", _sourceConfig.Name);
            }
        }

        private string BuildUnsentRecordsQuery()
        {
            // Get all columns from field mapping
            var columns = string.Join(", ", _sourceConfig.FieldMapping.Keys.Select(k => $"t.{k}"));

            // If no field mapping, select all columns
            if (string.IsNullOrWhiteSpace(columns))
            {
                columns = "t.*";
            }

            var sql = $@"
                SELECT TOP {_sourceConfig.Query.BatchSize}
                    {columns}
                FROM {_sourceConfig.Schema}.{_sourceConfig.TableName} t
                LEFT JOIN MQTT.SentRecords m
                    ON m.SourceName = '{_sourceConfig.Name}'
                    AND m.RecordId = CAST(t.{_sourceConfig.Query.PrimaryKey} AS NVARCHAR(100))
                WHERE m.Id IS NULL
                    AND ({_sourceConfig.Query.WhereClause})
                ORDER BY t.{_sourceConfig.Query.OrderBy}";

            return sql;
        }

        private async Task<List<Dictionary<string, object>>> ExecuteQueryAsync(SqlCommand command, CancellationToken cancellationToken)
        {
            var results = new List<Dictionary<string, object>>();

            using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    var row = new Dictionary<string, object>();

                    for (int i = 0; i < reader.FieldCount; i++)
                    {
                        var columnName = reader.GetName(i);
                        var value = reader.GetValue(i);
                        row[columnName] = value == DBNull.Value ? null! : value;
                    }

                    results.Add(row);
                }
            }

            return results;
        }

        private Dictionary<string, object?> MapFieldsToPayload(Dictionary<string, object> record)
        {
            var payload = new Dictionary<string, object?>();

            foreach (var mapping in _sourceConfig.FieldMapping)
            {
                var sourceColumn = mapping.Key;
                var targetField = mapping.Value;

                if (record.ContainsKey(sourceColumn))
                {
                    payload[targetField] = record[sourceColumn];
                }
            }

            // Add metadata
            payload["SourceTable"] = _sourceConfig.Name;
            payload["ProcessedAt"] = DateTime.UtcNow;

            return payload;
        }

        private string BuildTopic(Dictionary<string, object> record)
        {
            var topic = _sourceConfig.Mqtt.TopicPattern;

            // Replace placeholders like {MonitorId} with actual values
            foreach (var kvp in record)
            {
                var placeholder = $"{{{kvp.Key}}}";
                if (topic.Contains(placeholder))
                {
                    topic = topic.Replace(placeholder, kvp.Value?.ToString() ?? "unknown");
                }
            }

            return topic;
        }

        private async Task<bool> PublishToMqttAsync(
            string topic,
            Dictionary<string, object?> payload,
            Guid correlationId,
            CancellationToken cancellationToken)
        {
            try
            {
                var jsonPayload = JsonSerializer.Serialize(payload);

                var message = new MqttApplicationMessageBuilder()
                    .WithTopic(topic)
                    .WithPayload(jsonPayload)
                    .WithQualityOfServiceLevel((MQTTnet.Protocol.MqttQualityOfServiceLevel)_sourceConfig.Mqtt.Qos)
                    .WithRetainFlag(_sourceConfig.Mqtt.Retain)
                    .WithCorrelationData(Encoding.UTF8.GetBytes(correlationId.ToString()))
                    .Build();

                await _mqttClient.EnqueueAsync(message);

                _logger.LogDebug("[{TableName}] Published to topic: {Topic}", _sourceConfig.Name, topic);

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[{TableName}] Failed to publish MQTT message to topic: {Topic}", _sourceConfig.Name, topic);
                return false;
            }
        }

        private async Task MarkRecordAsSentAsync(string recordId, string topic, Guid correlationId, CancellationToken cancellationToken)
        {
            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync(cancellationToken);

                    var sql = @"
                        INSERT INTO MQTT.SentRecords (SourceName, RecordId, Topic, CorrelationId, SentAt)
                        VALUES (@SourceName, @RecordId, @Topic, @CorrelationId, GETUTCDATE())";

                    using (var command = new SqlCommand(sql, connection))
                    {
                        command.Parameters.AddWithValue("@SourceName", _sourceConfig.Name);
                        command.Parameters.AddWithValue("@RecordId", recordId);
                        command.Parameters.AddWithValue("@Topic", topic);
                        command.Parameters.AddWithValue("@CorrelationId", correlationId);

                        await command.ExecuteNonQueryAsync(cancellationToken);

                        _logger.LogDebug("[{TableName}] Marked record {RecordId} as sent", _sourceConfig.Name, recordId);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[{TableName}] Error marking record {RecordId} as sent", _sourceConfig.Name, recordId);
            }
        }
    }
}
