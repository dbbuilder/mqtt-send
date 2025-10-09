-- Create MQTT Configuration Table
-- Stores all source table configurations in the database

USE MqttBridge;
GO

-- Drop if exists
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'MqttSourceConfig')
    DROP TABLE dbo.MqttSourceConfig;
GO

CREATE TABLE dbo.MqttSourceConfig (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    SourceName NVARCHAR(100) NOT NULL UNIQUE,
    Enabled BIT NOT NULL DEFAULT 1,
    TableName NVARCHAR(100) NOT NULL,
    SchemaName NVARCHAR(50) NOT NULL DEFAULT 'dbo',
    Description NVARCHAR(500) NULL,

    -- Query Configuration (JSON)
    PrimaryKey NVARCHAR(100) NOT NULL,
    MonitorIdColumn NVARCHAR(100) NOT NULL,
    WhereClause NVARCHAR(1000) NULL DEFAULT '1=1',
    OrderBy NVARCHAR(200) NULL DEFAULT 'CreatedAt ASC',
    BatchSize INT NOT NULL DEFAULT 1000,
    PollingIntervalSeconds INT NOT NULL DEFAULT 5,

    -- MQTT Configuration
    TopicPattern NVARCHAR(500) NOT NULL,
    QosLevel INT NOT NULL DEFAULT 1,
    RetainFlag BIT NOT NULL DEFAULT 0,

    -- Field Mapping (JSON)
    FieldMappingJson NVARCHAR(MAX) NOT NULL,  -- {"TableColumn": "MqttField", ...}

    -- Metadata
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedAt DATETIME2 NULL,

    CONSTRAINT CHK_QosLevel CHECK (QosLevel IN (0, 1, 2))
);
GO

CREATE INDEX IX_MqttSourceConfig_Enabled ON dbo.MqttSourceConfig(Enabled)
    INCLUDE (SourceName, TableName);
GO

PRINT 'Created MqttSourceConfig table';
GO

-- Insert sample configurations for TableA, TableB, TableC
INSERT INTO dbo.MqttSourceConfig (
    SourceName, Enabled, TableName, SchemaName, Description,
    PrimaryKey, MonitorIdColumn, WhereClause, OrderBy, BatchSize, PollingIntervalSeconds,
    TopicPattern, QosLevel, RetainFlag,
    FieldMappingJson
)
VALUES
(
    'TableA',
    1,
    'TableA',
    'dbo',
    'Temperature sensor data',
    'RecordId',
    'MonitorId',
    '1=1',
    'CreatedAt ASC',
    100,
    2,
    'data/tableA/{MonitorId}',
    1,
    0,
    '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "Temperature": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }'
),
(
    'TableB',
    1,
    'TableB',
    'dbo',
    'Pressure sensor data',
    'RecordId',
    'MonitorId',
    '1=1',
    'CreatedAt ASC',
    100,
    2,
    'data/tableB/{MonitorId}',
    1,
    0,
    '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "Pressure": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }'
),
(
    'TableC',
    1,
    'TableC',
    'dbo',
    'Flow sensor data',
    'RecordId',
    'MonitorId',
    '1=1',
    'CreatedAt ASC',
    100,
    2,
    'data/tableC/{MonitorId}',
    1,
    0,
    '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "FlowRate": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }'
);
GO

PRINT 'Inserted sample configurations for TableA, TableB, TableC';
GO

-- View to see configurations
CREATE OR ALTER VIEW dbo.vw_MqttSourceConfigSummary
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
FROM dbo.MqttSourceConfig;
GO

-- Stored procedure to get active configurations
CREATE OR ALTER PROCEDURE dbo.sp_GetActiveMqttConfigs
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
        PrimaryKey,
        MonitorIdColumn,
        WhereClause,
        OrderBy,
        BatchSize,
        PollingIntervalSeconds,
        TopicPattern,
        QosLevel,
        RetainFlag,
        FieldMappingJson
    FROM dbo.MqttSourceConfig
    WHERE Enabled = 1
    ORDER BY SourceName;
END
GO

PRINT 'Created views and stored procedures';
GO

-- Verification
SELECT * FROM dbo.vw_MqttSourceConfigSummary;
GO

PRINT 'Configuration table setup complete!';
PRINT 'To add new tables, INSERT into dbo.MqttSourceConfig';
GO
