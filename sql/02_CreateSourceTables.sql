-- Create Sample Source Tables (A, B, C)
-- Demonstrates multi-table MQTT publishing

USE MqttBridge;
GO

-- ============================================================================
-- Table A: Temperature Sensors
-- ============================================================================

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableA')
    DROP TABLE dbo.TableA;
GO

CREATE TABLE dbo.TableA (
    RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonitorId NVARCHAR(50) NOT NULL,
    SensorType NVARCHAR(50) NOT NULL,
    Temperature DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(10) NOT NULL,
    Location NVARCHAR(100) NOT NULL,
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
GO

-- Indexes for fast unsent record queries
CREATE INDEX IX_TableA_CreatedAt ON dbo.TableA(CreatedAt) INCLUDE (RecordId, MonitorId);
CREATE INDEX IX_TableA_MonitorId ON dbo.TableA(MonitorId) INCLUDE (RecordId, CreatedAt);
GO

PRINT 'Created TableA (Temperature Sensors)';
GO

-- ============================================================================
-- Table B: Pressure Sensors
-- ============================================================================

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableB')
    DROP TABLE dbo.TableB;
GO

CREATE TABLE dbo.TableB (
    RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonitorId NVARCHAR(50) NOT NULL,
    SensorType NVARCHAR(50) NOT NULL,
    Pressure DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(10) NOT NULL,
    Location NVARCHAR(100) NOT NULL,
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE INDEX IX_TableB_CreatedAt ON dbo.TableB(CreatedAt) INCLUDE (RecordId, MonitorId);
CREATE INDEX IX_TableB_MonitorId ON dbo.TableB(MonitorId) INCLUDE (RecordId, CreatedAt);
GO

PRINT 'Created TableB (Pressure Sensors)';
GO

-- ============================================================================
-- Table C: Flow Sensors
-- ============================================================================

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableC')
    DROP TABLE dbo.TableC;
GO

CREATE TABLE dbo.TableC (
    RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonitorId NVARCHAR(50) NOT NULL,
    SensorType NVARCHAR(50) NOT NULL,
    FlowRate DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(10) NOT NULL,
    Location NVARCHAR(100) NOT NULL,
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE INDEX IX_TableC_CreatedAt ON dbo.TableC(CreatedAt) INCLUDE (RecordId, MonitorId);
CREATE INDEX IX_TableC_MonitorId ON dbo.TableC(MonitorId) INCLUDE (RecordId, CreatedAt);
GO

PRINT 'Created TableC (Flow Sensors)';
GO

-- ============================================================================
-- Stored Procedures to Get Unsent Records
-- ============================================================================

-- Table A: Get Unsent Records
CREATE OR ALTER PROCEDURE dbo.sp_GetUnsentRecords_TableA
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
    WHERE m.Id IS NULL  -- Not yet sent
    ORDER BY a.CreatedAt ASC;
END
GO

-- Table B: Get Unsent Records
CREATE OR ALTER PROCEDURE dbo.sp_GetUnsentRecords_TableB
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

-- Table C: Get Unsent Records
CREATE OR ALTER PROCEDURE dbo.sp_GetUnsentRecords_TableC
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

PRINT 'Created stored procedures for getting unsent records';
GO

-- ============================================================================
-- Insert Sample Data
-- ============================================================================

-- Table A: Temperature data for Monitors 1-10
DECLARE @i INT = 0;
WHILE @i < 50
BEGIN
    INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'temperature',
        68 + (RAND() * 10),
        'F',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted 50 sample records into TableA';

-- Table B: Pressure data for Monitors 1-10
SET @i = 0;
WHILE @i < 50
BEGIN
    INSERT INTO dbo.TableB (MonitorId, SensorType, Pressure, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'pressure',
        100 + (RAND() * 5),
        'kPa',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted 50 sample records into TableB';

-- Table C: Flow data for Monitors 1-10
SET @i = 0;
WHILE @i < 50
BEGIN
    INSERT INTO dbo.TableC (MonitorId, SensorType, FlowRate, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'flow',
        240 + (RAND() * 20),
        'L/min',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted 50 sample records into TableC';
GO

-- ============================================================================
-- Verification Queries
-- ============================================================================

SELECT 'TableA' AS TableName, COUNT(*) AS RecordCount FROM dbo.TableA
UNION ALL
SELECT 'TableB', COUNT(*) FROM dbo.TableB
UNION ALL
SELECT 'TableC', COUNT(*) FROM dbo.TableC;

-- Show sample data
SELECT TOP 5 'TableA' AS Source, MonitorId, SensorType, Temperature AS Value, Unit, Location FROM dbo.TableA ORDER BY RecordId
UNION ALL
SELECT TOP 5 'TableB', MonitorId, SensorType, Pressure, Unit, Location FROM dbo.TableB ORDER BY RecordId
UNION ALL
SELECT TOP 5 'TableC', MonitorId, SensorType, FlowRate, Unit, Location FROM dbo.TableC ORDER BY RecordId;

PRINT 'Source tables created with sample data!';
GO
