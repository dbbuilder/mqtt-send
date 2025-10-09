-- =============================================
-- Script: 03_CREATE_INDEXES.sql
-- Description: Creates all indexes and foreign keys
-- Database: MqttBridge
-- =============================================

USE MqttBridge;
GO

-- =============================================
-- dbo.Messages Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Messages') AND name = 'IX_Messages_MonitorId_CreatedDate')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Messages_MonitorId_CreatedDate
    ON dbo.Messages (MonitorId, CreatedDate)
    INCLUDE (Status, MessageContent);
    PRINT 'Index IX_Messages_MonitorId_CreatedDate created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Messages') AND name = 'IX_Messages_Status_CreatedDate')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Messages_Status_CreatedDate
    ON dbo.Messages (Status, CreatedDate);
    PRINT 'Index IX_Messages_Status_CreatedDate created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Messages') AND name = 'IX_Messages_Status_MonitorId_Priority')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Messages_Status_MonitorId_Priority
    ON dbo.Messages (Status, MonitorId, Priority, CreatedDate)
    INCLUDE (MessageId, MessageContent, CorrelationId, RetryCount);
    PRINT 'Index IX_Messages_Status_MonitorId_Priority created';
END
GO

-- =============================================
-- dbo.MqttSentRecords Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.MqttSentRecords') AND name = 'IX_MqttSentRecords_SourceTable')
BEGIN
    CREATE NONCLUSTERED INDEX IX_MqttSentRecords_SourceTable
    ON dbo.MqttSentRecords (SourceTable)
    INCLUDE (RecordId, SentAt);
    PRINT 'Index IX_MqttSentRecords_SourceTable created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.MqttSentRecords') AND name = 'IX_MqttSentRecords_SentAt')
BEGIN
    CREATE NONCLUSTERED INDEX IX_MqttSentRecords_SentAt
    ON dbo.MqttSentRecords (SentAt)
    INCLUDE (SourceTable, RecordId);
    PRINT 'Index IX_MqttSentRecords_SentAt created';
END
GO

-- =============================================
-- dbo.SensorAlerts Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.SensorAlerts') AND name = 'IX_SensorAlerts_Device_Time')
BEGIN
    CREATE NONCLUSTERED INDEX IX_SensorAlerts_Device_Time
    ON dbo.SensorAlerts (DeviceId, AlertTime);
    PRINT 'Index IX_SensorAlerts_Device_Time created';
END
GO

-- =============================================
-- dbo.TableA Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableA') AND name = 'IX_TableA_MonitorId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TableA_MonitorId
    ON dbo.TableA (MonitorId)
    INCLUDE (RecordId, CreatedAt);
    PRINT 'Index IX_TableA_MonitorId created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableA') AND name = 'IX_TableA_CreatedAt')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TableA_CreatedAt
    ON dbo.TableA (CreatedAt)
    INCLUDE (RecordId, MonitorId);
    PRINT 'Index IX_TableA_CreatedAt created';
END
GO

-- =============================================
-- dbo.TableB Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableB') AND name = 'IX_TableB_MonitorId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TableB_MonitorId
    ON dbo.TableB (MonitorId)
    INCLUDE (RecordId, CreatedAt);
    PRINT 'Index IX_TableB_MonitorId created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableB') AND name = 'IX_TableB_CreatedAt')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TableB_CreatedAt
    ON dbo.TableB (CreatedAt)
    INCLUDE (RecordId, MonitorId);
    PRINT 'Index IX_TableB_CreatedAt created';
END
GO

-- =============================================
-- dbo.TableC Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableC') AND name = 'IX_TableC_MonitorId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TableC_MonitorId
    ON dbo.TableC (MonitorId)
    INCLUDE (RecordId, CreatedAt);
    PRINT 'Index IX_TableC_MonitorId created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TableC') AND name = 'IX_TableC_CreatedAt')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TableC_CreatedAt
    ON dbo.TableC (CreatedAt)
    INCLUDE (RecordId, MonitorId);
    PRINT 'Index IX_TableC_CreatedAt created';
END
GO

