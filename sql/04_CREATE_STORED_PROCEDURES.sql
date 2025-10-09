-- =============================================
-- Script: 04_CREATE_STORED_PROCEDURES.sql
-- Description: Creates all stored procedures
-- Database: MqttBridge
-- =============================================

USE MqttBridge;
GO

-- =============================================
-- dbo Schema Stored Procedures
-- =============================================

-- Procedure: dbo.GetPendingMessages
IF OBJECT_ID('dbo.GetPendingMessages', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetPendingMessages;
GO

CREATE PROCEDURE dbo.GetPendingMessages
    @BatchSize INT = 100
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@BatchSize)
        MessageId,
        MonitorId,
        MessageContent,
        Priority,
        CreatedDate,
        ProcessedDate,
        Status,
        RetryCount,
        ErrorMessage,
        CorrelationId
    FROM dbo.Messages
    WHERE Status = 'Pending'
    ORDER BY MonitorId, Priority ASC, CreatedDate ASC;
END
GO

-- Procedure: dbo.UpdateMessageStatus
IF OBJECT_ID('dbo.UpdateMessageStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.UpdateMessageStatus;
GO

CREATE PROCEDURE dbo.UpdateMessageStatus
    @MessageId BIGINT,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @IncrementRetryCount BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE dbo.Messages
        SET
            Status = @Status,
            ProcessedDate = CASE WHEN @Status = 'Published' THEN SYSUTCDATETIME() ELSE ProcessedDate END,
            ErrorMessage = @ErrorMessage,
            RetryCount = CASE WHEN @IncrementRetryCount = 1 THEN RetryCount + 1 ELSE RetryCount END
        WHERE MessageId = @MessageId;

        SELECT @@ROWCOUNT AS RowsAffected;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END
GO

-- Procedure: dbo.CleanupExpiredMessages
IF OBJECT_ID('dbo.CleanupExpiredMessages', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CleanupExpiredMessages;
GO

CREATE PROCEDURE dbo.CleanupExpiredMessages
    @RetentionDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME());
    DECLARE @DeletedCount INT;

    BEGIN TRY
        DELETE FROM dbo.Messages
        WHERE CreatedDate < @CutoffDate
        AND Status IN ('Published', 'Failed');

        SET @DeletedCount = @@ROWCOUNT;

        SELECT
            @DeletedCount AS DeletedCount,
            @CutoffDate AS CutoffDate,
            @RetentionDays AS RetentionDays;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END
GO

-- Procedure: dbo.GetMessageStats
IF OBJECT_ID('dbo.GetMessageStats', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetMessageStats;
GO

CREATE PROCEDURE dbo.GetMessageStats
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Status,
        COUNT(*) AS MessageCount,
        MIN(CreatedDate) AS OldestMessage,
        MAX(CreatedDate) AS NewestMessage,
        AVG(DATEDIFF(SECOND, CreatedDate, COALESCE(ProcessedDate, SYSUTCDATETIME()))) AS AvgProcessingTimeSeconds
    FROM dbo.Messages
    GROUP BY Status;

    SELECT
        MonitorId,
        COUNT(*) AS MessageCount,
        MAX(CreatedDate) AS LastMessageDate
    FROM dbo.Messages
    WHERE Status = 'Pending'
    GROUP BY MonitorId
    ORDER BY MessageCount DESC;
END
GO

-- Procedure: dbo.sp_MarkRecordsSent
IF OBJECT_ID('dbo.sp_MarkRecordsSent', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_MarkRecordsSent;
GO

CREATE PROCEDURE dbo.sp_MarkRecordsSent
    @SourceTable NVARCHAR(100),
    @RecordIds NVARCHAR(MAX),
    @CorrelationId UNIQUEIDENTIFIER = NULL,
    @Topic NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RecordIdTable TABLE (RecordId NVARCHAR(100));

    INSERT INTO @RecordIdTable (RecordId)
    SELECT TRIM(value)
    FROM STRING_SPLIT(@RecordIds, ',')
    WHERE TRIM(value) <> '';

    INSERT INTO dbo.MqttSentRecords (SourceTable, RecordId, SentAt, CorrelationId, Topic)
    SELECT
        @SourceTable,
        r.RecordId,
        GETUTCDATE(),
        @CorrelationId,
        @Topic
    FROM @RecordIdTable r
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.MqttSentRecords m
        WHERE m.SourceTable = @SourceTable
        AND m.RecordId = r.RecordId
    );

    SELECT @@ROWCOUNT AS RecordsMarked;
END
GO

-- Procedure: dbo.sp_CleanupMqttTracking
IF OBJECT_ID('dbo.sp_CleanupMqttTracking', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CleanupMqttTracking;
GO

CREATE PROCEDURE dbo.sp_CleanupMqttTracking
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
        FROM dbo.MqttSentRecords
        WHERE SentAt < @CutoffDate;

        SET @RowsDeleted = @@ROWCOUNT;
        SET @TotalDeleted = @TotalDeleted + @RowsDeleted;

        IF @RowsDeleted > 0
            WAITFOR DELAY '00:00:00.100';
    END

    SELECT @TotalDeleted AS TotalRecordsDeleted;
END
GO

-- Procedure: dbo.sp_GetUnsentRecords_TableA
IF OBJECT_ID('dbo.sp_GetUnsentRecords_TableA', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetUnsentRecords_TableA;
GO

CREATE PROCEDURE dbo.sp_GetUnsentRecords_TableA
    @BatchSize INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@BatchSize)
        a.RecordId,
        a.MonitorId,
        a.SensorType,
        a.Temperature AS Value,
        a.Unit,
        a.Location,
        a.Timestamp,
        a.CreatedAt,
        DATEDIFF(MILLISECOND, a.CreatedAt, GETUTCDATE()) AS LagMs
    FROM dbo.TableA a
    LEFT JOIN dbo.MqttSentRecords m
        ON m.SourceTable = 'TableA'
        AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
    WHERE m.Id IS NULL
    ORDER BY a.CreatedAt ASC;
END
GO

-- Procedure: dbo.sp_GetUnsentRecords_TableB
IF OBJECT_ID('dbo.sp_GetUnsentRecords_TableB', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetUnsentRecords_TableB;
GO

CREATE PROCEDURE dbo.sp_GetUnsentRecords_TableB
    @BatchSize INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@BatchSize)
        b.RecordId,
        b.MonitorId,
        b.SensorType,
        b.Pressure AS Value,
        b.Unit,
        b.Location,
        b.Timestamp,
        b.CreatedAt,
        DATEDIFF(MILLISECOND, b.CreatedAt, GETUTCDATE()) AS LagMs
    FROM dbo.TableB b
    LEFT JOIN dbo.MqttSentRecords m
        ON m.SourceTable = 'TableB'
        AND m.RecordId = CAST(b.RecordId AS NVARCHAR(100))
    WHERE m.Id IS NULL
    ORDER BY b.CreatedAt ASC;
END
GO

-- Procedure: dbo.sp_GetUnsentRecords_TableC
IF OBJECT_ID('dbo.sp_GetUnsentRecords_TableC', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetUnsentRecords_TableC;
GO

CREATE PROCEDURE dbo.sp_GetUnsentRecords_TableC
    @BatchSize INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@BatchSize)
        c.RecordId,
        c.MonitorId,
        c.SensorType,
        c.FlowRate AS Value,
        c.Unit,
        c.Location,
        c.Timestamp,
        c.CreatedAt,
        DATEDIFF(MILLISECOND, c.CreatedAt, GETUTCDATE()) AS LagMs
    FROM dbo.TableC c
    LEFT JOIN dbo.MqttSentRecords m
        ON m.SourceTable = 'TableC'
        AND m.RecordId = CAST(c.RecordId AS NVARCHAR(100))
    WHERE m.Id IS NULL
    ORDER BY c.CreatedAt ASC;
END
GO

-- Procedure: dbo.UpdateSensorAggregate
IF OBJECT_ID('dbo.UpdateSensorAggregate', 'P') IS NOT NULL
    DROP PROCEDURE dbo.UpdateSensorAggregate;
GO

CREATE PROCEDURE dbo.UpdateSensorAggregate
    @DeviceId NVARCHAR(50),
    @SensorType NVARCHAR(50),
    @Value DECIMAL(18,4),
    @Timestamp DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HourBucket DATETIME2 = DATEADD(HOUR, DATEDIFF(HOUR, 0, @Timestamp), 0);

    MERGE dbo.SensorAggregates AS target
    USING (SELECT @DeviceId AS DeviceId, @SensorType AS SensorType, @HourBucket AS FirstReading) AS source
    ON target.DeviceId = source.DeviceId
       AND target.SensorType = source.SensorType
       AND target.FirstReading = source.FirstReading
    WHEN MATCHED THEN
        UPDATE SET
            LatestValue = @Value,
            ReadingCount = target.ReadingCount + 1,
            LastReading = @Timestamp
    WHEN NOT MATCHED THEN
        INSERT (DeviceId, SensorType, FirstReading, LastReading, ReadingCount, LatestValue)
        VALUES (@DeviceId, @SensorType, @HourBucket, @Timestamp, 1, @Value);
END
GO

-- =============================================
-- MQTT Schema Stored Procedures
-- =============================================

-- Procedure: MQTT.GetActiveReceiverConfigs
IF OBJECT_ID('MQTT.GetActiveReceiverConfigs', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.GetActiveReceiverConfigs;
GO

CREATE PROCEDURE MQTT.GetActiveReceiverConfigs
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

-- Procedure: MQTT.LogReceivedMessage
IF OBJECT_ID('MQTT.LogReceivedMessage', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.LogReceivedMessage;
GO

CREATE PROCEDURE MQTT.LogReceivedMessage
    @ReceiverConfigId INT,
    @Topic NVARCHAR(500),
    @Payload NVARCHAR(MAX),
    @QoS TINYINT = 1,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.ReceivedMessages (ReceiverConfigId, Topic, Payload, ReceivedAt, Status, CorrelationId)
    VALUES (@ReceiverConfigId, @Topic, @Payload, SYSUTCDATETIME(), 'Pending', @CorrelationId);

    SELECT SCOPE_IDENTITY() AS MessageId;
END
GO

-- Procedure: MQTT.UpdateReceivedMessageStatus
IF OBJECT_ID('MQTT.UpdateReceivedMessageStatus', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.UpdateReceivedMessageStatus;
GO

CREATE PROCEDURE MQTT.UpdateReceivedMessageStatus
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
        ProcessedAt = SYSUTCDATETIME(),
        ErrorMessage = @ErrorMessage
    WHERE Id = @MessageId;
END
GO

-- Procedure: MQTT.AddReceiverConfig
IF OBJECT_ID('MQTT.AddReceiverConfig', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.AddReceiverConfig;
GO

CREATE PROCEDURE MQTT.AddReceiverConfig
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

-- Procedure: MQTT.AddTopicTableMapping
IF OBJECT_ID('MQTT.AddTopicTableMapping', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.AddTopicTableMapping;
GO

CREATE PROCEDURE MQTT.AddTopicTableMapping
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

-- Procedure: MQTT.GetReceiverConfigCount
IF OBJECT_ID('MQTT.GetReceiverConfigCount', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.GetReceiverConfigCount;
GO

CREATE PROCEDURE MQTT.GetReceiverConfigCount
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS ConfigCount
    FROM MQTT.ReceiverConfig
    WHERE Enabled = 1;
END
GO

-- Procedure: MQTT.GetActiveConfigurations
IF OBJECT_ID('MQTT.GetActiveConfigurations', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.GetActiveConfigurations;
GO

CREATE PROCEDURE MQTT.GetActiveConfigurations
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

-- Procedure: MQTT.GetUnsentRecords
IF OBJECT_ID('MQTT.GetUnsentRecords', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.GetUnsentRecords;
GO

CREATE PROCEDURE MQTT.GetUnsentRecords
    @SourceName NVARCHAR(100),
    @TableName NVARCHAR(200),
    @PrimaryKeyColumn NVARCHAR(100),
    @Columns NVARCHAR(MAX),
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

-- Procedure: MQTT.MarkRecordsSent
IF OBJECT_ID('MQTT.MarkRecordsSent', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.MarkRecordsSent;
GO

CREATE PROCEDURE MQTT.MarkRecordsSent
    @SourceName NVARCHAR(100),
    @RecordIds NVARCHAR(MAX),
    @CorrelationId UNIQUEIDENTIFIER = NULL,
    @Topic NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RecordIdTable TABLE (RecordId NVARCHAR(100));

    INSERT INTO @RecordIdTable (RecordId)
    SELECT TRIM(value)
    FROM STRING_SPLIT(@RecordIds, ',')
    WHERE TRIM(value) <> '';

    INSERT INTO MQTT.SentRecords (SourceName, RecordId, SentAt, CorrelationId, Topic)
    SELECT
        @SourceName,
        r.RecordId,
        SYSUTCDATETIME(),
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

-- Procedure: MQTT.CleanupSentRecords
IF OBJECT_ID('MQTT.CleanupSentRecords', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.CleanupSentRecords;
GO

CREATE PROCEDURE MQTT.CleanupSentRecords
    @RetentionDays INT = 7,
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowsDeleted INT = 1;
    DECLARE @TotalDeleted INT = 0;
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME());

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

-- Procedure: MQTT.AddSourceConfiguration
IF OBJECT_ID('MQTT.AddSourceConfiguration', 'P') IS NOT NULL
    DROP PROCEDURE MQTT.AddSourceConfiguration;
GO

CREATE PROCEDURE MQTT.AddSourceConfiguration
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
-- Logging Schema Stored Procedures
-- =============================================

-- Procedure: Logging.GetRecentLogs
IF OBJECT_ID('Logging.GetRecentLogs', 'P') IS NOT NULL
    DROP PROCEDURE Logging.GetRecentLogs;
GO

CREATE PROCEDURE Logging.GetRecentLogs
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
        MachineName,
        ProcessId,
        ThreadId
    FROM Logging.ApplicationLogs
    WHERE
        Timestamp >= DATEADD(MINUTE, -@MinutesBack, SYSUTCDATETIME())
        AND (@ServiceName IS NULL OR ServiceName = @ServiceName)
        AND (@Level IS NULL OR Level = @Level)
    ORDER BY Timestamp DESC;
END
GO

-- Procedure: Logging.GetErrorStatistics
IF OBJECT_ID('Logging.GetErrorStatistics', 'P') IS NOT NULL
    DROP PROCEDURE Logging.GetErrorStatistics;
GO

CREATE PROCEDURE Logging.GetErrorStatistics
    @HoursBack INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ServiceName,
        Level,
        COUNT(*) AS ErrorCount,
        MIN(Timestamp) AS FirstOccurrence,
        MAX(Timestamp) AS LastOccurrence
    FROM Logging.ApplicationLogs
    WHERE
        Timestamp >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
        AND Level IN ('Error', 'Fatal')
    GROUP BY ServiceName, Level
    ORDER BY ErrorCount DESC, ServiceName;
END
GO

-- Procedure: Logging.CleanupOldLogs
IF OBJECT_ID('Logging.CleanupOldLogs', 'P') IS NOT NULL
    DROP PROCEDURE Logging.CleanupOldLogs;
GO

CREATE PROCEDURE Logging.CleanupOldLogs
    @DaysToKeep INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DeletedCount INT;

    DELETE FROM Logging.ApplicationLogs
    WHERE Timestamp < DATEADD(DAY, -@DaysToKeep, SYSUTCDATETIME());

    SET @DeletedCount = @@ROWCOUNT;

    SELECT
        @DeletedCount AS DeletedCount,
        @DaysToKeep AS DaysKept,
        SYSUTCDATETIME() AS CleanupTime;
END
GO

PRINT 'All stored procedures created successfully';
PRINT 'Total: 24 procedures';
GO
