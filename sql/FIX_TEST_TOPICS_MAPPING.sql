-- Fix FieldMappingJson to use generic $.Value field instead of $.Temperature
USE MqttBridge;
GO

UPDATE MQTT.ReceiverConfig
SET FieldMappingJson = '{
    "DeviceId": "$.MonitorId",
    "SensorType": "$.SensorType",
    "Value": "$.Value",
    "Unit": "$.Unit",
    "Timestamp": "$.Timestamp"
}'
WHERE ConfigName = 'DashboardTests';

PRINT '✓ Updated DashboardTests FieldMappingJson to use generic Value field';

-- Verify the update
SELECT
    ConfigName,
    TopicPattern,
    FieldMappingJson
FROM MQTT.ReceiverConfig
WHERE ConfigName = 'DashboardTests';

PRINT '';
PRINT '⚠ IMPORTANT: Restart ReceiverService to pick up the updated mapping!';
GO
