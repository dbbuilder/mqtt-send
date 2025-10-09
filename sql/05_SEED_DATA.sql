-- =============================================
-- Script: 05_SEED_DATA.sql
-- Description: Seeds initial configuration data
-- Database: MqttBridge
-- =============================================

USE MqttBridge;
GO

PRINT 'Seeding configuration data...';
GO

-- =============================================
-- Seed MQTT.ReceiverConfig
-- =============================================

-- Clear existing data (optional - comment out if you want to preserve existing data)
-- DELETE FROM MQTT.TopicTableMapping;
-- DELETE FROM MQTT.ReceiverConfig;
-- GO

-- Config 1: TableA_Data
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'TableA_Data')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
    VALUES (
        'TableA_Data',
        'data/tableA/+',
        'Receives TableA data from publisher',
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
    PRINT 'Inserted ReceiverConfig: TableA_Data';
END
GO

-- Config 2: TableB_Data
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'TableB_Data')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
    VALUES (
        'TableB_Data',
        'data/tableB/+',
        'Receives TableB data from publisher',
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
    PRINT 'Inserted ReceiverConfig: TableB_Data';
END
GO

-- Config 3: TableC_Data
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'TableC_Data')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
    VALUES (
        'TableC_Data',
        'data/tableC/+',
        'Receives TableC data from publisher',
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
    PRINT 'Inserted ReceiverConfig: TableC_Data';
END
GO

-- Config 4: TemperatureSensors
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'TemperatureSensors')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
    VALUES (
        'TemperatureSensors',
        'sensor/+/temperature',
        'Temperature sensor readings from all devices',
        'JSON',
        '{"DeviceId": "$.device_id", "SensorType": "$.sensor_type", "Value": "$.value", "Unit": "$.unit", "Timestamp": "$.timestamp"}',
        1,
        1
    );
    PRINT 'Inserted ReceiverConfig: TemperatureSensors';
END
GO

-- Config 5: PressureSensors
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'PressureSensors')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
    VALUES (
        'PressureSensors',
        'sensor/+/pressure',
        'Pressure sensor readings',
        'JSON',
        '{"DeviceId": "$.device_id", "SensorType": "$.sensor_type", "Value": "$.value", "Unit": "$.unit", "Timestamp": "$.timestamp"}',
        1,
        1
    );
    PRINT 'Inserted ReceiverConfig: PressureSensors';
END
GO

-- Config 6: HumiditySensors
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'HumiditySensors')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
    VALUES (
        'HumiditySensors',
        'sensor/+/humidity',
        'Humidity sensor readings',
        'JSON',
        '{"DeviceId": "$.device_id", "SensorType": "$.sensor_type", "Value": "$.value", "Unit": "$.unit", "Timestamp": "$.timestamp"}',
        1,
        1
    );
    PRINT 'Inserted ReceiverConfig: HumiditySensors';
END
GO

-- Config 7: DashboardTests
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'DashboardTests')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled)
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
    PRINT 'Inserted ReceiverConfig: DashboardTests';
END
GO

-- =============================================
-- Seed MQTT.TopicTableMapping
-- =============================================

-- Mappings for TableA_Data
DECLARE @TableAConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'TableA_Data');
IF @TableAConfigId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @TableAConfigId)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, ColumnMappingJson, Priority, ContinueOnError, Enabled)
    VALUES (
        @TableAConfigId,
        'dbo',
        'RawSensorData',
        'INSERT',
        '{
        "DeviceId": "DeviceId",
        "SensorType": "SensorType",
        "Value": "Value",
        "Unit": "Unit",
        "Timestamp": "Timestamp"
    }',
        1,
        0,
        1
    );
    PRINT 'Inserted TopicTableMapping for TableA_Data';
END
GO

-- Mappings for TableB_Data
DECLARE @TableBConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'TableB_Data');
IF @TableBConfigId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @TableBConfigId)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, ColumnMappingJson, Priority, ContinueOnError, Enabled)
    VALUES (
        @TableBConfigId,
        'dbo',
        'RawSensorData',
        'INSERT',
        '{
        "DeviceId": "DeviceId",
        "SensorType": "SensorType",
        "Value": "Value",
        "Unit": "Unit",
        "Timestamp": "Timestamp"
    }',
        1,
        0,
        1
    );
    PRINT 'Inserted TopicTableMapping for TableB_Data';
END
GO

-- Mappings for TableC_Data
DECLARE @TableCConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'TableC_Data');
IF @TableCConfigId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @TableCConfigId)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, ColumnMappingJson, Priority, ContinueOnError, Enabled)
    VALUES (
        @TableCConfigId,
        'dbo',
        'RawSensorData',
        'INSERT',
        '{
        "DeviceId": "DeviceId",
        "SensorType": "SensorType",
        "Value": "Value",
        "Unit": "Unit",
        "Timestamp": "Timestamp"
    }',
        1,
        0,
        1
    );
    PRINT 'Inserted TopicTableMapping for TableC_Data';
END
GO

