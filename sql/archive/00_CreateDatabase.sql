-- =============================================
-- Create Database for MQTT Bridge System
-- =============================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MqttBridge')
BEGIN
    CREATE DATABASE MqttBridge
    PRINT 'Database MqttBridge created successfully'
END
ELSE
BEGIN
    PRINT 'Database MqttBridge already exists'
END
GO

USE MqttBridge
GO

PRINT 'Using MqttBridge database'
GO
