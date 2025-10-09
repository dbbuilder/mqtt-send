using Microsoft.Data.SqlClient;
using MQTTnet;
using MQTTnet.Client;
using System.Text;
using System.Text.Json;

namespace MonitorDashboard.Services;

public class TestingService
{
    private readonly string _connectionString;
    private readonly ILogger<TestingService> _logger;
    private readonly IMqttClient _mqttClient;

    public TestingService(IConfiguration configuration, ILogger<TestingService> logger)
    {
        _connectionString = configuration.GetConnectionString("MqttBridge")
            ?? throw new InvalidOperationException("Connection string 'MqttBridge' not found.");
        _logger = logger;

        // Create MQTT client for testing
        var factory = new MqttFactory();
        _mqttClient = factory.CreateMqttClient();
    }

    public async Task<TestResult> SendTestMqttMessageAsync(string topic, string deviceId, string sensorType, double value, string unit)
    {
        try
        {
            // Connect to MQTT broker if not connected
            if (!_mqttClient.IsConnected)
            {
                var options = new MqttClientOptionsBuilder()
                    .WithTcpServer("localhost", 1883)
                    .WithClientId("DashboardTestClient")
                    .Build();

                await _mqttClient.ConnectAsync(options);
            }

            // Create test message payload (using generic Value field)
            var payload = new
            {
                MonitorId = deviceId,
                SensorType = sensorType,
                Value = value,
                Unit = unit,
                Location = "Dashboard Test",
                Timestamp = DateTime.UtcNow
            };

            var jsonPayload = JsonSerializer.Serialize(payload);

            // Publish message
            var message = new MqttApplicationMessageBuilder()
                .WithTopic(topic)
                .WithPayload(jsonPayload)
                .WithQualityOfServiceLevel(MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce)
                .Build();

            await _mqttClient.PublishAsync(message);

            _logger.LogInformation("Test message published to topic: {Topic}", topic);

            return new TestResult
            {
                Success = true,
                Message = $"✓ Published to {topic}",
                Details = jsonPayload
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending test MQTT message");
            return new TestResult
            {
                Success = false,
                Message = $"✗ Failed to publish: {ex.Message}",
                Details = null
            };
        }
    }

    public async Task<TestResult> InsertTestDataAsync(string tableName, int monitorId)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            string insertQuery = tableName.ToLower() switch
            {
                "tablea" => @"
                    INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location, Timestamp)
                    VALUES (@MonitorId, 'temperature', @Value, 'F', 'Dashboard Test', GETUTCDATE())",

                "tableb" => @"
                    INSERT INTO dbo.TableB (MonitorId, SensorType, Pressure, Unit, Location, Timestamp)
                    VALUES (@MonitorId, 'pressure', @Value, 'PSI', 'Dashboard Test', GETUTCDATE())",

                "tablec" => @"
                    INSERT INTO dbo.TableC (MonitorId, SensorType, FlowRate, Unit, Location, Timestamp)
                    VALUES (@MonitorId, 'flow', @Value, 'GPM', 'Dashboard Test', GETUTCDATE())",

                _ => throw new ArgumentException($"Unknown table: {tableName}")
            };

            var value = Random.Shared.Next(70, 100) + Random.Shared.NextDouble();

            await using var command = new SqlCommand(insertQuery, connection);
            command.Parameters.AddWithValue("@MonitorId", monitorId);
            command.Parameters.AddWithValue("@Value", value);

            await command.ExecuteNonQueryAsync();

            _logger.LogInformation("Test data inserted into {TableName} for MonitorId {MonitorId}", tableName, monitorId);

            return new TestResult
            {
                Success = true,
                Message = $"✓ Inserted test data into {tableName}",
                Details = $"MonitorId: {monitorId}, Value: {value:F2}"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error inserting test data");
            return new TestResult
            {
                Success = false,
                Message = $"✗ Failed to insert: {ex.Message}",
                Details = null
            };
        }
    }

    public async Task<TestResult> ClearTestDataAsync()
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var queries = new[]
            {
                "DELETE FROM dbo.RawSensorData WHERE DeviceId IN ('TEST1', 'TEST2')",
                "DELETE FROM MQTT.ReceivedMessages WHERE Topic LIKE 'test/%'",
                "DELETE FROM MQTT.SentRecords WHERE Topic LIKE 'test/%'"
            };

            int totalDeleted = 0;
            foreach (var query in queries)
            {
                await using var command = new SqlCommand(query, connection);
                totalDeleted += await command.ExecuteNonQueryAsync();
            }

            _logger.LogInformation("Cleared {Count} test records", totalDeleted);

            return new TestResult
            {
                Success = true,
                Message = $"✓ Cleared {totalDeleted} test records",
                Details = null
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error clearing test data");
            return new TestResult
            {
                Success = false,
                Message = $"✗ Failed to clear data: {ex.Message}",
                Details = null
            };
        }
    }

    public async Task<TestResult> GetLatestReceivedDataAsync()
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"
                SELECT TOP 5
                    CONVERT(VARCHAR, ReceivedAt, 120) as ReceivedAt,
                    DeviceId,
                    SensorType,
                    Value,
                    Unit
                FROM dbo.RawSensorData
                ORDER BY ReceivedAt DESC";

            await using var command = new SqlCommand(query, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var results = new List<string>();
            while (await reader.ReadAsync())
            {
                results.Add($"{reader.GetString(0)} | Device:{reader.GetString(1)} | {reader.GetString(2)}={reader.GetDecimal(3)}{reader.GetString(4)}");
            }

            return new TestResult
            {
                Success = true,
                Message = "Latest received data:",
                Details = string.Join("\n", results)
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting latest data");
            return new TestResult
            {
                Success = false,
                Message = $"✗ Failed: {ex.Message}",
                Details = null
            };
        }
    }
}

public class TestResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? Details { get; set; }
}
