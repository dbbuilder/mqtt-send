-- ============================================
-- AZURE SQL MIGRATION SCRIPT
-- ============================================
-- Migrates MqttBridge database to Azure SQL
-- Server: mbox-eastasia.database.windows.net
-- Database: MqttBridge
-- ============================================

USE MqttBridge;
GO

PRINT '========================================';
PRINT 'MQTT Bridge - Azure SQL Migration';
PRINT '========================================';
PRINT '';

-- ============================================
-- 1. CREATE SCHEMAS
-- ============================================
PRINT 'Step 1: Creating schemas...';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'MQTT')
BEGIN
    EXEC('CREATE SCHEMA MQTT');
    PRINT '  Created schema: MQTT';
END
ELSE
    PRINT '  Schema MQTT already exists';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Logging')
BEGIN
    EXEC('CREATE SCHEMA Logging');
    PRINT '  Created schema: Logging';
END
ELSE
    PRINT '  Schema Logging already exists';
GO

-- ============================================
-- 2. CREATE LOGGING TABLES
-- ============================================
PRINT '';
PRINT 'Step 2: Creating logging tables...';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ApplicationLogs' AND schema_id = SCHEMA_ID('Logging'))
BEGIN
    CREATE TABLE Logging.ApplicationLogs (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        Level NVARCHAR(50),
        Message NVARCHAR(MAX),
        Exception NVARCHAR(MAX),
        ServiceName NVARCHAR(100) NOT NULL,
        LogEvent NVARCHAR(MAX)
    );
    PRINT '  Created table: Logging.ApplicationLogs';
END
ELSE
    PRINT '  Table Logging.ApplicationLogs already exists';

IF NOT EXISTS (SELECT 1 FROM sys.views WHERE name = 'ErrorSummary' AND schema_id = SCHEMA_ID('Logging'))
BEGIN
    EXEC('CREATE VIEW Logging.ErrorSummary AS
    SELECT TOP 100
        Timestamp,
        ServiceName,
        Message,
        Exception
    FROM Logging.ApplicationLogs
    WHERE Level = ''Error''
    ORDER BY Timestamp DESC');
    PRINT '  Created view: Logging.ErrorSummary';
END
ELSE
    PRINT '  View Logging.ErrorSummary already exists';
GO

-- ============================================
-- 3. CREATE RECEIVER TABLES
-- ============================================
PRINT '';
PRINT 'Step 3: Creating receiver tables...';

-- ReceiverConfig table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ReceiverConfig' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.ReceiverConfig (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        ConfigName NVARCHAR(200) NOT NULL UNIQUE,
        TopicPattern NVARCHAR(500) NOT NULL,
        Description NVARCHAR(1000) NULL,
        MessageFormat NVARCHAR(50) NOT NULL DEFAULT 'JSON',
        FieldMappingJson NVARCHAR(MAX) NULL,
        Enabled BIT NOT NULL DEFAULT 1,
        QoS INT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '  Created table: MQTT.ReceiverConfig';
END
ELSE
    PRINT '  Table MQTT.ReceiverConfig already exists';

-- TopicTableMapping table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'TopicTableMapping' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.TopicTableMapping (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        ReceiverConfigId BIGINT NOT NULL,
        TargetTable NVARCHAR(200) NOT NULL,
        TargetSchema NVARCHAR(100) NOT NULL DEFAULT 'dbo',
        ColumnMappingJson NVARCHAR(MAX) NULL,
        FilterCondition NVARCHAR(500) NULL,
        Enabled BIT NOT NULL DEFAULT 1,
        InsertMode NVARCHAR(50) NOT NULL DEFAULT 'Direct',
        Priority INT NOT NULL DEFAULT 100,
        ContinueOnError BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT FK_TopicTableMapping_ReceiverConfig FOREIGN KEY (ReceiverConfigId)
            REFERENCES MQTT.ReceiverConfig(Id) ON DELETE CASCADE
    );
    PRINT '  Created table: MQTT.TopicTableMapping';
END
ELSE
    PRINT '  Table MQTT.TopicTableMapping already exists';

-- ReceivedMessages table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ReceivedMessages' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.ReceivedMessages (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        ReceiverConfigId BIGINT NOT NULL,
        Topic NVARCHAR(500) NOT NULL,
        Payload NVARCHAR(MAX) NOT NULL,
        QoS INT NOT NULL,
        ReceivedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        ProcessedAt DATETIME2 NULL,
        Status NVARCHAR(50) NOT NULL DEFAULT 'Pending',
        ErrorMessage NVARCHAR(MAX) NULL,
        TargetTablesProcessed INT NULL,
        CorrelationId UNIQUEIDENTIFIER NULL,
        CONSTRAINT FK_ReceivedMessages_ReceiverConfig FOREIGN KEY (ReceiverConfigId)
            REFERENCES MQTT.ReceiverConfig(Id)
    );

    CREATE INDEX IX_ReceivedMessages_ReceivedAt ON MQTT.ReceivedMessages(ReceivedAt DESC);
    CREATE INDEX IX_ReceivedMessages_Topic ON MQTT.ReceivedMessages(Topic);
    CREATE INDEX IX_ReceivedMessages_Status ON MQTT.ReceivedMessages(Status);

    PRINT '  Created table: MQTT.ReceivedMessages';
