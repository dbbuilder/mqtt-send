-- Add Receiver Configuration for Dashboard Test Topics

USE MqttBridge;
GO

-- Add receiver config for test topics (if not exists)
IF NOT EXISTS (SELECT 1 FROM MQTT.ReceiverConfig WHERE ConfigName = 'DashboardTests')
BEGIN
    INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, Enabled, QoS)
    VALUES (
        'DashboardTests',
        'test/#',  -- Subscribe to ALL test topics
        'Dashboard test button messages',
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

    PRINT '✓ Added DashboardTests receiver config';
END
ELSE
BEGIN
    PRINT '⚠ DashboardTests config already exists';
END
GO

-- Add table mapping for test topics to RawSensorData
IF NOT EXISTS (
    SELECT 1
    FROM MQTT.TopicTableMapping ttm
    JOIN MQTT.ReceiverConfig rc ON ttm.ReceiverConfigId = rc.Id
    WHERE rc.ConfigName = 'DashboardTests'
)
BEGIN
    INSERT INTO MQTT.TopicTableMapping (
        ReceiverConfigId,
        TargetTable,
        TargetSchema,
        ColumnMappingJson,
        Enabled,
        InsertMode,
        Priority,
        ContinueOnError
    )
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
        100,
        0
    FROM MQTT.ReceiverConfig
    WHERE ConfigName = 'DashboardTests';

    PRINT '✓ Added table mapping for DashboardTests → RawSensorData';
END
ELSE
BEGIN
    PRINT '⚠ DashboardTests table mapping already exists';
END
GO

-- Verify configuration
PRINT '';
PRINT '========================================';
PRINT ' Test Topics Configuration';
PRINT '========================================';

SELECT
    rc.ConfigName,
    rc.TopicPattern,
    rc.Enabled,
    COUNT(ttm.Id) as TableMappings
FROM MQTT.ReceiverConfig rc
LEFT JOIN MQTT.TopicTableMapping ttm ON rc.Id = ttm.ReceiverConfigId
WHERE rc.ConfigName = 'DashboardTests'
GROUP BY rc.ConfigName, rc.TopicPattern, rc.Enabled;

PRINT '';
PRINT '✓ Dashboard test buttons will now work!';
PRINT '';
PRINT 'Receiver will subscribe to: test/#';
PRINT 'Includes: test/temperature/TEST1, test/pressure/TEST1, etc.';
PRINT '';
PRINT '⚠ IMPORTANT: Restart ReceiverService to pick up new subscription!';
PRINT '';
GO
