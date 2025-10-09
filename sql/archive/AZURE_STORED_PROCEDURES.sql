-- =============================================
-- Exported Stored Procedures
-- Database: MqttBridge
-- Server: localhost,1433
-- Date: 2025-10-09 06:30:53
-- Filter: *
-- =============================================
 
-- =============================================
-- Procedure: MQTT.GetActiveReceiverConfigs
-- =============================================

-- =============================================
-- Stored Procedure: Get Active Receiver Configurations
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.GetActiveReceiverConfigs
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        rc.Id,
        rc.ConfigName,
        rc.TopicPattern,
        rc.Description,
        rc.MessageFormat,
        rc.FieldMappingJson,
        rc.QoS,
        rc.Enabled,

        -- Include all table mappings as JSON array
        (
            SELECT
                tm.Id,
                tm.TargetSchema,
                tm.TargetTable,
                tm.InsertMode,
                tm.StoredProcName,
                tm.ColumnMappingJson,
                tm.FilterCondition,
                tm.Enabled,
                tm.Priority,
                tm.ContinueOnError
            FROM MQTT.TopicTableMapping tm
            WHERE tm.ReceiverConfigId = rc.Id
              AND tm.Enabled = 1
            ORDER BY tm.Priority DESC
            FOR JSON PATH
        ) AS TableMappingsJson

    FROM MQTT.ReceiverConfig rc
    WHERE rc.Enabled = 1
    ORDER BY rc.ConfigName;
END

GO
 
-- =============================================
-- Procedure: MQTT.LogReceivedMessage
-- =============================================

-- =============================================
-- Stored Procedure: Log Received Message
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.LogReceivedMessage
    @ReceiverConfigId INT,
    @Topic NVARCHAR(500),
    @Payload NVARCHAR(MAX),
    @QoS TINYINT,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.ReceivedMessages (ReceiverConfigId, Topic, Payload, QoS, CorrelationId)
    VALUES (@ReceiverConfigId, @Topic, @Payload, @QoS, @CorrelationId);

    SELECT SCOPE_IDENTITY() AS MessageId;
END

GO
 
-- =============================================
-- Procedure: MQTT.UpdateReceivedMessageStatus
-- =============================================

-- =============================================
-- Stored Procedure: Update Message Status
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.UpdateReceivedMessageStatus
    @MessageId BIGINT,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @TargetTablesProcessed INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE MQTT.ReceivedMessages
    SET
        Status = @Status,
        ProcessedAt = GETUTCDATE(),
        ErrorMessage = @ErrorMessage,
        TargetTablesProcessed = @TargetTablesProcessed
    WHERE Id = @MessageId;
END

GO
 
-- =============================================
-- Procedure: MQTT.AddReceiverConfig
-- =============================================

-- =============================================
-- Stored Procedure: Add Receiver Configuration
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.AddReceiverConfig
    @ConfigName NVARCHAR(100),
    @TopicPattern NVARCHAR(500),
    @Description NVARCHAR(500) = NULL,
    @MessageFormat NVARCHAR(20) = 'JSON',
    @FieldMappingJson NVARCHAR(MAX) = NULL,
    @QoS TINYINT = 1,
    @Enabled BIT = 1,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.ReceiverConfig
    (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled, CreatedBy)
    VALUES
    (@ConfigName, @TopicPattern, @Description, @MessageFormat, @FieldMappingJson, @QoS, @Enabled, @CreatedBy);

    SELECT SCOPE_IDENTITY() AS ReceiverConfigId;
END

GO
 
-- =============================================
-- Procedure: MQTT.AddTopicTableMapping
-- =============================================

-- =============================================
-- Stored Procedure: Add Topic Table Mapping
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.AddTopicTableMapping
    @ReceiverConfigId INT,
    @TargetSchema NVARCHAR(50) = 'dbo',
    @TargetTable NVARCHAR(100),
    @InsertMode NVARCHAR(20) = 'Direct',
    @StoredProcName NVARCHAR(200) = NULL,
    @ColumnMappingJson NVARCHAR(MAX) = NULL,
    @FilterCondition NVARCHAR(500) = NULL,
    @Priority INT = 0,
    @ContinueOnError BIT = 1,
    @Enabled BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.TopicTableMapping
    (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, StoredProcName,
     ColumnMappingJson, FilterCondition, Priority, ContinueOnError, Enabled)
    VALUES
    (@ReceiverConfigId, @TargetSchema, @TargetTable, @InsertMode, @StoredProcName,
     @ColumnMappingJson, @FilterCondition, @Priority, @ContinueOnError, @Enabled);

    SELECT SCOPE_IDENTITY() AS MappingId;