-- =============================================
-- Logging.ApplicationLogs Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('Logging.ApplicationLogs') AND name = 'IX_ApplicationLogs_Level')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ApplicationLogs_Level
    ON Logging.ApplicationLogs (Level);
    PRINT 'Index IX_ApplicationLogs_Level created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('Logging.ApplicationLogs') AND name = 'IX_ApplicationLogs_ServiceName')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ApplicationLogs_ServiceName
    ON Logging.ApplicationLogs (ServiceName);
    PRINT 'Index IX_ApplicationLogs_ServiceName created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('Logging.ApplicationLogs') AND name = 'IX_ApplicationLogs_Timestamp')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ApplicationLogs_Timestamp
    ON Logging.ApplicationLogs (Timestamp);
    PRINT 'Index IX_ApplicationLogs_Timestamp created';
END
GO

-- =============================================
-- MQTT.ReceivedMessages Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.ReceivedMessages') AND name = 'IX_ReceivedMessages_ReceiverConfigId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ReceivedMessages_ReceiverConfigId
    ON MQTT.ReceivedMessages (ReceiverConfigId)
    INCLUDE (ReceivedAt, Status);
    PRINT 'Index IX_ReceivedMessages_ReceiverConfigId created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.ReceivedMessages') AND name = 'IX_ReceivedMessages_Status')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ReceivedMessages_Status
    ON MQTT.ReceivedMessages (Status, ReceivedAt);
    PRINT 'Index IX_ReceivedMessages_Status created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.ReceivedMessages') AND name = 'IX_ReceivedMessages_Topic')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ReceivedMessages_Topic
    ON MQTT.ReceivedMessages (Topic)
    INCLUDE (ReceivedAt);
    PRINT 'Index IX_ReceivedMessages_Topic created';
END
GO

-- =============================================
-- MQTT.ReceiverConfig Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.ReceiverConfig') AND name = 'IX_ReceiverConfig_Enabled')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ReceiverConfig_Enabled
    ON MQTT.ReceiverConfig (Enabled)
    INCLUDE (TopicPattern, MessageFormat);
    PRINT 'Index IX_ReceiverConfig_Enabled created';
END
GO

-- =============================================
-- MQTT.SentRecords Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.SentRecords') AND name = 'IX_SentRecords_SourceName')
BEGIN
    CREATE NONCLUSTERED INDEX IX_SentRecords_SourceName
    ON MQTT.SentRecords (SourceName)
    INCLUDE (RecordId, SentAt);
    PRINT 'Index IX_SentRecords_SourceName created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.SentRecords') AND name = 'IX_SentRecords_SentAt')
BEGIN
    CREATE NONCLUSTERED INDEX IX_SentRecords_SentAt
    ON MQTT.SentRecords (SentAt)
    INCLUDE (SourceName, RecordId);
    PRINT 'Index IX_SentRecords_SentAt created';
END
GO

-- =============================================
-- MQTT.SourceConfig Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.SourceConfig') AND name = 'IX_SourceConfig_Enabled')
BEGIN
    CREATE NONCLUSTERED INDEX IX_SourceConfig_Enabled
    ON MQTT.SourceConfig (Enabled)
    INCLUDE (SourceName, TableName);
    PRINT 'Index IX_SourceConfig_Enabled created';
END
GO

-- =============================================
-- MQTT.TopicTableMapping Indexes
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.TopicTableMapping') AND name = 'IX_TopicTableMapping_ReceiverConfigId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TopicTableMapping_ReceiverConfigId
    ON MQTT.TopicTableMapping (ReceiverConfigId)
    INCLUDE (Enabled, Priority);
    PRINT 'Index IX_TopicTableMapping_ReceiverConfigId created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('MQTT.TopicTableMapping') AND name = 'IX_TopicTableMapping_Target')
BEGIN
    CREATE NONCLUSTERED INDEX IX_TopicTableMapping_Target
    ON MQTT.TopicTableMapping (TargetSchema, TargetTable)
    INCLUDE (InsertMode);
    PRINT 'Index IX_TopicTableMapping_Target created';
END
GO

-- =============================================
-- Foreign Keys
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID('MQTT.FK_TopicTableMapping_ReceiverConfig'))
BEGIN
    ALTER TABLE MQTT.TopicTableMapping
    ADD CONSTRAINT FK_TopicTableMapping_ReceiverConfig
    FOREIGN KEY (ReceiverConfigId) REFERENCES MQTT.ReceiverConfig(Id);
    PRINT 'Foreign key FK_TopicTableMapping_ReceiverConfig created';
END
GO

PRINT 'All indexes and foreign keys created successfully';
GO
