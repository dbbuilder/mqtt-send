-- Create MQTT Schema
-- All MQTT-related objects will be in the MQTT schema

USE MqttBridge;
GO

-- Create MQTT schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'MQTT')
BEGIN
    EXEC('CREATE SCHEMA MQTT');
    PRINT 'Created MQTT schema';
END
ELSE
BEGIN
    PRINT 'MQTT schema already exists';
END
GO