END
ELSE
    PRINT '  Table MQTT.ReceivedMessages already exists';
GO

-- ============================================
-- 4. CREATE PUBLISHER TABLES
-- ============================================
PRINT '';
PRINT 'Step 4: Creating publisher tables...';

-- SourceConfig table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SourceConfig' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.SourceConfig (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        SourceName NVARCHAR(200) NOT NULL UNIQUE,
        TableName NVARCHAR(200) NOT NULL,
        SchemaName NVARCHAR(100) NOT NULL DEFAULT 'dbo',
        TopicPattern NVARCHAR(500) NOT NULL,
        MessageTemplate NVARCHAR(MAX) NULL,
        WhereClause NVARCHAR(1000) NULL,
        PollingIntervalSeconds INT NOT NULL DEFAULT 2,
        Enabled BIT NOT NULL DEFAULT 1,
        QoS INT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '  Created table: MQTT.SourceConfig';
END
ELSE
    PRINT '  Table MQTT.SourceConfig already exists';

-- SentRecords table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SentRecords' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.SentRecords (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        SourceConfigId BIGINT NULL,
        SourceName NVARCHAR(200) NOT NULL,
        RecordId BIGINT NOT NULL,
        Topic NVARCHAR(500) NOT NULL,
        Payload NVARCHAR(MAX) NOT NULL,
        QoS INT NOT NULL,
        SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        Status NVARCHAR(50) NOT NULL DEFAULT 'Sent',
        ErrorMessage NVARCHAR(MAX) NULL,
        CONSTRAINT FK_SentRecords_SourceConfig FOREIGN KEY (SourceConfigId)
            REFERENCES MQTT.SourceConfig(Id)
    );

    CREATE INDEX IX_SentRecords_SentAt ON MQTT.SentRecords(SentAt DESC);
    CREATE INDEX IX_SentRecords_SourceName ON MQTT.SentRecords(SourceName);

    PRINT '  Created table: MQTT.SentRecords';
END
ELSE
    PRINT '  Table MQTT.SentRecords already exists';
GO

-- ============================================
-- 5. CREATE DEMO DATA TABLES
-- ============================================
PRINT '';
PRINT 'Step 5: Creating demo data tables...';