END

GO
 
-- =============================================
-- Procedure: MQTT.GetReceiverConfigCount
-- =============================================

-- =============================================
-- Stored Procedure: Get Configuration Count (for auto-reload)
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.GetReceiverConfigCount
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS ConfigCount
    FROM MQTT.ReceiverConfig
    WHERE Enabled = 1;
END

GO
 
-- =============================================
-- Procedure: Logging.GetRecentLogs
-- =============================================

-- =============================================
-- Stored Procedure: Get Recent Logs
-- =============================================
CREATE OR ALTER PROCEDURE Logging.GetRecentLogs
    @ServiceName NVARCHAR(100) = NULL,
    @Level NVARCHAR(20) = NULL,
    @MinutesBack INT = 60,
    @MaxRows INT = 100
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@MaxRows)
        Id,
        Timestamp,
        Level,
        ServiceName,
        Message,
        Exception,
        Properties,
        CorrelationId
    FROM Logging.ApplicationLogs
    WHERE
        Timestamp >= DATEADD(MINUTE, -@MinutesBack, GETUTCDATE())
        AND (@ServiceName IS NULL OR ServiceName = @ServiceName)
        AND (@Level IS NULL OR Level = @Level)
    ORDER BY Timestamp DESC;
END

GO
 
-- =============================================
-- Procedure: Logging.GetErrorStatistics
-- =============================================

-- =============================================
-- Stored Procedure: Get Error Statistics
-- =============================================
CREATE OR ALTER PROCEDURE Logging.GetErrorStatistics
    @HoursBack INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ServiceName,
        Level,
        COUNT(*) as ErrorCount,
        MIN(Timestamp) as FirstOccurrence,
        MAX(Timestamp) as LastOccurrence
    FROM Logging.ApplicationLogs
    WHERE
        Timestamp >= DATEADD(HOUR, -@HoursBack, GETUTCDATE())
        AND Level IN ('Error', 'Fatal')
    GROUP BY ServiceName, Level
    ORDER BY ErrorCount DESC, ServiceName;
END

GO
 
-- =============================================
-- Procedure: Logging.CleanupOldLogs
-- =============================================

-- =============================================
-- Stored Procedure: Cleanup Old Logs
-- =============================================
CREATE OR ALTER PROCEDURE Logging.CleanupOldLogs
    @DaysToKeep INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DeletedCount INT;

    DELETE FROM Logging.ApplicationLogs
    WHERE Timestamp < DATEADD(DAY, -@DaysToKeep, GETUTCDATE());

    SET @DeletedCount = @@ROWCOUNT;

    SELECT
        @DeletedCount as DeletedCount,
        @DaysToKeep as DaysKept,
        GETUTCDATE() as CleanupTime;
END

GO
 
-- =============================================
-- Procedure: MQTT.GetActiveConfigurations
-- =============================================

-- ============================================================================
-- Step 4: Stored Procedures
-- ============================================================================

-- Get Active Configurations
CREATE OR ALTER PROCEDURE MQTT.GetActiveConfigurations
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        SourceName,
        Enabled,
        TableName,
        SchemaName,
        Description,
        PrimaryKeyColumn,
        MonitorIdColumn,
        WhereClause,
        OrderByClause,
        BatchSize,
        PollingIntervalSeconds,
        TopicPattern,
        QosLevel,
        RetainFlag,
        FieldMappingJson
    FROM MQTT.SourceConfig
    WHERE Enabled = 1
    ORDER BY SourceName;
END

GO
 
-- =============================================
-- Procedure: MQTT.GetUnsentRecords
-- =============================================

-- Get Unsent Records (Generic)
CREATE OR ALTER PROCEDURE MQTT.GetUnsentRecords
    @SourceName NVARCHAR(100),
    @TableName NVARCHAR(200),  -- Schema.Table
    @PrimaryKeyColumn NVARCHAR(100),
    @Columns NVARCHAR(MAX),  -- Comma-separated list
    @WhereClause NVARCHAR(1000),
    @OrderByClause NVARCHAR(200),
    @BatchSize INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
        SELECT TOP (@BatchSize)
            ' + @Columns + N'
        FROM ' + @TableName + N' t
        LEFT JOIN MQTT.SentRecords m
            ON m.SourceName = @SourceName
            AND m.RecordId = CAST(t.' + @PrimaryKeyColumn + N' AS NVARCHAR(100))
        WHERE m.Id IS NULL
            AND (' + @WhereClause + N')
        ORDER BY t.' + @OrderByClause;

    EXEC sp_executesql @SQL,
        N'@SourceName NVARCHAR(100), @BatchSize INT',
        @SourceName = @SourceName,
        @BatchSize = @BatchSize;
