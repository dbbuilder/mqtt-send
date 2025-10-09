-- Simple Demo Configuration Load (without stored procs)
USE MqttBridge;
GO

-- Create demo stored procedure first
CREATE OR ALTER PROCEDURE dbo.UpdateSensorAggregate
    @DeviceId NVARCHAR(50),
    @SensorType NVARCHAR(50),
    @Value DECIMAL(18,4),
    @Timestamp DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @HourBucket DATETIME2 = DATEADD(HOUR, DATEDIFF(HOUR, 0, @Timestamp), 0);

    MERGE dbo.SensorAggregates AS target
    USING (SELECT @DeviceId AS DeviceId, @SensorType AS SensorType, @HourBucket AS FirstReading) AS source
    ON target.DeviceId = source.DeviceId
       AND target.SensorType = source.SensorType
       AND target.FirstReading = source.FirstReading
    WHEN MATCHED THEN
        UPDATE SET
            AvgValue = (ISNULL(target.AvgValue, 0) * target.ReadingCount + @Value) / (target.ReadingCount + 1),
            MinValue = CASE WHEN @Value < ISNULL(target.MinValue, 999999) THEN @Value ELSE target.MinValue END,
            MaxValue = CASE WHEN @Value > ISNULL(target.MaxValue, -999999) THEN @Value ELSE target.MaxValue END,
            ReadingCount = target.ReadingCount + 1,
            LastReading = @Timestamp
    WHEN NOT MATCHED THEN
        INSERT (DeviceId, SensorType, AvgValue, MinValue, MaxValue, ReadingCount, FirstReading, LastReading)
        VALUES (@DeviceId, @SensorType, @Value, @Value, @Value, 1, @HourBucket, @Timestamp);
END
GO

-- Config 1: Temperature Sensors
DECLARE @TempConfigId INT;

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

SET @TempConfigId = SCOPE_IDENTITY();

-- Mapping 1: All readings to Raw table
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, Priority, Enabled)
VALUES (@TempConfigId, 'dbo', 'RawSensorData', 'Direct', 100, 1);

-- Mapping 2: High temp alerts
INSERT INTO MQTT.TopicTableMapping (
    ReceiverConfigId, TargetSchema, TargetTable, InsertMode,
    ColumnMappingJson, FilterCondition, Priority, Enabled
)
VALUES (
    @TempConfigId, 'dbo', 'SensorAlerts', 'Direct',
    '{"DeviceId": "$.device_id", "SensorType": "$.sensor_type", "AlertType": "HighTemperature", "Value": "$.value", "Threshold": 75.0, "AlertTime": "$.timestamp", "Severity": "Warning"}',
    'Value > 75.0',
    90,
    1
);

-- Mapping 3: Aggregates via stored proc
INSERT INTO MQTT.TopicTableMapping (
    ReceiverConfigId, TargetSchema, TargetTable, InsertMode, StoredProcName, Priority, Enabled
)
VALUES (@TempConfigId, 'dbo', 'SensorAggregates', 'StoredProc', 'dbo.UpdateSensorAggregate', 80, 1);

-- Config 2: Pressure Sensors
DECLARE @PressureConfigId INT;

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

SET @PressureConfigId = SCOPE_IDENTITY();

-- Mapping: Pressure to Raw table
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, Priority, Enabled)
VALUES (@PressureConfigId, 'dbo', 'RawSensorData', 'Direct', 100, 1);

GO

-- Show summary
PRINT 'Configuration loaded successfully!';
PRINT '';
SELECT
    rc.ConfigName,
    rc.TopicPattern,
    COUNT(tm.Id) AS MappingCount
FROM MQTT.ReceiverConfig rc
LEFT JOIN MQTT.TopicTableMapping tm ON tm.ReceiverConfigId = rc.Id
GROUP BY rc.Id, rc.ConfigName, rc.TopicPattern;
GO