-- RawSensorData table (destination for received messages)
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'RawSensorData' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.RawSensorData (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        DeviceId NVARCHAR(100) NOT NULL,
        SensorType NVARCHAR(100) NOT NULL,
        Value DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(50) NULL,
        Timestamp DATETIME2 NULL,
        ReceivedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_RawSensorData_ReceivedAt ON dbo.RawSensorData(ReceivedAt DESC);
    CREATE INDEX IX_RawSensorData_DeviceId ON dbo.RawSensorData(DeviceId);

    PRINT '  Created table: dbo.RawSensorData';
END
ELSE
    PRINT '  Table dbo.RawSensorData already exists';

-- TableA (source for publishing)
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'TableA' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.TableA (
        RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
        MonitorId INT NOT NULL,
        SensorType NVARCHAR(100) NOT NULL DEFAULT 'temperature',
        Temperature DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(50) NOT NULL DEFAULT 'F',
        Location NVARCHAR(200) NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        Published BIT NOT NULL DEFAULT 0
    );
    PRINT '  Created table: dbo.TableA';
END
ELSE
    PRINT '  Table dbo.TableA already exists';

-- TableB (source for publishing)
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'TableB' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.TableB (
        RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
        MonitorId INT NOT NULL,
        SensorType NVARCHAR(100) NOT NULL DEFAULT 'pressure',
        Pressure DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(50) NOT NULL DEFAULT 'PSI',
        Location NVARCHAR(200) NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        Published BIT NOT NULL DEFAULT 0
    );
    PRINT '  Created table: dbo.TableB';
END
ELSE
    PRINT '  Table dbo.TableB already exists';

-- TableC (source for publishing)
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'TableC' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.TableC (
        RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
        MonitorId INT NOT NULL,
        SensorType NVARCHAR(100) NOT NULL DEFAULT 'flow',
        FlowRate DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(50) NOT NULL DEFAULT 'GPM',
        Location NVARCHAR(200) NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        Published BIT NOT NULL DEFAULT 0
    );
    PRINT '  Created table: dbo.TableC';
END
ELSE
    PRINT '  Table dbo.TableC already exists';
GO

-- ============================================
-- 6. CONFIGURE PUBLISHER SOURCES
-- ============================================
PRINT '';
PRINT 'Step 6: Configuring publisher sources...';

IF NOT EXISTS (SELECT 1 FROM MQTT.SourceConfig WHERE SourceName = 'TableA')
BEGIN
    INSERT INTO MQTT.SourceConfig (SourceName, TableName, SchemaName, TopicPattern, PollingIntervalSeconds, WhereClause, Enabled, QoS)
    VALUES ('TableA', 'TableA', 'dbo', 'data/tableA/{MonitorId}', 2, 'Published = 0', 1, 1);
    PRINT '  Added source config: TableA';
END

IF NOT EXISTS (SELECT 1 FROM MQTT.SourceConfig WHERE SourceName = 'TableB')
BEGIN
    INSERT INTO MQTT.SourceConfig (SourceName, TableName, SchemaName, TopicPattern, PollingIntervalSeconds, WhereClause, Enabled, QoS)
    VALUES ('TableB', 'TableB', 'dbo', 'data/tableB/{MonitorId}', 2, 'Published = 0', 1, 1);
    PRINT '  Added source config: TableB';
END

IF NOT EXISTS (SELECT 1 FROM MQTT.SourceConfig WHERE SourceName = 'TableC')
BEGIN
    INSERT INTO MQTT.SourceConfig (SourceName, TableName, SchemaName, TopicPattern, PollingIntervalSeconds, WhereClause, Enabled, QoS)
    VALUES ('TableC', 'TableC', 'dbo', 'data/tableC/{MonitorId}', 2, 'Published = 0', 1, 1);
    PRINT '  Added source config: TableC';
END
GO

-- ============================================
-- 7. CONFIGURE RECEIVER SUBSCRIPTIONS
-- ============================================
PRINT '';
PRINT 'Step 7: Configuring receiver subscriptions...';

-- Dashboard test topics
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'DashboardTests')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
    VALUES (
        'DashboardTests',
        'test/#',
        'Dashboard test button messages',
        'JSON',
        '{
            "DeviceId": "$.MonitorId",
            "SensorType": "$.SensorType",
            "Value": "$.Value",
            "Unit": "$.Unit",
            "Timestamp": "$.Timestamp"
        }',
        1,
        1
    );

    -- Add table mapping
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority)
    SELECT
        Id,
        'RawSensorData',
        'dbo',
        '{
            "DeviceId": "DeviceId",
            "SensorType": "SensorType",
            "Value": "Value",
            "Unit": "Unit",
            "Timestamp": "Timestamp"
        }',
        1,
        'Direct',
        100
    FROM MQTT.ReceiverConfig
    WHERE ConfigName = 'DashboardTests';

    PRINT '  Added receiver config: DashboardTests';
