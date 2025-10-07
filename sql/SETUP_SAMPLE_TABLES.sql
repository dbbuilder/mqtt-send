-- Setup Sample Source Tables and Configurations
-- Creates TableA, TableB, TableC with sample data and MQTT configurations

USE MqttBridge;
GO

-- ============================================================================
-- Create Source Tables
-- ============================================================================

-- TableA: Temperature Sensors
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableA' AND schema_id = SCHEMA_ID('dbo'))
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

CREATE INDEX IX_TableA_CreatedAt ON dbo.TableA(CreatedAt) INCLUDE (RecordId, MonitorId);
CREATE INDEX IX_TableA_MonitorId ON dbo.TableA(MonitorId) INCLUDE (RecordId, CreatedAt);
GO

-- TableB: Pressure Sensors
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableB' AND schema_id = SCHEMA_ID('dbo'))
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

-- TableC: Flow Sensors
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableC' AND schema_id = SCHEMA_ID('dbo'))
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

PRINT 'Created source tables: TableA, TableB, TableC';
GO

-- ============================================================================
-- Add Sample Data
-- ============================================================================

-- TableA: Temperature data
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
PRINT 'Inserted 50 records into TableA';

-- TableB: Pressure data
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
PRINT 'Inserted 50 records into TableB';

-- TableC: Flow data
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
PRINT 'Inserted 50 records into TableC';
GO

-- ============================================================================
-- Add MQTT Configurations
-- ============================================================================

-- TableA Configuration
EXEC MQTT.AddSourceConfiguration
    @SourceName = 'TableA',
    @TableName = 'TableA',
    @SchemaName = 'dbo',
    @Description = 'Temperature sensor data',
    @PrimaryKeyColumn = 'RecordId',
    @MonitorIdColumn = 'MonitorId',
    @TopicPattern = 'data/tableA/{MonitorId}',
    @FieldMappingJson = '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "Temperature": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }',
    @WhereClause = '1=1',
    @OrderByClause = 'CreatedAt ASC',
    @BatchSize = 100,
    @PollingIntervalSeconds = 2,
    @QosLevel = 1,
    @RetainFlag = 0,
    @Enabled = 1;

PRINT 'Added MQTT configuration for TableA';
GO

-- TableB Configuration
EXEC MQTT.AddSourceConfiguration
    @SourceName = 'TableB',
    @TableName = 'TableB',
    @SchemaName = 'dbo',
    @Description = 'Pressure sensor data',
    @PrimaryKeyColumn = 'RecordId',
    @MonitorIdColumn = 'MonitorId',
    @TopicPattern = 'data/tableB/{MonitorId}',
    @FieldMappingJson = '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "Pressure": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }',
    @WhereClause = '1=1',
    @OrderByClause = 'CreatedAt ASC',
    @BatchSize = 100,
    @PollingIntervalSeconds = 2,
    @QosLevel = 1,
    @RetainFlag = 0,
    @Enabled = 1;

PRINT 'Added MQTT configuration for TableB';
GO

-- TableC Configuration
EXEC MQTT.AddSourceConfiguration
    @SourceName = 'TableC',
    @TableName = 'TableC',
    @SchemaName = 'dbo',
    @Description = 'Flow sensor data',
    @PrimaryKeyColumn = 'RecordId',
    @MonitorIdColumn = 'MonitorId',
    @TopicPattern = 'data/tableC/{MonitorId}',
    @FieldMappingJson = '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "FlowRate": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }',
    @WhereClause = '1=1',
    @OrderByClause = 'CreatedAt ASC',
    @BatchSize = 100,
    @PollingIntervalSeconds = 2,
    @QosLevel = 1,
    @RetainFlag = 0,
    @Enabled = 1;

PRINT 'Added MQTT configuration for TableC';
GO

-- ============================================================================
-- Verification
-- ============================================================================

PRINT '';
PRINT 'Source Tables:';
SELECT 'TableA' AS TableName, COUNT(*) AS RecordCount FROM dbo.TableA
UNION ALL
SELECT 'TableB', COUNT(*) FROM dbo.TableB
UNION ALL
SELECT 'TableC', COUNT(*) FROM dbo.TableC;

PRINT '';
PRINT 'MQTT Configurations:';
SELECT * FROM MQTT.vw_ConfigurationSummary;

PRINT '';
PRINT 'Setup Complete! Ready to publish to MQTT.';
GO
