-- Create MQTT Sent Records Tracking Table
-- Run this first before setting up source tables

USE MqttBridge;
GO

-- Drop if exists (for clean testing)
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'MqttSentRecords')
BEGIN
    DROP TABLE dbo.MqttSentRecords;
    PRINT 'Dropped existing MqttSentRecords table';
END
GO

-- Create tracking table
CREATE TABLE dbo.MqttSentRecords (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceTable NVARCHAR(100) NOT NULL,
    RecordId NVARCHAR(100) NOT NULL,
    SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CorrelationId UNIQUEIDENTIFIER NULL,
    Topic NVARCHAR(500) NULL,

    -- Composite unique constraint to prevent duplicates
    CONSTRAINT UQ_MqttSentRecords_Source_Record UNIQUE (SourceTable, RecordId)
);
GO

-- Index for cleanup/archival queries
CREATE INDEX IX_MqttSentRecords_SentAt ON dbo.MqttSentRecords(SentAt)
    INCLUDE (SourceTable, RecordId);
GO

-- Index for fast source table lookups
CREATE INDEX IX_MqttSentRecords_SourceTable ON dbo.MqttSentRecords(SourceTable)
    INCLUDE (RecordId, SentAt);
GO

PRINT 'Created MqttSentRecords tracking table with indexes';
GO

-- Create stored procedure to mark records as sent
CREATE OR ALTER PROCEDURE dbo.sp_MarkRecordsSent
    @SourceTable NVARCHAR(100),
    @RecordIds NVARCHAR(MAX),  -- Comma-separated list
    @CorrelationId UNIQUEIDENTIFIER = NULL,
    @Topic NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Parse comma-separated list into table variable
    DECLARE @RecordIdTable TABLE (RecordId NVARCHAR(100));

    INSERT INTO @RecordIdTable (RecordId)
    SELECT TRIM(value)
    FROM STRING_SPLIT(@RecordIds, ',')
    WHERE TRIM(value) <> '';

    -- Insert tracking records (ignore duplicates via UNIQUE constraint)
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

PRINT 'Created sp_MarkRecordsSent stored procedure';
GO

-- Create cleanup procedure
CREATE OR ALTER PROCEDURE dbo.sp_CleanupMqttTracking
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

        -- Small delay to avoid blocking
        IF @RowsDeleted > 0
            WAITFOR DELAY '00:00:00.100';
    END

    SELECT @TotalDeleted AS TotalRecordsDeleted;
END
GO

PRINT 'Created sp_CleanupMqttTracking stored procedure';
GO

-- Create monitoring view
CREATE OR ALTER VIEW dbo.vw_MqttBridgeMetrics
AS
SELECT
    m.SourceTable,
    COUNT(*) AS TotalSent,
    MIN(m.SentAt) AS FirstSent,
    MAX(m.SentAt) AS LastSent,
    COUNT(DISTINCT CAST(m.SentAt AS DATE)) AS DaysActive,
    CASE
        WHEN DATEDIFF(SECOND, MIN(m.SentAt), MAX(m.SentAt)) > 0
        THEN COUNT(*) * 1.0 / DATEDIFF(SECOND, MIN(m.SentAt), MAX(m.SentAt))
        ELSE 0
    END AS AvgRecordsPerSecond
FROM dbo.MqttSentRecords m
GROUP BY m.SourceTable;
GO

PRINT 'Created vw_MqttBridgeMetrics monitoring view';
GO

-- Verification query
SELECT 'Tracking table created successfully' AS Status;
SELECT * FROM dbo.vw_MqttBridgeMetrics;
GO
