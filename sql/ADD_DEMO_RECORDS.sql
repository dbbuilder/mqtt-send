-- Add demo records for testing Monitor routing
-- Monitor 1 and Monitor 2 records across all tables
USE MqttBridge;
GO

-- Add records to TableA (Temperature data)
INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location)
VALUES
    ('1', 'temperature', 22.5, 'C', 'Monitor1-Demo-TableA'),
    ('2', 'temperature', 24.8, 'C', 'Monitor2-Demo-TableA');
GO

-- Add records to TableB (Pressure data)
INSERT INTO dbo.TableB (MonitorId, SensorType, Pressure, Unit, Location)
VALUES
    ('1', 'pressure', 101.3, 'kPa', 'Monitor1-Demo-TableB'),
    ('2', 'pressure', 102.1, 'kPa', 'Monitor2-Demo-TableB');
GO

-- Add records to TableC (Flow data)
INSERT INTO dbo.TableC (MonitorId, SensorType, FlowRate, Unit, Location)
VALUES
    ('1', 'flow', 15.7, 'L/min', 'Monitor1-Demo-TableC'),
    ('2', 'flow', 16.2, 'L/min', 'Monitor2-Demo-TableC');
GO

PRINT 'Demo records added successfully';
PRINT '';
PRINT 'Added 2 records to each table (1 for Monitor 1, 1 for Monitor 2)';
PRINT 'Total: 6 records';
PRINT '';
PRINT 'Publisher will process these within 2 seconds';
PRINT 'Subscriber 1 will receive Monitor 1 records';
PRINT 'Subscriber 2 will receive Monitor 2 records';
GO
