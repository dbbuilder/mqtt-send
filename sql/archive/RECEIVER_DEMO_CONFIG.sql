-- MQTT Receiver Demo Configuration
-- Shows one-to-many topic mapping (one MQTT topic → multiple database tables)

USE MqttBridge;
GO

-- =============================================
-- Demo Tables for Receiver
-- =============================================

-- Raw sensor data storage
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RawSensorData' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.RawSensorData
    (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        DeviceId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        Value DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NOT NULL,
        Timestamp DATETIME2 NOT NULL,
        ReceivedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '✓ Created dbo.RawSensorData table';
END
GO

-- Aggregated sensor readings
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SensorAggregates' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.SensorAggregates
    (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        DeviceId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        AvgValue DECIMAL(18,4) NULL,
        MinValue DECIMAL(18,4) NULL,
        MaxValue DECIMAL(18,4) NULL,
        ReadingCount INT NOT NULL DEFAULT 1,
        FirstReading DATETIME2 NOT NULL,
        LastReading DATETIME2 NOT NULL,

        UNIQUE (DeviceId, SensorType, FirstReading)
    );
    PRINT '✓ Created dbo.SensorAggregates table';
END
GO

-- Alert log for threshold violations
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SensorAlerts' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.SensorAlerts
    (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        DeviceId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        AlertType NVARCHAR(50) NOT NULL, -- HighTemp, LowPressure, etc.
        Value DECIMAL(18,4) NOT NULL,
        Threshold DECIMAL(18,4) NOT NULL,
        AlertTime DATETIME2 NOT NULL,
        Severity NVARCHAR(20) NOT NULL DEFAULT 'Warning', -- Info, Warning, Critical

        INDEX IX_SensorAlerts_Device_Time (DeviceId, AlertTime DESC)
    );
    PRINT '✓ Created dbo.SensorAlerts table';
END
GO

-- =============================================
-- Receiver Configuration Example
-- =============================================

-- Config 1: Temperature sensor data (one topic → multiple tables)
DECLARE @ConfigId INT;

EXEC MQTT.AddReceiverConfig
    @ConfigName = 'TemperatureSensors',
    @TopicPattern = 'sensor/+/temperature', -- Matches sensor/device1/temperature, sensor/device2/temperature, etc.
    @Description = 'Temperature sensor readings from all devices',
    @MessageFormat = 'JSON',
    @FieldMappingJson = '{
        "DeviceId": "$.device_id",
        "SensorType": "$.sensor_type",
        "Value": "$.value",
        "Unit": "$.unit",
        "Timestamp": "$.timestamp"
    }',
    @QoS = 1,
    @Enabled = 1,
    @CreatedBy = 'System';

SET @ConfigId = SCOPE_IDENTITY();
PRINT '✓ Created TemperatureSensors config (ID: ' + CAST(@ConfigId AS NVARCHAR) + ')';

-- Mapping 1: Store ALL temperature readings in raw table
EXEC MQTT.AddTopicTableMapping
    @ReceiverConfigId = @ConfigId,
    @TargetSchema = 'dbo',
    @TargetTable = 'RawSensorData',
    @InsertMode = 'Direct',
    @Priority = 100,
    @Enabled = 1;

PRINT '  ↳ Mapped to dbo.RawSensorData (all readings)';

-- Mapping 2: Store HIGH temperature readings in alerts table
EXEC MQTT.AddTopicTableMapping
    @ReceiverConfigId = @ConfigId,
    @TargetSchema = 'dbo',
    @TargetTable = 'SensorAlerts',
    @InsertMode = 'Direct',
    @ColumnMappingJson = '{
        "DeviceId": "$.device_id",
        "SensorType": "$.sensor_type",
        "AlertType": "HighTemperature",
        "Value": "$.value",
        "Threshold": 75.0,
        "AlertTime": "$.timestamp",
        "Severity": "Warning"
    }',
    @FilterCondition = 'Value > 75.0',
    @Priority = 90,
    @Enabled = 1;

PRINT '  ↳ Mapped to dbo.SensorAlerts (Value > 75)';

-- Mapping 3: Aggregate readings (using stored proc)
EXEC MQTT.AddTopicTableMapping
    @ReceiverConfigId = @ConfigId,
    @TargetSchema = 'dbo',
    @TargetTable = 'SensorAggregates',
    @InsertMode = 'StoredProc',
    @StoredProcName = 'dbo.UpdateSensorAggregate',
    @Priority = 80,
    @Enabled = 1;

