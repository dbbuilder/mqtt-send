-- =============================================
-- MQTT Bridge Logging Schema
-- Centralized logging for all services
-- =============================================

USE MqttBridge;
GO

-- Create Logging schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Logging')
BEGIN
    EXEC('CREATE SCHEMA Logging');
    PRINT '✓ Created Logging schema';
END
GO

-- =============================================
-- Application Logs Table
-- Stores all application logs from all services
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ApplicationLogs' AND schema_id = SCHEMA_ID('Logging'))
BEGIN
    CREATE TABLE Logging.ApplicationLogs
    (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,

        -- Timestamp
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),

        -- Log Level
        Level NVARCHAR(20) NOT NULL, -- Verbose, Debug, Information, Warning, Error, Fatal

        -- Source Information
        ServiceName NVARCHAR(100) NOT NULL, -- ReceiverService, PublisherService, MonitorDashboard
        MachineName NVARCHAR(100) NULL,

        -- Log Content
        Message NVARCHAR(MAX) NOT NULL,
        MessageTemplate NVARCHAR(MAX) NULL,
        Exception NVARCHAR(MAX) NULL,

        -- Context
        Properties NVARCHAR(MAX) NULL, -- JSON with additional properties

        -- Correlation
        CorrelationId UNIQUEIDENTIFIER NULL,

        -- Indexes for performance
        INDEX IX_ApplicationLogs_Timestamp (Timestamp DESC) INCLUDE (Level, ServiceName),
        INDEX IX_ApplicationLogs_Level (Level) INCLUDE (Timestamp, ServiceName),
        INDEX IX_ApplicationLogs_ServiceName (ServiceName) INCLUDE (Timestamp, Level),
        INDEX IX_ApplicationLogs_CorrelationId (CorrelationId) WHERE CorrelationId IS NOT NULL
    );

    PRINT '✓ Created Logging.ApplicationLogs table';
END
GO

-- =============================================
-- Error Summary View
-- Quick access to errors and warnings
-- =============================================
CREATE OR ALTER VIEW Logging.ErrorSummary
AS
SELECT
    Id,
    Timestamp,
    Level,
    ServiceName,
    Message,
    Exception,
    CorrelationId
FROM Logging.ApplicationLogs
WHERE Level IN ('Error', 'Fatal', 'Warning')
GO

PRINT '✓ Created Logging.ErrorSummary view';
GO

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

PRINT '✓ Created Logging.GetRecentLogs procedure';
GO

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

PRINT '✓ Created Logging.GetErrorStatistics procedure';
GO

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

PRINT '✓ Created Logging.CleanupOldLogs procedure';
GO

-- =============================================
-- Sample: Insert test log entry
-- =============================================
-- Uncomment to test
/*
INSERT INTO Logging.ApplicationLogs (Level, ServiceName, Message, Timestamp)
VALUES ('Information', 'TestService', 'Test log entry', GETUTCDATE());

EXEC Logging.GetRecentLogs @ServiceName = 'TestService', @MaxRows = 10;
*/

PRINT '';
PRINT '========================================';
PRINT ' Logging Schema Created Successfully';
PRINT '========================================';
PRINT '';
PRINT 'Available Objects:';
PRINT '  - Logging.ApplicationLogs (table)';
PRINT '  - Logging.ErrorSummary (view)';
PRINT '  - Logging.GetRecentLogs (procedure)';
PRINT '  - Logging.GetErrorStatistics (procedure)';
PRINT '  - Logging.CleanupOldLogs (procedure)';
PRINT '';
GO
