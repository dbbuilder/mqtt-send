using ReceiverService.Models;
using System.Data;
using System.Data.SqlClient;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace ReceiverService.Services
{
    public class MessageProcessor
    {
        private readonly ILogger _logger;
        private readonly string _connectionString;

        public MessageProcessor(ILogger logger, string connectionString)
        {
            _logger = logger;
            _connectionString = connectionString;
        }

        public async Task<int> ProcessMessageAsync(ReceiverConfiguration config, string topic, string payload)
        {
            _logger.LogInformation("Processing message for config '{ConfigName}'", config.ConfigName);

            // Parse message payload
            var messageData = ParseMessage(payload, config.MessageFormat, config.FieldMappingJson);

            if (messageData == null || messageData.Count == 0)
            {
                _logger.LogWarning("Failed to parse message or message is empty");
                return 0;
            }

            int successCount = 0;

            // Process each table mapping
            var orderedMappings = config.TableMappings
                .Where(m => m.Enabled)
                .OrderByDescending(m => m.Priority)
                .ToList();

            foreach (var mapping in orderedMappings)
            {
                try
                {
                    // Check filter condition
                    if (!string.IsNullOrWhiteSpace(mapping.FilterCondition))
                    {
                        if (!EvaluateFilterCondition(messageData, mapping.FilterCondition))
                        {
                            _logger.LogDebug("Skipping mapping to {Schema}.{Table} - filter condition not met: {Condition}",
                                mapping.TargetSchema, mapping.TargetTable, mapping.FilterCondition);
                            continue;
                        }
                    }

                    // Get column mapping (use table-specific mapping if available, otherwise use global)
                    var columnMapping = mapping.GetColumnMapping() ?? config.GetFieldMapping();

                    if (columnMapping == null)
                    {
                        _logger.LogWarning("No column mapping defined for {Schema}.{Table}", mapping.TargetSchema, mapping.TargetTable);
                        continue;
                    }

                    // Insert into table
                    await InsertIntoTableAsync(mapping, messageData, columnMapping);
                    successCount++;

                    _logger.LogInformation("✓ Inserted into {Schema}.{Table}", mapping.TargetSchema, mapping.TargetTable);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error inserting into {Schema}.{Table}", mapping.TargetSchema, mapping.TargetTable);

                    if (!mapping.ContinueOnError)
                    {
                        throw;
                    }
                }
            }

            return successCount;
        }

        private Dictionary<string, object>? ParseMessage(string payload, string messageFormat, string? fieldMappingJson)
        {
            try
            {
                if (messageFormat.Equals("JSON", StringComparison.OrdinalIgnoreCase))
                {
                    var jsonDoc = JsonDocument.Parse(payload);
                    var result = new Dictionary<string, object>();

                    // Extract all properties from JSON
                    foreach (var property in jsonDoc.RootElement.EnumerateObject())
                    {
                        result[property.Name] = GetJsonValue(property.Value);
                    }

                    return result;
                }
                else
                {
                    _logger.LogWarning("Unsupported message format: {Format}", messageFormat);
                    return null;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error parsing message");
                return null;
            }
        }

        private object GetJsonValue(JsonElement element)
        {
            return element.ValueKind switch
            {
                JsonValueKind.String => element.GetString() ?? string.Empty,
                JsonValueKind.Number => element.TryGetDecimal(out var dec) ? dec : element.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Null => DBNull.Value,
                _ => element.ToString()
            };
        }

        private object? GetValueCaseInsensitive(Dictionary<string, object> data, string key)
        {
            // Try exact match first
            if (data.TryGetValue(key, out var value))
                return value;

            // Try case-insensitive match
            var match = data.FirstOrDefault(kvp =>
                string.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase));

            return match.Value;
        }

        private bool EvaluateFilterCondition(Dictionary<string, object> messageData, string filterCondition)
        {
            // Simple filter evaluation: "Value > 75.0", "SensorType = 'temperature'", etc.
            // This is a basic implementation - could be enhanced with expression parser

            try
            {
                // Pattern: FieldName operator Value
                var match = Regex.Match(filterCondition, @"(\w+)\s*(>|<|>=|<=|=|!=)\s*(.+)", RegexOptions.IgnoreCase);

                if (!match.Success)
                {
                    _logger.LogWarning("Invalid filter condition format: {Condition}", filterCondition);
                    return true; // Allow by default if filter is invalid
                }

                var fieldName = match.Groups[1].Value;
                var op = match.Groups[2].Value;
                var valueStr = match.Groups[3].Value.Trim().Trim('\'', '"');

                // Case-insensitive field lookup
                var fieldValue = GetValueCaseInsensitive(messageData, fieldName);
                if (fieldValue == null)
                {
                    _logger.LogWarning("Field '{Field}' not found in message data for filter", fieldName);
                    return false;
                }

                // Try to parse as decimal for numeric comparisons
                if (decimal.TryParse(fieldValue?.ToString(), out var fieldDecimal) &&
                    decimal.TryParse(valueStr, out var compareDecimal))
                {
                    return op switch
                    {
                        ">" => fieldDecimal > compareDecimal,
                        "<" => fieldDecimal < compareDecimal,
                        ">=" => fieldDecimal >= compareDecimal,
                        "<=" => fieldDecimal <= compareDecimal,
                        "=" => fieldDecimal == compareDecimal,
                        "!=" => fieldDecimal != compareDecimal,
                        _ => true
                    };
                }

                // String comparison
                var fieldStr = fieldValue?.ToString() ?? string.Empty;
                return op switch
                {
                    "=" => fieldStr.Equals(valueStr, StringComparison.OrdinalIgnoreCase),
                    "!=" => !fieldStr.Equals(valueStr, StringComparison.OrdinalIgnoreCase),
                    _ => true
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error evaluating filter condition: {Condition}", filterCondition);
                return true; // Allow by default on error
            }
        }

        private async Task InsertIntoTableAsync(
            TopicTableMapping mapping,
            Dictionary<string, object> messageData,
            Dictionary<string, string> columnMapping)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            if (mapping.InsertMode.Equals("StoredProc", StringComparison.OrdinalIgnoreCase))
            {
                // Execute stored procedure
                await ExecuteStoredProcAsync(connection, mapping, messageData, columnMapping);
            }
            else
            {
                // Direct INSERT statement
                await ExecuteDirectInsertAsync(connection, mapping, messageData, columnMapping);
            }
        }

        private async Task ExecuteStoredProcAsync(
            SqlConnection connection,
            TopicTableMapping mapping,
            Dictionary<string, object> messageData,
            Dictionary<string, string> columnMapping)
        {
            if (string.IsNullOrWhiteSpace(mapping.StoredProcName))
            {
                throw new InvalidOperationException($"StoredProcName is required for InsertMode=StoredProc");
            }

            using var command = new SqlCommand(mapping.StoredProcName, connection);
            command.CommandType = CommandType.StoredProcedure;

            // Get actual parameters from stored procedure
            var procParameters = await GetStoredProcParametersAsync(connection, mapping.StoredProcName);

            // Add parameters based on stored proc definition (not column mapping)
            foreach (var paramName in procParameters)
            {
                // Try to find matching field in column mapping (case-insensitive)
                var mappingEntry = columnMapping.FirstOrDefault(kvp =>
                    string.Equals(kvp.Key, paramName, StringComparison.OrdinalIgnoreCase));

                if (mappingEntry.Key != null)
                {
                    var jsonPath = mappingEntry.Value;
                    var fieldName = jsonPath.TrimStart('$', '.');

                    // Case-insensitive lookup in message data
                    var value = GetValueCaseInsensitive(messageData, fieldName);

                    if (value != null)
                    {
                        command.Parameters.AddWithValue($"@{paramName}", value);
                    }
                    else if (jsonPath.StartsWith("\"") || !jsonPath.Contains("$"))
                    {
                        // Constant value
                        command.Parameters.AddWithValue($"@{paramName}", jsonPath.Trim('"'));
                    }
                    else
                    {
                        command.Parameters.AddWithValue($"@{paramName}", DBNull.Value);
                    }
                }
                else
                {
                    // Parameter not in mapping, set to NULL
                    command.Parameters.AddWithValue($"@{paramName}", DBNull.Value);
                }
            }

            await command.ExecuteNonQueryAsync();
        }

        private async Task<List<string>> GetStoredProcParametersAsync(SqlConnection connection, string procName)
        {
            var parameters = new List<string>();

            // Parse schema and proc name
            var parts = procName.Split('.');
            var schema = parts.Length > 1 ? parts[0] : "dbo";
            var name = parts.Length > 1 ? parts[1] : parts[0];

            var query = @"
                SELECT PARAMETER_NAME
                FROM INFORMATION_SCHEMA.PARAMETERS
                WHERE SPECIFIC_SCHEMA = @Schema
                  AND SPECIFIC_NAME = @Name
                  AND PARAMETER_MODE = 'IN'
                ORDER BY ORDINAL_POSITION";

            using var cmd = new SqlCommand(query, connection);
            cmd.Parameters.AddWithValue("@Schema", schema);
            cmd.Parameters.AddWithValue("@Name", name);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var paramName = reader.GetString(0).TrimStart('@');
                parameters.Add(paramName);
            }

            return parameters;
        }

        private async Task ExecuteDirectInsertAsync(
            SqlConnection connection,
            TopicTableMapping mapping,
            Dictionary<string, object> messageData,
            Dictionary<string, string> columnMapping)
        {
            var columns = new List<string>();
            var values = new List<object>();

            foreach (var kvp in columnMapping)
            {
                var dbColumnName = kvp.Key;
                var jsonPath = kvp.Value;

                // Extract field name from JSON path or use constant
                var fieldName = jsonPath.TrimStart('$', '.');

                object? value = null;

                // Case-insensitive lookup in message data
                var msgValue = GetValueCaseInsensitive(messageData, fieldName);
                if (msgValue != null)
                {
                    value = msgValue;
                }
                else if (decimal.TryParse(jsonPath, out var constantDecimal))
                {
                    // Numeric constant (e.g., 75.0 for Threshold)
                    value = constantDecimal;
                }
                else if (jsonPath.StartsWith("\"") || !jsonPath.Contains("$"))
                {
                    // String constant (e.g., "HighTemperature" for AlertType)
                    value = jsonPath.Trim('"');
                }

                if (value != null)
                {
                    columns.Add(dbColumnName);
                    values.Add(value);
                }
            }

            if (columns.Count == 0)
            {
                throw new InvalidOperationException("No columns to insert");
            }

            var sql = $@"
                INSERT INTO {mapping.TargetSchema}.{mapping.TargetTable}
                ({string.Join(", ", columns)})
                VALUES
                ({string.Join(", ", columns.Select((_, i) => $"@p{i}"))})";

            using var command = new SqlCommand(sql, connection);

            for (int i = 0; i < values.Count; i++)
            {
                command.Parameters.AddWithValue($"@p{i}", values[i] ?? DBNull.Value);
            }

            await command.ExecuteNonQueryAsync();
        }
    }
}
