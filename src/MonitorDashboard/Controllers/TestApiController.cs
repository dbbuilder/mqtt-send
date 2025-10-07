using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using MQTTnet;
using MQTTnet.Client;
using System.Text.Json;

namespace MonitorDashboard.Controllers;

[ApiController]
[Route("api/test")]
public class TestApiController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<TestApiController> _logger;

    public TestApiController(IConfiguration configuration, ILogger<TestApiController> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost("send-message")]
    public async Task<IActionResult> SendMessage([FromBody] SendMessageRequest request)
    {
        try
        {
            var mqttFactory = new MqttFactory();
            using var mqttClient = mqttFactory.CreateMqttClient();

            var options = new MqttClientOptionsBuilder()
                .WithTcpServer("localhost", 1883)
                .Build();

            await mqttClient.ConnectAsync(options);

            var deviceId = $"device{new Random().Next(1, 5)}";
            var topic = $"sensor/{deviceId}/{request.SensorType}";
            var timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

            var payload = new
            {
                device_id = deviceId,
                sensor_type = request.SensorType,
                value = request.Value,
                unit = request.SensorType == "temperature" ? "F" : "kPa",
                timestamp = timestamp
            };

            var message = new MqttApplicationMessageBuilder()
                .WithTopic(topic)
                .WithPayload(JsonSerializer.Serialize(payload))
                .WithQualityOfServiceLevel(MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce)
                .Build();

            await mqttClient.PublishAsync(message);
            await mqttClient.DisconnectAsync();

            _logger.LogInformation("Sent test message to topic {Topic} with value {Value}", topic, request.Value);

            return Ok(new { success = true, topic, payload });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending test message");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost("send-bulk")]
    public async Task<IActionResult> SendBulkMessages([FromBody] SendBulkRequest request)
    {
        try
        {
            var mqttFactory = new MqttFactory();
            using var mqttClient = mqttFactory.CreateMqttClient();

            var options = new MqttClientOptionsBuilder()
                .WithTcpServer("localhost", 1883)
                .Build();

            await mqttClient.ConnectAsync(options);

            var messagesSent = 0;
            var random = new Random();
            var sensorTypes = new[] { "temperature", "pressure", "humidity" };

            for (int i = 0; i < request.Count; i++)
            {
                var sensorType = sensorTypes[random.Next(sensorTypes.Length)];
                var deviceId = $"device{random.Next(1, 10)}";
                var topic = $"sensor/{deviceId}/{sensorType}";

                var value = sensorType switch
                {
                    "temperature" => 65 + (random.NextDouble() * 30), // 65-95F
                    "pressure" => 95 + (random.NextDouble() * 10),    // 95-105 kPa
                    "humidity" => 30 + (random.NextDouble() * 50),    // 30-80%
                    _ => random.NextDouble() * 100
                };

                var payload = new
                {
                    device_id = deviceId,
                    sensor_type = sensorType,
                    value = Math.Round(value, 2),
                    unit = sensorType == "temperature" ? "F" : (sensorType == "pressure" ? "kPa" : "%"),
                    timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                };

                var message = new MqttApplicationMessageBuilder()
                    .WithTopic(topic)
                    .WithPayload(JsonSerializer.Serialize(payload))
                    .WithQualityOfServiceLevel(MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce)
                    .Build();

                await mqttClient.PublishAsync(message);
                messagesSent++;

                await Task.Delay(100); // Small delay between messages
            }

            await mqttClient.DisconnectAsync();

            _logger.LogInformation("Sent {Count} bulk test messages", messagesSent);

            return Ok(new { success = true, messagesSent });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending bulk messages");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost("trigger-publisher")]
    public async Task<IActionResult> TriggerPublisher([FromBody] TriggerPublisherRequest request)
    {
        try
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge");
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            // Insert a test record into the specified table
            var random = new Random();
            var monitorId = random.Next(1, 11).ToString();
            var value = 100 + (random.NextDouble() * 50);

            string sql = request.TableName switch
            {
                "TableA" => @"
                    INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location, Timestamp)
                    VALUES (@MonitorId, 'temperature', @Value, 'F', 'Building A - Floor 1', GETUTCDATE());
                    SELECT SCOPE_IDENTITY();",
                "TableB" => @"
                    INSERT INTO dbo.TableB (MonitorId, SensorType, Pressure, Unit, Location, Timestamp)
                    VALUES (@MonitorId, 'pressure', @Value, 'kPa', 'Building B - Floor 2', GETUTCDATE());
                    SELECT SCOPE_IDENTITY();",
                "TableC" => @"
                    INSERT INTO dbo.TableC (MonitorId, SensorType, FlowRate, Unit, Location, Timestamp)
                    VALUES (@MonitorId, 'flow', @Value, 'L/min', 'Building C - Floor 3', GETUTCDATE());
                    SELECT SCOPE_IDENTITY();",
                _ => throw new ArgumentException($"Unknown table: {request.TableName}")
            };

            await using var cmd = new SqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("@MonitorId", monitorId);
            cmd.Parameters.AddWithValue("@Value", value);

            var recordId = await cmd.ExecuteScalarAsync();

            _logger.LogInformation("Inserted test record into {TableName}: ID={RecordId}", request.TableName, recordId);

            return Ok(new
            {
                success = true,
                tableName = request.TableName,
                recordsPublished = 1,
                recordId = Convert.ToInt64(recordId)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error triggering publisher for table {TableName}", request.TableName);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost("clear-data")]
    public async Task<IActionResult> ClearData()
    {
        try
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge");
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            var sql = @"
                DELETE FROM dbo.RawSensorData;
                DELETE FROM dbo.SensorAlerts;
                DELETE FROM dbo.SensorAggregates;
                DELETE FROM MQTT.ReceivedMessages;
                DELETE FROM dbo.TableA;
                DELETE FROM dbo.TableB;
                DELETE FROM dbo.TableC;
                DELETE FROM MQTT.SentRecords;
                SELECT @@ROWCOUNT;";

            await using var cmd = new SqlCommand(sql, connection);
            var rowsDeleted = (int)(await cmd.ExecuteScalarAsync() ?? 0);

            _logger.LogInformation("Cleared all test data: {RowsDeleted} records deleted", rowsDeleted);

            return Ok(new { success = true, recordsDeleted = rowsDeleted });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error clearing test data");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}

public record SendMessageRequest(string SensorType, double Value);
public record SendBulkRequest(int Count);
public record TriggerPublisherRequest(string TableName);