END

GO
 
-- =============================================
-- Procedure: MQTT.MarkRecordsSent
-- =============================================

-- Mark Records as Sent
CREATE OR ALTER PROCEDURE MQTT.MarkRecordsSent
    @SourceName NVARCHAR(100),
    @RecordIds NVARCHAR(MAX),  -- Comma-separated
    @CorrelationId UNIQUEIDENTIFIER = NULL,
    @Topic NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Parse comma-separated RecordIds
    DECLARE @RecordIdTable TABLE (RecordId NVARCHAR(100));

    INSERT INTO @RecordIdTable (RecordId)
    SELECT TRIM(value)
    FROM STRING_SPLIT(@RecordIds, ',')
    WHERE TRIM(value) <> '';

    -- Insert tracking records (ignore duplicates)
    INSERT INTO MQTT.SentRecords (SourceName, RecordId, SentAt, CorrelationId, Topic)
    SELECT
        @SourceName,
        r.RecordId,
        GETUTCDATE(),
        @CorrelationId,
        @Topic
    FROM @RecordIdTable r
    WHERE NOT EXISTS (
        SELECT 1
        FROM MQTT.SentRecords m
        WHERE m.SourceName = @SourceName
        AND m.RecordId = r.RecordId
    );

    SELECT @@ROWCOUNT AS RecordsMarked;
END

GO
 
-- =============================================
-- Procedure: MQTT.CleanupSentRecords
-- =============================================

-- Cleanup Old Tracking Records
CREATE OR ALTER PROCEDURE MQTT.CleanupSentRecords
    @RetentionDays INT = 7,
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowsDeleted INT = 1;
    DECLARE @TotalDeleted INT = 0;
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, GETUTCDATE());

    WHILE @RowsDeleted > 0
    BEGIN
        DELETE TOP (@BatchSize)
        FROM MQTT.SentRecords
        WHERE SentAt < @CutoffDate;

        SET @RowsDeleted = @@ROWCOUNT;
        SET @TotalDeleted = @TotalDeleted + @RowsDeleted;

        IF @RowsDeleted > 0
            WAITFOR DELAY '00:00:00.100';
    END

    SELECT @TotalDeleted AS TotalRecordsDeleted;
END

GO
 
-- =============================================
-- Procedure: MQTT.AddSourceConfiguration
-- =============================================

-- Add New Source Configuration
CREATE OR ALTER PROCEDURE MQTT.AddSourceConfiguration
    @SourceName NVARCHAR(100),
    @TableName NVARCHAR(100),
    @SchemaName NVARCHAR(50) = 'dbo',
    @Description NVARCHAR(500) = NULL,
    @PrimaryKeyColumn NVARCHAR(100),
    @MonitorIdColumn NVARCHAR(100),
    @TopicPattern NVARCHAR(500),
    @FieldMappingJson NVARCHAR(MAX),
    @WhereClause NVARCHAR(1000) = '1=1',
    @OrderByClause NVARCHAR(200) = 'CreatedAt ASC',
    @BatchSize INT = 1000,
    @PollingIntervalSeconds INT = 5,
    @QosLevel INT = 1,
    @RetainFlag BIT = 0,
    @Enabled BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.SourceConfig (
        SourceName, Enabled, TableName, SchemaName, Description,
        PrimaryKeyColumn, MonitorIdColumn, WhereClause, OrderByClause,
        BatchSize, PollingIntervalSeconds,
        TopicPattern, QosLevel, RetainFlag, FieldMappingJson
    )
    VALUES (
        @SourceName, @Enabled, @TableName, @SchemaName, @Description,
        @PrimaryKeyColumn, @MonitorIdColumn, @WhereClause, @OrderByClause,
        @BatchSize, @PollingIntervalSeconds,
        @TopicPattern, @QosLevel, @RetainFlag, @FieldMappingJson
    );

    SELECT SCOPE_IDENTITY() AS ConfigId;
END

GO
 
-- =============================================
-- Export Complete: 14 procedure(s)
-- =============================================
