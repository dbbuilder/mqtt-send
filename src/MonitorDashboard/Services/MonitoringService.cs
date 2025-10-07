using Microsoft.Data.SqlClient;
using MonitorDashboard.Models;

namespace MonitorDashboard.Services;

public class MonitoringService
{
    private readonly string _connectionString;
    private readonly ILogger<MonitoringService> _logger;

    public MonitoringService(IConfiguration configuration, ILogger<MonitoringService> logger)
    {
        _connectionString = configuration.GetConnectionString("MqttBridge")
            ?? throw new InvalidOperationException("Connection string 'MqttBridge' not found.");
        _logger = logger;
    }

    public async Task<SystemStatus> GetSystemStatusAsync()
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var status = new SystemStatus();

            // Get receiver config count
            await using var cmdReceiver = new SqlCommand(
                "SELECT COUNT(*) FROM MQTT.ReceiverConfig WHERE Enabled = 1",
                connection);
            status.ActiveSubscriptions = (int)(await cmdReceiver.ExecuteScalarAsync() ?? 0);

            // Get publisher source config count
            await using var cmdPublisher = new SqlCommand(
                "SELECT COUNT(*) FROM MQTT.SourceConfig WHERE Enabled = 1",
                connection);
            status.MonitoredTables = (int)(await cmdPublisher.ExecuteScalarAsync() ?? 0);

            // Check if we have recent activity (last 5 minutes)
            await using var cmdRecent = new SqlCommand(@"
                SELECT COUNT(*) FROM MQTT.ReceivedMessages
                WHERE ReceivedAt > DATEADD(MINUTE, -5, GETUTCDATE())",
                connection);
            var recentMessages = (int)(await cmdRecent.ExecuteScalarAsync() ?? 0);
            status.ReceiverConnected = recentMessages > 0 || status.ActiveSubscriptions > 0;

            // Check publisher activity (recent publications in last 5 minutes)
            await using var cmdRecentPubs = new SqlCommand(@"
                SELECT COUNT(*) FROM MQTT.SentRecords
                WHERE SentAt > DATEADD(MINUTE, -5, GETUTCDATE())",
                connection);
            var recentPublications = (int)(await cmdRecentPubs.ExecuteScalarAsync() ?? 0);
            status.PublisherConnected = recentPublications > 0 || status.MonitoredTables > 0;

            status.LastUpdate = DateTime.UtcNow;