PRINT '  ↳ Mapped to dbo.SensorAggregates (via stored proc)';

-- =============================================
-- Config 2: Pressure sensor data
-- =============================================

EXEC MQTT.AddReceiverConfig
    @ConfigName = 'PressureSensors',
    @TopicPattern = 'sensor/+/pressure',
    @Description = 'Pressure sensor readings',
    @MessageFormat = 'JSON',
    @FieldMappingJson = '{
        "DeviceId": "$.device_id",
        "SensorType": "$.sensor_type",
        "Value": "$.value",
        "Unit": "$.unit",
        "Timestamp": "$.timestamp"
    }',
    @QoS = 1,
    @Enabled = 1;

SET @ConfigId = SCOPE_IDENTITY();
PRINT '';
PRINT '✓ Created PressureSensors config (ID: ' + CAST(@ConfigId AS NVARCHAR) + ')';

-- Store in raw data
EXEC MQTT.AddTopicTableMapping
    @ReceiverConfigId = @ConfigId,
    @TargetSchema = 'dbo',
    @TargetTable = 'RawSensorData',
    @InsertMode = 'Direct',
    @Enabled = 1;

PRINT '  ↳ Mapped to dbo.RawSensorData';

-- =============================================
-- Config 3: Wildcard pattern for all sensor types
-- =============================================

EXEC MQTT.AddReceiverConfig
    @ConfigName = 'AllSensors',
    @TopicPattern = 'sensor/#', -- Matches all topics starting with sensor/
    @Description = 'Catch-all for any sensor data',
    @MessageFormat = 'JSON',
    @FieldMappingJson = '{
        "DeviceId": "$.device_id",
        "SensorType": "$.sensor_type",
        "Value": "$.value",
        "Unit": "$.unit",
        "Timestamp": "$.timestamp"
    }',
    @QoS = 0,
    @Enabled = 0; -- Disabled by default (enable for debug)

PRINT '';
PRINT '✓ Created AllSensors wildcard config (DISABLED)';

-- =============================================
-- Helper Stored Procedure for Aggregation
-- =============================================

CREATE OR ALTER PROCEDURE dbo.UpdateSensorAggregate
    @DeviceId NVARCHAR(50),
    @SensorType NVARCHAR(50),
    @Value DECIMAL(18,4),
    @Timestamp DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HourBucket DATETIME2 = DATEADD(HOUR, DATEDIFF(HOUR, 0, @Timestamp), 0);

    -- Upsert aggregate
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

PRINT '';
PRINT '✓ Created dbo.UpdateSensorAggregate stored procedure';

-- =============================================
-- View Current Configuration
-- =============================================

PRINT '';
PRINT '============================================';
PRINT 'RECEIVER CONFIGURATION SUMMARY';
PRINT '============================================';

SELECT
    rc.ConfigName,
    rc.TopicPattern,
    rc.Enabled,
    COUNT(tm.Id) AS TableMappingCount
FROM MQTT.ReceiverConfig rc
LEFT JOIN MQTT.TopicTableMapping tm ON tm.ReceiverConfigId = rc.Id AND tm.Enabled = 1
GROUP BY rc.Id, rc.ConfigName, rc.TopicPattern, rc.Enabled
ORDER BY rc.ConfigName;

PRINT '';
PRINT 'Detailed Mappings:';

SELECT
    rc.ConfigName AS [Config],
    rc.TopicPattern AS [Topic Pattern],
    tm.TargetTable AS [Target Table],
    tm.InsertMode AS [Insert Mode],
    tm.FilterCondition AS [Filter],
    tm.Priority,
    tm.Enabled
FROM MQTT.ReceiverConfig rc
INNER JOIN MQTT.TopicTableMapping tm ON tm.ReceiverConfigId = rc.Id
ORDER BY rc.ConfigName, tm.Priority DESC;

PRINT '';
PRINT '============================================';
PRINT 'DEMO SETUP COMPLETE';
PRINT '============================================';
PRINT '';
PRINT 'Example MQTT Message:';
PRINT '  Topic: sensor/device1/temperature';
PRINT '  Payload: {"device_id":"device1","sensor_type":"temperature","value":78.5,"unit":"F","timestamp":"2024-01-15T10:30:00Z"}';
PRINT '';
PRINT 'This message will be written to:';
PRINT '  1. dbo.RawSensorData (all readings)';
PRINT '  2. dbo.SensorAlerts (because 78.5 > 75)';
PRINT '  3. dbo.SensorAggregates (hourly aggregation)';
PRINT '';
GO
