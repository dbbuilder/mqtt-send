using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using System.Data;

namespace MonitorDashboard.Pages;

public class ConfigurationModel : PageModel
{
    private readonly ILogger<ConfigurationModel> _logger;
    private readonly IConfiguration _configuration;

    public ConfigurationModel(ILogger<ConfigurationModel> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    [TempData]
    public string? SuccessMessage { get; set; }

    [TempData]
    public string? ErrorMessage { get; set; }

    public List<ReceiverConfig> Configurations { get; set; } = new();

    public class ReceiverConfig
    {
        public int Id { get; set; }
        public string ConfigName { get; set; } = string.Empty;
        public string TopicPattern { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string MessageFormat { get; set; } = "JSON";
        public int QoS { get; set; }
        public bool Enabled { get; set; }
    }

    public async Task OnGetAsync()
    {
        await LoadConfigurationsAsync();
    }

    public async Task<IActionResult> OnPostAddConfigAsync(
        string configName,
        string topicPattern,
        string messageFormat,
        string fieldMappingJson,
        int qoS,
        bool enabled,
        string targetTable,
        string insertMode,
        int priority,
        bool tableEnabled,
        string? filterExpression)
    {
        try
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge");
            if (string.IsNullOrEmpty(connectionString))
            {
                throw new InvalidOperationException("Connection string 'MqttBridge' not found");
            }

            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            // Start transaction
            await using var transaction = connection.BeginTransaction();

            try
            {
                // 1. Insert ReceiverConfig
                var insertConfigSql = @"
                    INSERT INTO MQTT.ReceiverConfig
                        (ConfigName, TopicPattern, MessageFormat, FieldMappingJson, QoS, Enabled, CreatedAt, UpdatedAt)
                    VALUES
                        (@ConfigName, @TopicPattern, @MessageFormat, @FieldMappingJson, @QoS, @Enabled, GETUTCDATE(), GETUTCDATE());
                    SELECT CAST(SCOPE_IDENTITY() AS INT);";

                int configId;
                await using (var cmd = new SqlCommand(insertConfigSql, connection, transaction))
                {
                    cmd.Parameters.AddWithValue("@ConfigName", configName);
                    cmd.Parameters.AddWithValue("@TopicPattern", topicPattern);
                    cmd.Parameters.AddWithValue("@MessageFormat", messageFormat);
                    cmd.Parameters.AddWithValue("@FieldMappingJson", fieldMappingJson);
                    cmd.Parameters.AddWithValue("@QoS", qoS);
                    cmd.Parameters.AddWithValue("@Enabled", enabled);

                    var result = await cmd.ExecuteScalarAsync();
                    configId = Convert.ToInt32(result);
                }

                // 2. Insert TopicTableMapping
                var insertMappingSql = @"
                    INSERT INTO MQTT.TopicTableMapping
                        (ReceiverConfigId, TargetTable, InsertMode, Priority, FilterExpression, Enabled, CreatedAt)
                    VALUES
                        (@ReceiverConfigId, @TargetTable, @InsertMode, @Priority, @FilterExpression, @Enabled, GETUTCDATE());";

                await using (var cmd = new SqlCommand(insertMappingSql, connection, transaction))
                {
                    cmd.Parameters.AddWithValue("@ReceiverConfigId", configId);
                    cmd.Parameters.AddWithValue("@TargetTable", targetTable);
                    cmd.Parameters.AddWithValue("@InsertMode", insertMode);
                    cmd.Parameters.AddWithValue("@Priority", priority);
                    cmd.Parameters.AddWithValue("@FilterExpression", (object?)filterExpression ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Enabled", tableEnabled);

                    await cmd.ExecuteNonQueryAsync();
                }

                await transaction.CommitAsync();

                SuccessMessage = $"✓ Configuration '{configName}' added successfully! Receiver will auto-reload within 30 seconds.";
                _logger.LogInformation("Added new receiver configuration: {ConfigName}", configName);
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Failed to add configuration: {ex.Message}";
            _logger.LogError(ex, "Error adding receiver configuration");
        }

        await LoadConfigurationsAsync();
        return Page();
    }

    private async Task LoadConfigurationsAsync()
    {
        try
        {
            var connectionString = _configuration.GetConnectionString("MqttBridge");
            if (string.IsNullOrEmpty(connectionString))
            {
                _logger.LogWarning("Connection string 'MqttBridge' not found");
                return;
            }

            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            var sql = @"
                SELECT
                    Id,
                    ConfigName,
                    TopicPattern,
                    Description,
                    MessageFormat,
                    QoS,
                    Enabled
                FROM MQTT.ReceiverConfig
                ORDER BY CreatedAt DESC";

            await using var cmd = new SqlCommand(sql, connection);
            await using var reader = await cmd.ExecuteReaderAsync();

            Configurations = new List<ReceiverConfig>();
            while (await reader.ReadAsync())
            {
                Configurations.Add(new ReceiverConfig
                {
                    Id = reader.GetInt32(0),
                    ConfigName = reader.GetString(1),
                    TopicPattern = reader.GetString(2),
                    Description = reader.IsDBNull(3) ? null : reader.GetString(3),
                    MessageFormat = reader.GetString(4),
                    QoS = reader.GetByte(5),
                    Enabled = reader.GetBoolean(6)
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading receiver configurations");
            ErrorMessage = "Failed to load configurations";
        }
    }
}