-- Mappings for TemperatureSensors (3 mappings: RawSensorData, SensorAlerts, SensorAggregates)
DECLARE @TempConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'TemperatureSensors');
IF @TempConfigId IS NOT NULL
BEGIN
    -- Mapping 1: All readings to RawSensorData
    IF NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @TempConfigId AND TargetTable = 'RawSensorData')
    BEGIN
        INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, Priority, ContinueOnError, Enabled)
        VALUES (@TempConfigId, 'dbo', 'RawSensorData', 'Direct', 100, 1, 1);
        PRINT 'Inserted TopicTableMapping: TemperatureSensors -> RawSensorData';
    END

    -- Mapping 2: High temperature alerts
    IF NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @TempConfigId AND TargetTable = 'SensorAlerts')
    BEGIN
        INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, ColumnMappingJson, FilterCondition, Priority, ContinueOnError, Enabled)
        VALUES (
            @TempConfigId,
            'dbo',
            'SensorAlerts',
            'Direct',
            '{"DeviceId": "$.device_id", "SensorType": "$.sensor_type", "AlertType": "HighTemperature", "Value": "$.value", "Threshold": 75.0, "AlertTime": "$.timestamp", "Severity": "Warning"}',
            'Value > 75.0',
            90,
            1,
            1
        );
        PRINT 'Inserted TopicTableMapping: TemperatureSensors -> SensorAlerts';
    END
END
GO

-- Mappings for PressureSensors
DECLARE @PressureConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'PressureSensors');
IF @PressureConfigId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @PressureConfigId)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, Priority, ContinueOnError, Enabled)
    VALUES (@PressureConfigId, 'dbo', 'RawSensorData', 'Direct', 100, 1, 1);
    PRINT 'Inserted TopicTableMapping for PressureSensors';
END
GO

-- Mappings for HumiditySensors
DECLARE @HumidityConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'HumiditySensors');
IF @HumidityConfigId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @HumidityConfigId)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, Priority, ContinueOnError, Enabled)
    VALUES (@HumidityConfigId, 'dbo', 'RawSensorData', 'Direct', 100, 1, 1);
    PRINT 'Inserted TopicTableMapping for HumiditySensors';
END
GO

-- Mappings for DashboardTests
DECLARE @DashboardConfigId INT = (SELECT Id FROM MQTT.ReceiverConfig WHERE ConfigName = 'DashboardTests');
IF @DashboardConfigId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MQTT.TopicTableMapping WHERE ReceiverConfigId = @DashboardConfigId)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, ColumnMappingJson, Priority, ContinueOnError, Enabled)
    VALUES (
        @DashboardConfigId,
        'dbo',
        'RawSensorData',
        'INSERT',
        '{
            "DeviceId": "DeviceId",
            "SensorType": "SensorType",
            "Value": "Value",
            "Unit": "Unit",
            "Timestamp": "Timestamp"
        }',
        100,
        0,
        1
    );
    PRINT 'Inserted TopicTableMapping for DashboardTests';
END
GO

-- =============================================
-- Seed MQTT.SourceConfig (Publisher Configuration)
-- =============================================

-- Clear existing source config (optional)
-- DELETE FROM MQTT.SourceConfig;
-- GO

-- Source Config 1: TableA
IF NOT EXISTS (SELECT 1 FROM MQTT.SourceConfig WHERE SourceName = 'TableA')
BEGIN
    INSERT INTO MQTT.SourceConfig (
        SourceName, Enabled, TableName, SchemaName, Description,
        PrimaryKeyColumn, MonitorIdColumn, WhereClause, OrderByClause,
        BatchSize, PollingIntervalSeconds,
        TopicPattern, QosLevel, RetainFlag, FieldMappingJson
    )
    VALUES (
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
    );
    PRINT 'Inserted SourceConfig: TableA';
END
GO

-- Source Config 2: TableB
IF NOT EXISTS (SELECT 1 FROM MQTT.SourceConfig WHERE SourceName = 'TableB')
BEGIN
    INSERT INTO MQTT.SourceConfig (
        SourceName, Enabled, TableName, SchemaName, Description,
        PrimaryKeyColumn, MonitorIdColumn, WhereClause, OrderByClause,
        BatchSize, PollingIntervalSeconds,
        TopicPattern, QosLevel, RetainFlag, FieldMappingJson
    )
    VALUES (
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
    );
    PRINT 'Inserted SourceConfig: TableB';
END
GO

-- Source Config 3: TableC
IF NOT EXISTS (SELECT 1 FROM MQTT.SourceConfig WHERE SourceName = 'TableC')
BEGIN
    INSERT INTO MQTT.SourceConfig (
        SourceName, Enabled, TableName, SchemaName, Description,
        PrimaryKeyColumn, MonitorIdColumn, WhereClause, OrderByClause,
        BatchSize, PollingIntervalSeconds,
        TopicPattern, QosLevel, RetainFlag, FieldMappingJson
    )
    VALUES (
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
    PRINT 'Inserted SourceConfig: TableC';
END
GO

-- =============================================
-- Verification Queries
-- =============================================

PRINT '';
PRINT 'Seed data loaded successfully!';
PRINT '';
PRINT '=== ReceiverConfig Summary ===';
SELECT ConfigName, TopicPattern, Enabled FROM MQTT.ReceiverConfig ORDER BY Id;

PRINT '';
PRINT '=== TopicTableMapping Summary ===';
SELECT
    rc.ConfigName,
    tm.TargetTable,
    tm.InsertMode,
    tm.Priority,
    tm.Enabled
FROM MQTT.TopicTableMapping tm
INNER JOIN MQTT.ReceiverConfig rc ON rc.Id = tm.ReceiverConfigId
ORDER BY rc.ConfigName, tm.Priority DESC;

PRINT '';
PRINT '=== SourceConfig Summary ===';
SELECT SourceName, TableName, TopicPattern, Enabled FROM MQTT.SourceConfig ORDER BY Id;
GO
