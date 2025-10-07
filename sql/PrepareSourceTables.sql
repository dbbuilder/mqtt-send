-- Prepare Source Tables for High-Scale MQTT Bridge
-- Run this script on each source table you want to publish to MQTT

USE MqttBridge;
GO

-- ============================================================================
-- STEP 1: Create Tracking Table (Run Once)
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MqttSentRecords')
BEGIN
    CREATE TABLE dbo.MqttSentRecords (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        SourceTable NVARCHAR(100) NOT NULL,
        RecordId NVARCHAR(100) NOT NULL,
        SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CorrelationId UNIQUEIDENTIFIER NULL,
        Topic NVARCHAR(500) NULL,

        -- Composite unique index for fast lookups
        CONSTRAINT UQ_Source_Record UNIQUE (SourceTable, RecordId)
    );

    -- Index for cleanup queries
    CREATE INDEX IX_MqttSentRecords_SentAt ON dbo.MqttSentRecords(SentAt)
        INCLUDE (SourceTable);

    PRINT 'Created MqttSentRecords tracking table';
END
ELSE
BEGIN
    PRINT 'MqttSentRecords already exists';
END
GO

-- ============================================================================
-- STEP 2: Example - Prepare TableA
-- ============================================================================
-- Copy this pattern for each source table (A, B, C, D, E, F, G...)

-- Add helpful columns if they don't exist
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TableA') AND name = 'CreatedAt')
BEGIN
    ALTER TABLE dbo.TableA ADD CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE();
    PRINT 'Added CreatedAt column to TableA';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TableA') AND name = 'ModifiedAt')
BEGIN
    ALTER TABLE dbo.TableA ADD ModifiedAt DATETIME2 NULL;
    PRINT 'Added ModifiedAt column to TableA';
END

-- Create optimized indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableA') AND name = 'IX_TableA_CreatedAt')
BEGIN
    CREATE INDEX IX_TableA_CreatedAt ON dbo.TableA(CreatedAt)
        INCLUDE (RecordId, MonitorId);
    PRINT 'Created index IX_TableA_CreatedAt on TableA';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableA') AND name = 'IX_TableA_MonitorId')
BEGIN
    CREATE INDEX IX_TableA_MonitorId ON dbo.TableA(MonitorId)
        INCLUDE (RecordId, CreatedAt);
    PRINT 'Created index IX_TableA_MonitorId on TableA';
END

GO

-- ============================================================================
-- STEP 3: Query to Find Unsent Records (Example for TableA)
-- ============================================================================
-- This is the query pattern the Publisher will use

CREATE OR ALTER PROCEDURE dbo.GetUnsentRecords_TableA
    @BatchSize INT = 5000
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@BatchSize)
        a.RecordId,
        a.MonitorId,
        a.Value,
        a.Timestamp,
        a.CreatedAt,
        DATEDIFF(MILLISECOND, a.CreatedAt, GETUTCDATE()) AS LagMs
    FROM dbo.TableA a
    LEFT JOIN dbo.MqttSentRecords m
        ON m.SourceTable = 'TableA'
        AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
    WHERE m.Id IS NULL  -- Not yet sent
    ORDER BY a.CreatedAt ASC;
END
GO

-- ============================================================================
-- STEP 4: Mark Records as Sent
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.MarkRecordsSent
    @SourceTable NVARCHAR(100),
    @RecordIds NVARCHAR(MAX),  -- Comma-separated list
    @CorrelationId UNIQUEIDENTIFIER = NULL,
    @Topic NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Parse comma-separated list into table
    DECLARE @RecordIdTable TABLE (RecordId NVARCHAR(100));

    INSERT INTO @RecordIdTable (RecordId)
    SELECT value
    FROM STRING_SPLIT(@RecordIds, ',');

    -- Insert tracking records (ignore duplicates)
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

-- ============================================================================
-- STEP 5: Cleanup/Archival Job
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.CleanupMqttTracking
    @RetentionDays INT = 7,
    @BatchSize INT = 10000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowsDeleted INT = 1;
    DECLARE @TotalDeleted INT = 0;

    WHILE @RowsDeleted > 0
    BEGIN
        DELETE TOP (@BatchSize)
        FROM dbo.MqttSentRecords
        WHERE SentAt < DATEADD(DAY, -@RetentionDays, GETUTCDATE());

        SET @RowsDeleted = @@ROWCOUNT;
        SET @TotalDeleted = @TotalDeleted + @RowsDeleted;

        -- Small delay to avoid blocking
        IF @RowsDeleted > 0
            WAITFOR DELAY '00:00:00.100';
    END

    SELECT @TotalDeleted AS TotalRecordsDeleted;
END
GO

-- ============================================================================
-- STEP 6: Enable Database Optimizations
-- ============================================================================

-- Enable Read Committed Snapshot Isolation (reduces locking)
IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = 'MqttBridge') = 0
BEGIN
    ALTER DATABASE MqttBridge SET READ_COMMITTED_SNAPSHOT ON;
    PRINT 'Enabled Read Committed Snapshot Isolation';
END

-- Enable Auto Update Statistics Asynchronously
IF (SELECT is_auto_update_stats_async_on FROM sys.databases WHERE name = 'MqttBridge') = 0
BEGIN
    ALTER DATABASE MqttBridge SET AUTO_UPDATE_STATISTICS_ASYNC ON;
    PRINT 'Enabled Auto Update Statistics Asynchronously';
END

GO

-- ============================================================================
-- STEP 7: Monitor Performance
-- ============================================================================

CREATE OR ALTER VIEW dbo.vw_MqttBridgeMetrics
AS
SELECT
    m.SourceTable,
    COUNT(*) AS SentRecords,
    MIN(m.SentAt) AS FirstSent,
    MAX(m.SentAt) AS LastSent,
    DATEDIFF(MINUTE, MIN(m.SentAt), MAX(m.SentAt)) AS DurationMinutes,
    COUNT(*) * 1.0 / NULLIF(DATEDIFF(SECOND, MIN(m.SentAt), MAX(m.SentAt)), 0) AS AvgRecordsPerSecond
FROM dbo.MqttSentRecords m
WHERE m.SentAt >= DATEADD(HOUR, -1, GETUTCDATE())
GROUP BY m.SourceTable;
GO

-- ============================================================================
-- STEP 8: Sample Data for Testing
-- ============================================================================

-- Create test table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TableA')
BEGIN
    CREATE TABLE dbo.TableA (
        RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
        MonitorId NVARCHAR(50) NOT NULL,
        Value DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NOT NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        ModifiedAt DATETIME2 NULL
    );

    -- Insert sample data
    DECLARE @i INT = 0;
    WHILE @i < 1000
    BEGIN
        INSERT INTO dbo.TableA (MonitorId, Value, Unit)
        VALUES (
            'Monitor-' + CAST((@i % 100) AS NVARCHAR),
            RAND() * 100,
            CASE (@i % 3) WHEN 0 THEN 'F' WHEN 1 THEN '%' ELSE 'kPa' END
        );
        SET @i = @i + 1;
    END

    PRINT 'Created and populated TableA with sample data';
END
GO

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check tracking table
SELECT COUNT(*) AS TotalSentRecords FROM dbo.MqttSentRecords;

-- Check unsent records in TableA
SELECT COUNT(*) AS UnsentRecords
FROM dbo.TableA a
LEFT JOIN dbo.MqttSentRecords m
    ON m.SourceTable = 'TableA'
    AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

-- View metrics
SELECT * FROM dbo.vw_MqttBridgeMetrics;

PRINT 'Setup complete! Ready for high-scale MQTT publishing.';
GO
