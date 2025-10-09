-- =============================================
-- Script: 01_CREATE_SCHEMAS.sql
-- Description: Creates MQTT and Logging schemas
-- Database: MqttBridge
-- =============================================

USE MqttBridge;
GO

-- Create MQTT schema if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'MQTT')
BEGIN
    EXEC('CREATE SCHEMA MQTT');
    PRINT 'Schema MQTT created successfully';
END
ELSE
BEGIN
    PRINT 'Schema MQTT already exists';
END
GO

-- Create Logging schema if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Logging')
BEGIN
    EXEC('CREATE SCHEMA Logging');
    PRINT 'Schema Logging created successfully';
END
ELSE
BEGIN
    PRINT 'Schema Logging already exists';
END
GO

PRINT 'Schema creation complete';
GO
