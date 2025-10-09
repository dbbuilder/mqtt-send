-- Remove TableD to reset the test
USE MqttBridge;
GO

-- Remove from configuration
DELETE FROM MQTT.SourceConfig WHERE SourceName = 'TableD';
GO

-- Remove tracking records
DELETE FROM MQTT.SentRecords WHERE SourceName = 'TableD';
GO

-- Drop table
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'TableD' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.TableD;
GO

PRINT 'TableD removed successfully';
GO

-- Show remaining configurations
SELECT 'Remaining Configurations:' AS Info;
SELECT SourceName, Enabled, TableName, TopicPattern
FROM MQTT.SourceConfig
WHERE Enabled = 1
ORDER BY SourceName;
GO
