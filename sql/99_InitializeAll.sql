-- =============================================
-- Complete Database Initialization Script
-- =============================================

-- Create Database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MqttBridge')
BEGIN
    CREATE DATABASE MqttBridge
    PRINT 'Database MqttBridge created successfully'
END
ELSE
BEGIN
    PRINT 'Database MqttBridge already exists'
END
GO

USE MqttBridge
GO

-- Drop table if exists (for clean reinstall)
IF OBJECT_ID('dbo.Messages', 'U') IS NOT NULL
    DROP TABLE dbo.Messages
GO

-- Create Messages table
CREATE TABLE dbo.Messages
(
    MessageId BIGINT IDENTITY(1,1) NOT NULL,
    MonitorId NVARCHAR(50) NOT NULL,
    MessageContent NVARCHAR(MAX) NOT NULL,
    Priority INT NOT NULL DEFAULT 0,
    CreatedDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ProcessedDate DATETIME2 NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
    RetryCount INT NOT NULL DEFAULT 0,
    ErrorMessage NVARCHAR(MAX) NULL,
    CorrelationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),

    CONSTRAINT PK_Messages PRIMARY KEY CLUSTERED (MessageId ASC)
)
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_Messages_Status_MonitorId_Priority
ON dbo.Messages (Status, MonitorId, Priority, CreatedDate)
INCLUDE (MessageId, MessageContent, CorrelationId, RetryCount)
GO

CREATE NONCLUSTERED INDEX IX_Messages_MonitorId_CreatedDate
ON dbo.Messages (MonitorId, CreatedDate DESC)
INCLUDE (Status, MessageContent)
GO

CREATE NONCLUSTERED INDEX IX_Messages_Status_CreatedDate
ON dbo.Messages (Status, CreatedDate)
GO

PRINT 'Messages table and indexes created successfully'
GO

-- Drop existing procedures
IF OBJECT_ID('dbo.GetPendingMessages', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetPendingMessages
GO

IF OBJECT_ID('dbo.UpdateMessageStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.UpdateMessageStatus
GO

IF OBJECT_ID('dbo.CleanupExpiredMessages', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CleanupExpiredMessages
GO

IF OBJECT_ID('dbo.GetMessageStats', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetMessageStats
GO

-- Create GetPendingMessages procedure
CREATE PROCEDURE dbo.GetPendingMessages
    @BatchSize INT = 100
AS
BEGIN
    SET NOCOUNT ON

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
    ORDER BY MonitorId, Priority ASC, CreatedDate ASC
END
GO

-- Create UpdateMessageStatus procedure
CREATE PROCEDURE dbo.UpdateMessageStatus
    @MessageId BIGINT,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @IncrementRetryCount BIT = 0
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRY
        UPDATE dbo.Messages
        SET
            Status = @Status,
            ProcessedDate = CASE WHEN @Status = 'Published' THEN SYSUTCDATETIME() ELSE ProcessedDate END,
            ErrorMessage = @ErrorMessage,
            RetryCount = CASE WHEN @IncrementRetryCount = 1 THEN RetryCount + 1 ELSE RetryCount END
        WHERE MessageId = @MessageId

        SELECT @@ROWCOUNT AS RowsAffected
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@ErrorMsg, 16, 1)
    END CATCH
END
GO

-- Create CleanupExpiredMessages procedure
CREATE PROCEDURE dbo.CleanupExpiredMessages
    @RetentionDays INT = 30
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME())
    DECLARE @DeletedCount INT

    BEGIN TRY
        DELETE FROM dbo.Messages
        WHERE CreatedDate < @CutoffDate
        AND Status IN ('Published', 'Failed')

        SET @DeletedCount = @@ROWCOUNT

        SELECT
            @DeletedCount AS DeletedCount,
            @CutoffDate AS CutoffDate,
            @RetentionDays AS RetentionDays
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg2 NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@ErrorMsg2, 16, 1)
    END CATCH
END
GO

-- Create GetMessageStats procedure
CREATE PROCEDURE dbo.GetMessageStats
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        Status,
        COUNT(*) AS MessageCount,
        MIN(CreatedDate) AS OldestMessage,
        MAX(CreatedDate) AS NewestMessage,
        AVG(DATEDIFF(SECOND, CreatedDate, COALESCE(ProcessedDate, SYSUTCDATETIME()))) AS AvgProcessingTimeSeconds
    FROM dbo.Messages
    GROUP BY Status

    SELECT
        MonitorId,
        COUNT(*) AS MessageCount,
        MAX(CreatedDate) AS LastMessageDate
    FROM dbo.Messages
    WHERE Status = 'Pending'
    GROUP BY MonitorId
    ORDER BY MessageCount DESC
END
GO

PRINT 'Stored procedures created successfully'
GO

-- Clear existing data
DELETE FROM dbo.Messages
GO

-- Insert seed data
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('SENSOR_001', '{"temperature": 72.5, "humidity": 45, "timestamp": "2025-10-05T20:00:00Z"}', 0, 'Pending'),
    ('SENSOR_001', '{"temperature": 73.2, "humidity": 46, "timestamp": "2025-10-05T20:05:00Z"}', 0, 'Pending'),
    ('SENSOR_001', '{"temperature": 74.0, "humidity": 47, "timestamp": "2025-10-05T20:10:00Z"}', 0, 'Pending'),
    ('DEVICE_A', '{"status": "online", "battery": 85, "signal_strength": -65}', 0, 'Pending'),
    ('DEVICE_A', '{"status": "online", "battery": 84, "signal_strength": -67}', 0, 'Pending'),
    ('GATEWAY_123', '{"connected_devices": 15, "uptime_seconds": 86400, "errors": 0}', 0, 'Pending'),
    ('GATEWAY_123', '{"connected_devices": 16, "uptime_seconds": 86700, "errors": 0}', 0, 'Pending'),
    ('PUMP_STATION_07', '{"flow_rate": 250.5, "pressure_psi": 45, "motor_temp": 85}', 1, 'Pending'),
    ('PUMP_STATION_07', '{"flow_rate": 248.3, "pressure_psi": 44, "motor_temp": 86}', 0, 'Pending'),
    ('ALARM_PANEL_5', '{"zone": "front_door", "status": "armed", "last_event": "none"}', 0, 'Pending'),
    ('ALARM_PANEL_5', '{"zone": "motion_detector", "status": "triggered", "last_event": "motion_detected"}', 0, 'Pending')
GO

PRINT 'Seed data inserted successfully'
GO

-- Display summary
SELECT
    MonitorId,
    COUNT(*) AS MessageCount
FROM dbo.Messages
GROUP BY MonitorId
ORDER BY MonitorId
GO

PRINT 'Database initialization complete!'
GO
