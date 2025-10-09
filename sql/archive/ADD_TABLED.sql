-- Add TableD dynamically to demonstrate database-driven configuration
USE MqttBridge;
GO

-- Step 1: Create TableD
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableD' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.TableD;
GO

CREATE TABLE dbo.TableD (
    RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonitorId NVARCHAR(50) NOT NULL,
    SensorType NVARCHAR(50) NOT NULL,
    Humidity DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(10) NOT NULL,
    Location NVARCHAR(100) NOT NULL,
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE INDEX IX_TableD_CreatedAt ON dbo.TableD(CreatedAt) INCLUDE (RecordId, MonitorId);
CREATE INDEX IX_TableD_MonitorId ON dbo.TableD(MonitorId) INCLUDE (RecordId, CreatedAt);
GO

PRINT 'TableD created successfully';
GO

-- Step 2: Add MQTT Configuration
EXEC MQTT.AddSourceConfiguration
    @SourceName = 'TableD',
    @TableName = 'TableD',
    @SchemaName = 'dbo',
    @Description = 'Humidity sensor data',
    @PrimaryKeyColumn = 'RecordId',
    @MonitorIdColumn = 'MonitorId',
    @TopicPattern = 'data/tableD/{MonitorId}',
    @FieldMappingJson = '{
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "Humidity": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
    }',
    @WhereClause = '1=1',
    @OrderByClause = 'CreatedAt ASC',
    @BatchSize = 100,
    @PollingIntervalSeconds = 2,
    @QosLevel = 1,
    @RetainFlag = 0,
    @Enabled = 1;
GO

PRINT 'TableD configuration added successfully';
GO

-- Step 3: Insert sample data
DECLARE @i INT = 0;
WHILE @i < 30
BEGIN
    INSERT INTO dbo.TableD (MonitorId, SensorType, Humidity, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'humidity',
        45 + (RAND() * 15), -- 45-60% humidity
        '%',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
GO

PRINT 'Inserted 30 sample records into TableD';
GO

-- Verification
SELECT 'Active Configurations:' AS Info;
SELECT SourceName, Enabled, TableName, TopicPattern
FROM MQTT.SourceConfig
WHERE Enabled = 1
ORDER BY SourceName;
GO

SELECT 'TableD Records:' AS Info;
SELECT COUNT(*) AS TotalRecords FROM dbo.TableD;
GO

SELECT 'TableD Unsent Records:' AS Info;
SELECT COUNT(*) AS UnsentRecords
FROM dbo.TableD d
LEFT JOIN MQTT.SentRecords m
    ON m.SourceName = 'TableD'
    AND m.RecordId = CAST(d.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;
GO
