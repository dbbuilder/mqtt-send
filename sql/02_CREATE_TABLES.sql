-- =============================================
-- Script: 02_CREATE_TABLES.sql
-- Description: Creates all tables in the MqttBridge database
-- Database: MqttBridge
-- =============================================

USE MqttBridge;
GO

-- =============================================
-- dbo Schema Tables
-- =============================================

-- Table: dbo.Messages
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'Messages')
BEGIN
    CREATE TABLE dbo.Messages (
        MessageId BIGINT IDENTITY(1,1) NOT NULL,
        MonitorId NVARCHAR(50) NOT NULL,
        MessageContent NVARCHAR(MAX) NOT NULL,
        Priority INT NOT NULL DEFAULT 0,
        CreatedDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ProcessedDate DATETIME2 NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
        RetryCount INT NOT NULL DEFAULT 0,
        ErrorMessage NVARCHAR(MAX) NULL,
        CorrelationId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        CONSTRAINT PK_Messages PRIMARY KEY CLUSTERED (MessageId)
    );
    PRINT 'Table dbo.Messages created successfully';
END
GO

-- Table: dbo.MqttSentRecords
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'MqttSentRecords')
BEGIN
    CREATE TABLE dbo.MqttSentRecords (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        SourceTable NVARCHAR(100) NOT NULL,
        RecordId NVARCHAR(100) NOT NULL,
        SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CorrelationId UNIQUEIDENTIFIER NULL,
        Topic NVARCHAR(500) NULL,
        CONSTRAINT PK__MqttSent__3214EC07A2C885F0 PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_MqttSentRecords_Source_Record UNIQUE (SourceTable, RecordId)
    );
    PRINT 'Table dbo.MqttSentRecords created successfully';
END
GO

-- Table: dbo.RawSensorData
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'RawSensorData')
BEGIN
    CREATE TABLE dbo.RawSensorData (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        DeviceId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        Value DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ReceivedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK__RawSenso__3214EC0764EEE16B PRIMARY KEY CLUSTERED (Id)
    );
    PRINT 'Table dbo.RawSensorData created successfully';
END
GO

-- Table: dbo.SensorAggregates
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'SensorAggregates')
BEGIN
    CREATE TABLE dbo.SensorAggregates (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        DeviceId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        FirstReading DATETIME2 NOT NULL,
        LastReading DATETIME2 NOT NULL,
        ReadingCount INT NOT NULL DEFAULT 1,
        LatestValue DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NULL,
        CONSTRAINT PK__SensorAg__3214EC078D20D365 PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ__SensorAg__E4387B4253855206 UNIQUE (DeviceId, SensorType, FirstReading)
    );
    PRINT 'Table dbo.SensorAggregates created successfully';
END
GO

-- Table: dbo.SensorAlerts
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'SensorAlerts')
BEGIN
    CREATE TABLE dbo.SensorAlerts (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        DeviceId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        AlertType NVARCHAR(50) NOT NULL,
        Value DECIMAL(18,4) NOT NULL,
        Threshold DECIMAL(18,4) NOT NULL,
        AlertTime DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        Severity NVARCHAR(20) NOT NULL DEFAULT 'Warning',
        CONSTRAINT PK__SensorAl__3214EC079E5A8886 PRIMARY KEY CLUSTERED (Id)
    );
    PRINT 'Table dbo.SensorAlerts created successfully';
END
GO

-- Table: dbo.TableA
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'TableA')
BEGIN
    CREATE TABLE dbo.TableA (
        RecordId INT IDENTITY(1,1) NOT NULL,
        MonitorId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        Temperature DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NULL,
        Location NVARCHAR(100) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        Timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK__TableA__FBDF78E9B551EDC8 PRIMARY KEY CLUSTERED (RecordId)
    );
    PRINT 'Table dbo.TableA created successfully';
END
GO

-- Table: dbo.TableB
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'TableB')
BEGIN
    CREATE TABLE dbo.TableB (
        RecordId INT IDENTITY(1,1) NOT NULL,
        MonitorId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        Pressure DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NULL,
        Location NVARCHAR(100) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        Timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK__TableB__FBDF78E974D7A76A PRIMARY KEY CLUSTERED (RecordId)
    );
    PRINT 'Table dbo.TableB created successfully';
END
GO

-- Table: dbo.TableC
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'TableC')
BEGIN
    CREATE TABLE dbo.TableC (
        RecordId INT IDENTITY(1,1) NOT NULL,
        MonitorId NVARCHAR(50) NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        FlowRate DECIMAL(18,4) NOT NULL,
        Unit NVARCHAR(20) NULL,
        Location NVARCHAR(100) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        Timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK__TableC__FBDF78E96BCB5119 PRIMARY KEY CLUSTERED (RecordId)
    );
    PRINT 'Table dbo.TableC created successfully';
END
GO

-- =============================================
-- Logging Schema Tables
-- =============================================

-- Table: Logging.ApplicationLogs
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('Logging') AND name = 'ApplicationLogs')
BEGIN
    CREATE TABLE Logging.ApplicationLogs (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        Level NVARCHAR(20) NOT NULL,
        ServiceName NVARCHAR(100) NOT NULL,
        Message NVARCHAR(MAX) NOT NULL,
        Exception NVARCHAR(MAX) NULL,
        MachineName NVARCHAR(100) NULL,
        ProcessId INT NULL,
        ThreadId INT NULL,
        Properties NVARCHAR(MAX) NULL,
        CONSTRAINT PK__Applicat__3214EC07769B7755 PRIMARY KEY CLUSTERED (Id)
    );
    PRINT 'Table Logging.ApplicationLogs created successfully';