END

-- Published data topics (for bidirectional flow)
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'PublishedData_TableA')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
    VALUES (
        'PublishedData_TableA',
        'data/tableA/+',
        'Receive published TableA data',
        'JSON',
        '{
            "DeviceId": "$.MonitorId",
            "SensorType": "$.SensorType",
            "Value": "$.Temperature",
            "Unit": "$.Unit",
            "Timestamp": "$.Timestamp"
        }',
        1,
        1
    );

    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority)
    SELECT
        Id,
        'RawSensorData',
        'dbo',
        '{
            "DeviceId": "DeviceId",
            "SensorType": "SensorType",
            "Value": "Value",
            "Unit": "Unit",
            "Timestamp": "Timestamp"
        }',
        1,
        'Direct',
        100
    FROM MQTT.ReceiverConfig
    WHERE ConfigName = 'PublishedData_TableA';

    PRINT '  Added receiver config: PublishedData_TableA';
END

IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'PublishedData_TableB')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
    VALUES (
        'PublishedData_TableB',
        'data/tableB/+',
        'Receive published TableB data',
        'JSON',
        '{
            "DeviceId": "$.MonitorId",
            "SensorType": "$.SensorType",
            "Value": "$.Pressure",
            "Unit": "$.Unit",
            "Timestamp": "$.Timestamp"
        }',
        1,
        1
    );

    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority)
    SELECT
        Id,
        'RawSensorData',
        'dbo',
        '{
            "DeviceId": "DeviceId",
            "SensorType": "SensorType",
            "Value": "Value",
            "Unit": "Unit",
            "Timestamp": "Timestamp"
        }',
        1,
        'Direct',
        100
    FROM MQTT.ReceiverConfig
    WHERE ConfigName = 'PublishedData_TableB';

    PRINT '  Added receiver config: PublishedData_TableB';
END

IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'PublishedData_TableC')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
    VALUES (
        'PublishedData_TableC',
        'data/tableC/+',
        'Receive published TableC data',
        'JSON',
        '{
            "DeviceId": "$.MonitorId",
            "SensorType": "$.SensorType",
            "Value": "$.FlowRate",
            "Unit": "$.Unit",
            "Timestamp": "$.Timestamp"
        }',
        1,
        1
    );

    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority)
    SELECT
        Id,
        'RawSensorData',
        'dbo',
        '{
            "DeviceId": "DeviceId",
            "SensorType": "SensorType",
            "Value": "Value",
            "Unit": "Unit",
            "Timestamp": "Timestamp"
        }',
        1,
        'Direct',
        100
    FROM MQTT.ReceiverConfig
    WHERE ConfigName = 'PublishedData_TableC';

    PRINT '  Added receiver config: PublishedData_TableC';
END
GO

-- ============================================
-- 8. VERIFICATION
-- ============================================
PRINT '';
PRINT '========================================';
PRINT 'Migration Complete - Verification:';
PRINT '========================================';

PRINT '';
PRINT 'Schemas:';
SELECT name FROM sys.schemas WHERE name IN ('MQTT', 'Logging');

PRINT '';
PRINT 'MQTT Tables:';
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MQTT'
ORDER BY TABLE_NAME;

PRINT '';
PRINT 'Publisher Sources:';
SELECT SourceName, TableName, TopicPattern, Enabled
FROM MQTT.SourceConfig;

PRINT '';
PRINT 'Receiver Configurations:';
SELECT ConfigName, TopicPattern, Enabled
FROM MQTT.ReceiverConfig;

PRINT '';
PRINT 'Demo Tables:';
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
AND TABLE_NAME IN ('RawSensorData', 'TableA', 'TableB', 'TableC')
ORDER BY TABLE_NAME;

PRINT '';
PRINT '========================================';
PRINT 'Azure SQL Migration Complete!';
PRINT '========================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Update appsettings.json with Azure connection string';
PRINT '2. Restart services to connect to Azure SQL';
PRINT '3. Test dashboard buttons to verify connectivity';
PRINT '';
GO
