-- =============================================
-- Update Azure SQL SourceConfig with Complete Data
-- Based on working Docker SQL Server configuration
-- =============================================

-- Update TableA configuration
UPDATE MQTT.SourceConfig
SET
    Description = 'Temperature sensor data',
    PrimaryKeyColumn = 'RecordId',
    MonitorIdColumn = 'MonitorId',
    WhereClause = '1=1',
    OrderByClause = 'CreatedAt ASC',
    BatchSize = 100,
    PollingIntervalSeconds = 2,
    TopicPattern = 'data/tableA/{MonitorId}',
    QosLevel = 1,
    RetainFlag = 0,
    FieldMappingJson = '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Value","Unit":"Unit","Location":"Location","Timestamp":"Timestamp"}'
WHERE SourceName = 'TableA';

PRINT 'Updated TableA configuration';

-- Update TableB configuration
UPDATE MQTT.SourceConfig
SET
    Description = 'Pressure sensor data',
    PrimaryKeyColumn = 'RecordId',
    MonitorIdColumn = 'MonitorId',
    WhereClause = '1=1',
    OrderByClause = 'CreatedAt ASC',
    BatchSize = 100,
    PollingIntervalSeconds = 2,
    TopicPattern = 'data/tableB/{MonitorId}',
    QosLevel = 1,
    RetainFlag = 0,
    FieldMappingJson = '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Value","Unit":"Unit","Location":"Location","Timestamp":"Timestamp"}'
WHERE SourceName = 'TableB';

PRINT 'Updated TableB configuration';

-- Update TableC configuration
UPDATE MQTT.SourceConfig
SET
    Description = 'Flow sensor data',
    PrimaryKeyColumn = 'RecordId',
    MonitorIdColumn = 'MonitorId',
    WhereClause = '1=1',
    OrderByClause = 'CreatedAt ASC',
    BatchSize = 100,
    PollingIntervalSeconds = 2,
    TopicPattern = 'data/tableC/{MonitorId}',
    QosLevel = 1,
    RetainFlag = 0,
    FieldMappingJson = '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Value","Unit":"Unit","Location":"Location","Timestamp":"Timestamp"}'
WHERE SourceName = 'TableC';

PRINT 'Updated TableC configuration';

PRINT '';
PRINT '============================================';
PRINT 'SourceConfig update complete!';
PRINT '============================================';
PRINT '';
SELECT
    SourceName,
    Enabled,
    TableName,
    TopicPattern,
    PollingIntervalSeconds,
    PrimaryKeyColumn,
    MonitorIdColumn,
    Description
FROM MQTT.SourceConfig
ORDER BY SourceName;
