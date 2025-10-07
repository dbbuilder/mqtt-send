-- =============================================
-- Seed Data for Testing MQTT Bridge System
-- =============================================

USE MqttBridge
GO

-- Clear existing data (if table exists)
IF OBJECT_ID('dbo.Messages', 'U') IS NOT NULL
    DELETE FROM dbo.Messages
GO

PRINT 'Inserting seed data...'
GO

-- Insert test messages for different monitors
-- Monitor: SENSOR_001 (Temperature/Humidity Sensor)
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('SENSOR_001', '{"temperature": 72.5, "humidity": 45, "timestamp": "2025-10-05T20:00:00Z"}', 0, 'Pending'),
    ('SENSOR_001', '{"temperature": 73.2, "humidity": 46, "timestamp": "2025-10-05T20:05:00Z"}', 0, 'Pending'),
    ('SENSOR_001', '{"temperature": 74.0, "humidity": 47, "timestamp": "2025-10-05T20:10:00Z"}', 0, 'Pending')

-- Monitor: DEVICE_A (Generic IoT Device)
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('DEVICE_A', '{"status": "online", "battery": 85, "signal_strength": -65}', 0, 'Pending'),
    ('DEVICE_A', '{"status": "online", "battery": 84, "signal_strength": -67}', 0, 'Pending')

-- Monitor: GATEWAY_123 (Network Gateway)
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('GATEWAY_123', '{"connected_devices": 15, "uptime_seconds": 86400, "errors": 0}', 0, 'Pending'),
    ('GATEWAY_123', '{"connected_devices": 16, "uptime_seconds": 86700, "errors": 0}', 0, 'Pending')

-- Monitor: PUMP_STATION_07 (Industrial Equipment)
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('PUMP_STATION_07', '{"flow_rate": 250.5, "pressure_psi": 45, "motor_temp": 85}', 1, 'Pending'),
    ('PUMP_STATION_07', '{"flow_rate": 248.3, "pressure_psi": 44, "motor_temp": 86}', 0, 'Pending')

-- Monitor: ALARM_PANEL_5 (Security System)
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('ALARM_PANEL_5', '{"zone": "front_door", "status": "armed", "last_event": "none"}', 0, 'Pending'),
    ('ALARM_PANEL_5', '{"zone": "motion_detector", "status": "triggered", "last_event": "motion_detected"}', 0, 'Pending')

GO

-- Display inserted data
SELECT
    MessageId,
    MonitorId,
    LEFT(MessageContent, 50) + '...' AS MessageContent,
    Priority,
    Status,
    CreatedDate,
    CorrelationId
FROM dbo.Messages
ORDER BY MonitorId, Priority, CreatedDate
GO

-- Display statistics
PRINT ''
PRINT 'Seed Data Summary:'
PRINT '------------------'
SELECT
    MonitorId,
    COUNT(*) AS MessageCount,
    MIN(Priority) AS MinPriority,
    MAX(Priority) AS MaxPriority
FROM dbo.Messages
GROUP BY MonitorId
ORDER BY MonitorId
GO

PRINT ''
PRINT 'Total Messages: ' + CAST((SELECT COUNT(*) FROM dbo.Messages) AS VARCHAR(10))
GO