            return status;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting system status");
            return new SystemStatus { LastUpdate = DateTime.UtcNow };
        }
    }

    public async Task<ReceiverStatus> GetReceiverStatusAsync()
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var status = new ReceiverStatus();

            // Get subscriptions
            await using var cmdSubs = new SqlCommand(@"
                SELECT rc.ConfigName, rc.TopicPattern, rc.Enabled,
                       COUNT(ttm.Id) as MappingCount
                FROM MQTT.ReceiverConfig rc
                LEFT JOIN MQTT.TopicTableMapping ttm ON rc.Id = ttm.ReceiverConfigId
                GROUP BY rc.ConfigName, rc.TopicPattern, rc.Enabled
                ORDER BY rc.ConfigName",
                connection);

            await using var readerSubs = await cmdSubs.ExecuteReaderAsync();
            while (await readerSubs.ReadAsync())
            {
                status.Subscriptions.Add(new TopicSubscription
                {
                    ConfigName = readerSubs.GetString(0),
                    TopicPattern = readerSubs.GetString(1),
                    IsEnabled = readerSubs.GetBoolean(2),
                    TableMappingCount = readerSubs.GetInt32(3)
                });
            }
            await readerSubs.CloseAsync();

            status.ConfigCount = status.Subscriptions.Count;

            // Get recent messages
            await using var cmdRecent = new SqlCommand(@"
                SELECT TOP 10
                    rm.Id, rm.Topic, rc.ConfigName, rm.ReceivedAt,
                    rm.Status, rm.TargetTablesProcessed, rm.ErrorMessage
                FROM MQTT.ReceivedMessages rm
                LEFT JOIN MQTT.ReceiverConfig rc ON rm.ReceiverConfigId = rc.Id
                ORDER BY rm.ReceivedAt DESC",
                connection);

            await using var readerRecent = await cmdRecent.ExecuteReaderAsync();
            while (await readerRecent.ReadAsync())
            {
                status.RecentMessages.Add(new RecentMessage
                {
                    Id = readerRecent.GetInt32(0),
                    Topic = readerRecent.GetString(1),
                    ConfigName = readerRecent.IsDBNull(2) ? "" : readerRecent.GetString(2),
                    ReceivedAt = readerRecent.GetDateTime(3),
                    Success = readerRecent.GetString(4) == "Success",
                    TablesAffected = readerRecent.IsDBNull(5) ? 0 : readerRecent.GetInt32(5),
                    ErrorMessage = readerRecent.IsDBNull(6) ? null : readerRecent.GetString(6)
                });
            }
            await readerRecent.CloseAsync();

            // Get statistics
            await using var cmdStats = new SqlCommand(@"
                SELECT
                    ISNULL(COUNT(*), 0) as TotalToday,
                    ISNULL(SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END), 0) as SuccessToday,
                    ISNULL(SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END), 0) as FailedToday
                FROM MQTT.ReceivedMessages
                WHERE ReceivedAt >= CAST(GETUTCDATE() AS DATE)",
                connection);

            await using var readerStats = await cmdStats.ExecuteReaderAsync();
            if (await readerStats.ReadAsync())
            {
                status.Statistics.TotalToday = readerStats.IsDBNull(0) ? 0 : readerStats.GetInt32(0);
                status.Statistics.SuccessToday = readerStats.IsDBNull(1) ? 0 : readerStats.GetInt32(1);
                status.Statistics.FailedToday = readerStats.IsDBNull(2) ? 0 : readerStats.GetInt32(2);
            }
            await readerStats.CloseAsync();

            // Get total all time
            await using var cmdTotal = new SqlCommand(
                "SELECT COUNT(*) FROM MQTT.ReceivedMessages",
                connection);
            status.Statistics.TotalAllTime = (int)(await cmdTotal.ExecuteScalarAsync() ?? 0);

            return status;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting receiver status");
            return new ReceiverStatus();
        }
    }

    public async Task<PublisherStatus> GetPublisherStatusAsync()
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var status = new PublisherStatus();

            // Get source configurations
            await using var cmdSources = new SqlCommand(@"
                SELECT SourceName, TopicPattern, Enabled, PollingIntervalSeconds, TableName
                FROM MQTT.SourceConfig
                ORDER BY SourceName",
                connection);

            await using var readerSources = await cmdSources.ExecuteReaderAsync();
            while (await readerSources.ReadAsync())
            {
                status.TableMonitors.Add(new TableMonitor
                {
                    TableName = readerSources.GetString(0),
                    Topic = readerSources.GetString(1),
                    IsEnabled = readerSources.GetBoolean(2),
                    PollingIntervalSeconds = readerSources.GetInt32(3)
                });
            }
            await readerSources.CloseAsync();

            status.MonitoredTableCount = status.TableMonitors.Count(m => m.IsEnabled);

            // Get recent sent records
            await using var cmdRecent = new SqlCommand(@"
                SELECT TOP 10
                    sr.Id, sr.SourceName, sr.Topic, sr.SentAt
                FROM MQTT.SentRecords sr
                ORDER BY sr.SentAt DESC",
                connection);

            await using var readerRecent = await cmdRecent.ExecuteReaderAsync();
            while (await readerRecent.ReadAsync())
            {
                status.RecentPublications.Add(new RecentPublication
                {
                    Id = (int)readerRecent.GetInt64(0), // BIGINT in SQL = Int64 in C#
                    TableName = readerRecent.GetString(1),
                    Topic = readerRecent.GetString(2),
                    PublishedAt = readerRecent.GetDateTime(3),
                    Success = true,
                    ErrorMessage = null
                });
            }
            await readerRecent.CloseAsync();

            // Get statistics
            await using var cmdStats = new SqlCommand(@"
                SELECT
                    ISNULL(COUNT(*), 0) as TotalToday,
                    ISNULL(COUNT(*), 0) as SuccessToday
                FROM MQTT.SentRecords
                WHERE SentAt >= CAST(GETUTCDATE() AS DATE)",
                connection);

            await using var readerStats = await cmdStats.ExecuteReaderAsync();
            if (await readerStats.ReadAsync())
            {
                status.Statistics.TotalToday = readerStats.IsDBNull(0) ? 0 : readerStats.GetInt32(0);
                status.Statistics.SuccessToday = readerStats.IsDBNull(1) ? 0 : readerStats.GetInt32(1);
                status.Statistics.FailedToday = 0; // No failure tracking yet
            }
            await readerStats.CloseAsync();

            // Get total all time
            await using var cmdTotal = new SqlCommand(
                "SELECT COUNT(*) FROM MQTT.SentRecords",
                connection);
            status.Statistics.TotalAllTime = (int)(await cmdTotal.ExecuteScalarAsync() ?? 0);

            return status;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting publisher status");
            return new PublisherStatus();
        }
    }

    public async Task<List<MessageFlowEvent>> GetRecentFlowEventsAsync(int count = 20)
    {
        var events = new List<MessageFlowEvent>();

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            // Get recent received and published messages combined
            await using var cmdEvents = new SqlCommand($@"
                SELECT TOP {count} *
                FROM (
                    -- Received messages
                    SELECT
                        rm.ReceivedAt as Timestamp,
                        'received' as Type,
                        rm.Topic,
                        rc.ConfigName as Details,
                        CASE WHEN rm.Status = 'Success' THEN 1 ELSE 0 END as Success
                    FROM MQTT.ReceivedMessages rm
                    LEFT JOIN MQTT.ReceiverConfig rc ON rm.ReceiverConfigId = rc.Id

                    UNION ALL

                    -- Published messages
                    SELECT
                        sr.SentAt as Timestamp,
                        'published' as Type,
                        sr.Topic,
                        sr.SourceName as Details,
                        1 as Success
                    FROM MQTT.SentRecords sr
                ) AS CombinedEvents
                ORDER BY Timestamp DESC",
                connection);

            await using var reader = await cmdEvents.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                events.Add(new MessageFlowEvent
                {
                    Timestamp = reader.GetDateTime(0),
                    Type = reader.GetString(1),
                    Topic = reader.GetString(2),
                    Details = reader.IsDBNull(3) ? null : reader.GetString(3),
                    Success = reader.GetInt32(4) == 1
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting recent flow events");
        }

        return events;
    }
}