END
GO

-- =============================================
-- MQTT Schema Tables
-- =============================================

-- Table: MQTT.ReceivedMessages
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('MQTT') AND name = 'ReceivedMessages')
BEGIN
    CREATE TABLE MQTT.ReceivedMessages (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        ReceiverConfigId INT NOT NULL,
        Topic NVARCHAR(500) NOT NULL,
        Payload NVARCHAR(MAX) NOT NULL,
        ReceivedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ProcessedAt DATETIME2 NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
        ErrorMessage NVARCHAR(MAX) NULL,
        RetryCount INT NOT NULL DEFAULT 0,
        CONSTRAINT PK__Received__3214EC0727B96E9A PRIMARY KEY CLUSTERED (Id)
    );
    PRINT 'Table MQTT.ReceivedMessages created successfully';
END
GO

-- Table: MQTT.ReceiverConfig
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('MQTT') AND name = 'ReceiverConfig')
BEGIN
    CREATE TABLE MQTT.ReceiverConfig (
        Id INT IDENTITY(1,1) NOT NULL,
        ConfigName NVARCHAR(100) NOT NULL,
        TopicPattern NVARCHAR(500) NOT NULL,
        Description NVARCHAR(500) NULL,
        MessageFormat NVARCHAR(20) NOT NULL,
        FieldMappingJson NVARCHAR(MAX) NULL,
        Enabled BIT NOT NULL DEFAULT 1,
        QoS TINYINT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy NVARCHAR(100) NULL,
        CONSTRAINT PK__Receiver__3214EC07BE0F9F03 PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ__Receiver__A89A7DB2735A3222 UNIQUE (ConfigName)
    );
    PRINT 'Table MQTT.ReceiverConfig created successfully';
END
GO

-- Table: MQTT.SentRecords
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('MQTT') AND name = 'SentRecords')
BEGIN
    CREATE TABLE MQTT.SentRecords (
        Id BIGINT IDENTITY(1,1) NOT NULL,
        SourceName NVARCHAR(100) NOT NULL,
        RecordId NVARCHAR(100) NOT NULL,
        SentAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CorrelationId UNIQUEIDENTIFIER NULL,
        Topic NVARCHAR(500) NULL,
        CONSTRAINT PK__SentReco__3214EC07BDEA96CF PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_SentRecords_Source_Record UNIQUE (SourceName, RecordId)
    );
    PRINT 'Table MQTT.SentRecords created successfully';
END
GO

-- Table: MQTT.SourceConfig
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('MQTT') AND name = 'SourceConfig')
BEGIN
    CREATE TABLE MQTT.SourceConfig (
        Id INT IDENTITY(1,1) NOT NULL,
        SourceName NVARCHAR(100) NOT NULL,
        Enabled BIT NOT NULL DEFAULT 1,
        TableName NVARCHAR(100) NOT NULL,
        SchemaName NVARCHAR(50) NOT NULL DEFAULT 'dbo',
        Description NVARCHAR(500) NULL,
        PrimaryKeyColumn NVARCHAR(100) NOT NULL,
        MonitorIdColumn NVARCHAR(100) NULL,
        WhereClause NVARCHAR(MAX) NULL,
        OrderByClause NVARCHAR(200) NULL,
        BatchSize INT NOT NULL DEFAULT 100,
        PollingIntervalSeconds INT NOT NULL DEFAULT 5,
        TopicPattern NVARCHAR(500) NOT NULL,
        QosLevel TINYINT NOT NULL DEFAULT 1,
        RetainFlag BIT NOT NULL DEFAULT 0,
        FieldMappingJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ModifiedAt DATETIME2 NULL,
        CONSTRAINT PK__SourceCo__3214EC07CD31AF0B PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ__SourceCo__3C28DC1701F6A1B5 UNIQUE (SourceName),
        CONSTRAINT CHK_QosLevel CHECK (QosLevel IN (0, 1, 2))
    );
    PRINT 'Table MQTT.SourceConfig created successfully';
END
GO

-- Table: MQTT.TopicTableMapping
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID('MQTT') AND name = 'TopicTableMapping')
BEGIN
    CREATE TABLE MQTT.TopicTableMapping (
        Id INT IDENTITY(1,1) NOT NULL,
        ReceiverConfigId INT NOT NULL,
        TargetSchema NVARCHAR(50) NOT NULL DEFAULT 'dbo',
        TargetTable NVARCHAR(100) NOT NULL,
        InsertMode NVARCHAR(20) NOT NULL DEFAULT 'Direct',
        StoredProcName NVARCHAR(200) NULL,
        ColumnMappingJson NVARCHAR(MAX) NULL,
        FilterCondition NVARCHAR(MAX) NULL,
        Enabled BIT NOT NULL DEFAULT 1,
        Priority INT NOT NULL DEFAULT 100,
        ContinueOnError BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK__TopicTab__3214EC07C9E8F9ED PRIMARY KEY CLUSTERED (Id)
    );
    PRINT 'Table MQTT.TopicTableMapping created successfully';
END
GO

PRINT 'All tables created successfully';
GO
