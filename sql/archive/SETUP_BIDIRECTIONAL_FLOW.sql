-- =============================================
-- Setup Bidirectional MQTT Flow
-- Publisher sends from TableA/B/C to MQTT
-- Receiver subscribes and stores in RawSensorData
-- =============================================

USE MqttBridge;
GO

-- =============================================
-- Add Receiver Configurations for Publisher Topics
-- =============================================

-- Clear existing receiver configs (optional - comment out if you want to keep existing)
DELETE FROM MQTT.TopicTableMapping;
DELETE FROM MQTT.ReceiverConfig;
GO

-- Config for TableA data (monitor IDs 1 and 2)
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
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
GO

-- Config for TableB data (monitor IDs 1 and 2)
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
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
GO

-- Config for TableC data (monitor IDs 1 and 2)
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
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
GO

-- =============================================
-- Add Topic-to-Table Mappings
-- =============================================

-- TableA -> RawSensorData
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority, ContinueOnError)
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
    'INSERT',
    1,
    0
FROM MQTT.ReceiverConfig
WHERE ConfigName = 'TableA_Data';
GO

-- TableB -> RawSensorData
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority, ContinueOnError)
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
    'INSERT',
    1,
    0
FROM MQTT.ReceiverConfig
WHERE ConfigName = 'TableB_Data';
GO

-- TableC -> RawSensorData
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority, ContinueOnError)
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
    'INSERT',
    1,
    0
FROM MQTT.ReceiverConfig
WHERE ConfigName = 'TableC_Data';
GO

-- =============================================
-- Verify Configuration
-- =============================================

PRINT '';
PRINT '========================================';
PRINT ' Bidirectional Flow Configuration';
PRINT '========================================';
PRINT '';

PRINT 'Receiver Configurations:';
SELECT
    rc.ConfigName,
    rc.TopicPattern,
    rc.Enabled,
    COUNT(ttm.Id) as TableMappings
FROM MQTT.ReceiverConfig rc
LEFT JOIN MQTT.TopicTableMapping ttm ON rc.Id = ttm.ReceiverConfigId
GROUP BY rc.ConfigName, rc.TopicPattern, rc.Enabled;

PRINT '';
PRINT 'Publisher Sources:';
SELECT
    SourceName,
    TopicPattern,
    Enabled,
    PollingIntervalSeconds
FROM MQTT.SourceConfig
WHERE Enabled = 1;

PRINT '';
PRINT '========================================';
PRINT ' Setup Complete!';
PRINT '========================================';
PRINT '';
PRINT 'Expected Flow:';
PRINT '  1. Publisher reads TableA/B/C (MonitorId 1,2)';
PRINT '  2. Publishes to data/tableA/1, data/tableA/2, etc.';
PRINT '  3. Receiver subscribes to data/tableA/+, data/tableB/+, data/tableC/+';
PRINT '  4. Stores received data in RawSensorData';
PRINT '';
GO
