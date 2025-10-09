-- MQTT System Setup - All Objects in MQTT Schema
-- Run this single script to set up the complete system

USE MqttBridge;
GO

-- ============================================================================
-- Step 1: Create MQTT Schema
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'MQTT')
BEGIN
    EXEC('CREATE SCHEMA MQTT');
    PRINT 'Created MQTT schema';
END
GO

-- ============================================================================
-- Step 2: Create Configuration Table
-- ============================================================================

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SourceConfig' AND schema_id = SCHEMA_ID('MQTT'))
    DROP TABLE MQTT.SourceConfig;
GO

CREATE TABLE MQTT.SourceConfig (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    SourceName NVARCHAR(100) NOT NULL UNIQUE,
    Enabled BIT NOT NULL DEFAULT 1,
    TableName NVARCHAR(100) NOT NULL,
    SchemaName NVARCHAR(50) NOT NULL DEFAULT 'dbo',
    Description NVARCHAR(500) NULL,

    -- Query Configuration
    PrimaryKeyColumn NVARCHAR(100) NOT NULL,
    MonitorIdColumn NVARCHAR(100) NOT NULL,
    WhereClause NVARCHAR(1000) NULL DEFAULT '1=1',
    OrderByClause NVARCHAR(200) NULL DEFAULT 'CreatedAt ASC',
    BatchSize INT NOT NULL DEFAULT 1000,
    PollingIntervalSeconds INT NOT NULL DEFAULT 5,

    -- MQTT Configuration
    TopicPattern NVARCHAR(500) NOT NULL,
    QosLevel INT NOT NULL DEFAULT 1,
    RetainFlag BIT NOT NULL DEFAULT 0,

    -- Field Mapping (JSON)
    FieldMappingJson NVARCHAR(MAX) NOT NULL,

    -- Metadata
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedAt DATETIME2 NULL,

    CONSTRAINT CHK_QosLevel CHECK (QosLevel IN (0, 1, 2))
);
GO

CREATE INDEX IX_SourceConfig_Enabled ON MQTT.SourceConfig(Enabled) INCLUDE (SourceName, TableName);
GO

PRINT 'Created MQTT.SourceConfig table';
GO

-- ============================================================================
-- Step 3: Create Tracking Table
-- ============================================================================

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SentRecords' AND schema_id = SCHEMA_ID('MQTT'))
    DROP TABLE MQTT.SentRecords;
GO

CREATE TABLE MQTT.SentRecords (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceName NVARCHAR(100) NOT NULL,
    RecordId NVARCHAR(100) NOT NULL,
    SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CorrelationId UNIQUEIDENTIFIER NULL,
    Topic NVARCHAR(500) NULL,

    CONSTRAINT UQ_SentRecords_Source_Record UNIQUE (SourceName, RecordId)
);
GO

CREATE INDEX IX_SentRecords_SentAt ON MQTT.SentRecords(SentAt) INCLUDE (SourceName, RecordId);
CREATE INDEX IX_SentRecords_SourceName ON MQTT.SentRecords(SourceName) INCLUDE (RecordId, SentAt);
GO

PRINT 'Created MQTT.SentRecords tracking table';
GO

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

PRINT 'Created MQTT stored procedures';
GO

-- ============================================================================
-- Step 5: Monitoring Views
-- ============================================================================

CREATE OR ALTER VIEW MQTT.vw_ConfigurationSummary
AS
SELECT
    SourceName,
    Enabled,
    TableName,
    Description,
    TopicPattern,
    BatchSize,
    PollingIntervalSeconds,
    CreatedAt,
    ModifiedAt
FROM MQTT.SourceConfig;
GO

CREATE OR ALTER VIEW MQTT.vw_Metrics
AS
SELECT
    m.SourceName,
    COUNT(*) AS TotalSent,
    MIN(m.SentAt) AS FirstSent,
    MAX(m.SentAt) AS LastSent,
    COUNT(DISTINCT CAST(m.SentAt AS DATE)) AS DaysActive,
    CASE
        WHEN DATEDIFF(SECOND, MIN(m.SentAt), MAX(m.SentAt)) > 0
        THEN COUNT(*) * 1.0 / DATEDIFF(SECOND, MIN(m.SentAt), MAX(m.SentAt))
        ELSE 0
    END AS AvgRecordsPerSecond
FROM MQTT.SentRecords m
GROUP BY m.SourceName;
GO

PRINT 'Created MQTT views';
GO

PRINT '';
PRINT '============================================================================';
PRINT 'MQTT System Setup Complete!';
PRINT '============================================================================';
PRINT 'Schema: MQTT';
PRINT 'Tables: MQTT.SourceConfig, MQTT.SentRecords';
PRINT 'Procedures: MQTT.GetActiveConfigurations, MQTT.GetUnsentRecords, MQTT.MarkRecordsSent';
PRINT '';
PRINT 'Next: Add source configurations using MQTT.AddSourceConfiguration';
PRINT '============================================================================';
GO
