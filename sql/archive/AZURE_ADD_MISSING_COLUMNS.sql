-- =============================================
-- Add Missing Columns to Azure SQL Database
-- To match local SQL Server schema
-- =============================================

-- Add missing columns to MQTT.TopicTableMapping
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'TopicTableMapping' AND COLUMN_NAME = 'StoredProcName')
BEGIN
    ALTER TABLE MQTT.TopicTableMapping ADD StoredProcName NVARCHAR(200) NULL;
    PRINT 'Added StoredProcName to MQTT.TopicTableMapping';
END

-- Add missing columns to MQTT.ReceiverConfig
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'ReceiverConfig' AND COLUMN_NAME = 'CreatedBy')
BEGIN
    ALTER TABLE MQTT.ReceiverConfig ADD CreatedBy NVARCHAR(100) NULL;
    PRINT 'Added CreatedBy to MQTT.ReceiverConfig';
END

-- Add missing columns to Logging.ApplicationLogs
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'Logging' AND TABLE_NAME = 'ApplicationLogs' AND COLUMN_NAME = 'Properties')
BEGIN
    ALTER TABLE Logging.ApplicationLogs ADD Properties NVARCHAR(MAX) NULL;
    PRINT 'Added Properties to Logging.ApplicationLogs';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'Logging' AND TABLE_NAME = 'ApplicationLogs' AND COLUMN_NAME = 'CorrelationId')
BEGIN
    ALTER TABLE Logging.ApplicationLogs ADD CorrelationId UNIQUEIDENTIFIER NULL;
    PRINT 'Added CorrelationId to Logging.ApplicationLogs';
END

-- Add missing columns to MQTT.SourceConfig
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'Description')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD Description NVARCHAR(500) NULL;
    PRINT 'Added Description to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'PrimaryKeyColumn')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD PrimaryKeyColumn NVARCHAR(100) NULL;
    PRINT 'Added PrimaryKeyColumn to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'MonitorIdColumn')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD MonitorIdColumn NVARCHAR(100) NULL;
    PRINT 'Added MonitorIdColumn to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'OrderByClause')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD OrderByClause NVARCHAR(200) NULL;
    PRINT 'Added OrderByClause to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'BatchSize')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD BatchSize INT NULL DEFAULT 1000;
    PRINT 'Added BatchSize to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'QosLevel')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD QosLevel INT NULL DEFAULT 1;
    PRINT 'Added QosLevel to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'RetainFlag')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD RetainFlag BIT NULL DEFAULT 0;
    PRINT 'Added RetainFlag to MQTT.SourceConfig';
END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig' AND COLUMN_NAME = 'FieldMappingJson')
BEGIN
    ALTER TABLE MQTT.SourceConfig ADD FieldMappingJson NVARCHAR(MAX) NULL;
    PRINT 'Added FieldMappingJson to MQTT.SourceConfig';
END

-- Add missing columns to MQTT.SentRecords
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SentRecords' AND COLUMN_NAME = 'CorrelationId')
BEGIN
    ALTER TABLE MQTT.SentRecords ADD CorrelationId UNIQUEIDENTIFIER NULL;
    PRINT 'Added CorrelationId to MQTT.SentRecords';
END

PRINT '=============================================';
PRINT 'Missing columns added successfully';
PRINT '=============================================';
