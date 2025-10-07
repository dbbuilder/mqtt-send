-- MQTT Receiver Configuration Schema
-- Handles dynamic MQTT topic subscriptions and routing to database tables

USE MqttBridge;
GO

-- =============================================
-- MQTT Receiver Configuration Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ReceiverConfig' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.ReceiverConfig
    (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ConfigName NVARCHAR(100) NOT NULL UNIQUE,
        TopicPattern NVARCHAR(500) NOT NULL,
        Description NVARCHAR(500) NULL,

        -- Message parsing configuration
        MessageFormat NVARCHAR(20) NOT NULL DEFAULT 'JSON', -- JSON, XML, CSV, Raw
        FieldMappingJson NVARCHAR(MAX) NULL, -- JSON mapping of MQTT fields to DB columns

        -- Configuration settings
        Enabled BIT NOT NULL DEFAULT 1,
        QoS TINYINT NOT NULL DEFAULT 1, -- MQTT QoS level (0, 1, 2)

        -- Metadata
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy NVARCHAR(100) NULL,

        INDEX IX_ReceiverConfig_Enabled (Enabled) INCLUDE (TopicPattern, MessageFormat)
    );

    PRINT '✓ Created MQTT.ReceiverConfig table';
END
GO

-- =============================================
-- Topic to Table Mapping Table (One-to-Many)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TopicTableMapping' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.TopicTableMapping
    (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ReceiverConfigId INT NOT NULL,

        -- Target table information
        TargetSchema NVARCHAR(50) NOT NULL DEFAULT 'dbo',
        TargetTable NVARCHAR(100) NOT NULL,

        -- Insert method
        InsertMode NVARCHAR(20) NOT NULL DEFAULT 'Direct', -- Direct, StoredProc, View
        StoredProcName NVARCHAR(200) NULL, -- Used if InsertMode = 'StoredProc'

        -- Column mapping (overrides ReceiverConfig.FieldMappingJson if specified)
        ColumnMappingJson NVARCHAR(MAX) NULL,

        -- Filtering
        FilterCondition NVARCHAR(500) NULL, -- SQL WHERE clause condition (e.g., "Value > 100")

        -- Configuration
        Enabled BIT NOT NULL DEFAULT 1,
        Priority INT NOT NULL DEFAULT 0, -- Processing order when multiple mappings exist

        -- Error handling
        ContinueOnError BIT NOT NULL DEFAULT 1, -- Continue to next mapping if this one fails

        -- Metadata
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),

        CONSTRAINT FK_TopicTableMapping_ReceiverConfig
            FOREIGN KEY (ReceiverConfigId) REFERENCES MQTT.ReceiverConfig(Id) ON DELETE CASCADE,

        INDEX IX_TopicTableMapping_ReceiverConfigId (ReceiverConfigId) INCLUDE (Enabled, Priority),
        INDEX IX_TopicTableMapping_Target (TargetSchema, TargetTable) INCLUDE (InsertMode)
    );

    PRINT '✓ Created MQTT.TopicTableMapping table';
END
GO

-- =============================================
-- Received Messages Log Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ReceivedMessages' AND schema_id = SCHEMA_ID('MQTT'))
BEGIN
    CREATE TABLE MQTT.ReceivedMessages
    (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        ReceiverConfigId INT NOT NULL,

        -- MQTT message details
        Topic NVARCHAR(500) NOT NULL,
        Payload NVARCHAR(MAX) NOT NULL,
        QoS TINYINT NOT NULL,

        -- Processing details
        ReceivedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        ProcessedAt DATETIME2 NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending, Success, Failed
        ErrorMessage NVARCHAR(MAX) NULL,
        TargetTablesProcessed INT NULL, -- Count of tables successfully written to

        -- Correlation
        CorrelationId UNIQUEIDENTIFIER NULL,

        INDEX IX_ReceivedMessages_Status (Status, ReceivedAt),
        INDEX IX_ReceivedMessages_Topic (Topic) INCLUDE (ReceivedAt),
        INDEX IX_ReceivedMessages_ReceiverConfigId (ReceiverConfigId) INCLUDE (ReceivedAt, Status)
    );

    PRINT '✓ Created MQTT.ReceivedMessages table';
END
GO

-- =============================================
-- Stored Procedure: Get Active Receiver Configurations
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.GetActiveReceiverConfigs
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        rc.Id,
        rc.ConfigName,
        rc.TopicPattern,
        rc.Description,
        rc.MessageFormat,
        rc.FieldMappingJson,
        rc.QoS,
        rc.Enabled,

        -- Include all table mappings as JSON array
        (
            SELECT
                tm.Id,
                tm.TargetSchema,
                tm.TargetTable,
                tm.InsertMode,
                tm.StoredProcName,
                tm.ColumnMappingJson,
                tm.FilterCondition,
                tm.Enabled,
                tm.Priority,
                tm.ContinueOnError
            FROM MQTT.TopicTableMapping tm
            WHERE tm.ReceiverConfigId = rc.Id
              AND tm.Enabled = 1
            ORDER BY tm.Priority DESC
            FOR JSON PATH
        ) AS TableMappingsJson

    FROM MQTT.ReceiverConfig rc
    WHERE rc.Enabled = 1
    ORDER BY rc.ConfigName;
END
GO

-- =============================================
-- Stored Procedure: Log Received Message
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.LogReceivedMessage
    @ReceiverConfigId INT,
    @Topic NVARCHAR(500),
    @Payload NVARCHAR(MAX),
    @QoS TINYINT,
    @CorrelationId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.ReceivedMessages (ReceiverConfigId, Topic, Payload, QoS, CorrelationId)
    VALUES (@ReceiverConfigId, @Topic, @Payload, @QoS, @CorrelationId);

    SELECT SCOPE_IDENTITY() AS MessageId;
END
GO

-- =============================================
-- Stored Procedure: Update Message Status
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.UpdateReceivedMessageStatus
    @MessageId BIGINT,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @TargetTablesProcessed INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE MQTT.ReceivedMessages
    SET
        Status = @Status,
        ProcessedAt = GETUTCDATE(),
        ErrorMessage = @ErrorMessage,
        TargetTablesProcessed = @TargetTablesProcessed
    WHERE Id = @MessageId;
END
GO

-- =============================================
-- Stored Procedure: Add Receiver Configuration
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.AddReceiverConfig
    @ConfigName NVARCHAR(100),
    @TopicPattern NVARCHAR(500),
    @Description NVARCHAR(500) = NULL,
    @MessageFormat NVARCHAR(20) = 'JSON',
    @FieldMappingJson NVARCHAR(MAX) = NULL,
    @QoS TINYINT = 1,
    @Enabled BIT = 1,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.ReceiverConfig
    (ConfigName, TopicPattern, Description, MessageFormat, FieldMappingJson, QoS, Enabled, CreatedBy)
    VALUES
    (@ConfigName, @TopicPattern, @Description, @MessageFormat, @FieldMappingJson, @QoS, @Enabled, @CreatedBy);

    SELECT SCOPE_IDENTITY() AS ReceiverConfigId;
END
GO

-- =============================================
-- Stored Procedure: Add Topic Table Mapping
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.AddTopicTableMapping
    @ReceiverConfigId INT,
    @TargetSchema NVARCHAR(50) = 'dbo',
    @TargetTable NVARCHAR(100),
    @InsertMode NVARCHAR(20) = 'Direct',
    @StoredProcName NVARCHAR(200) = NULL,
    @ColumnMappingJson NVARCHAR(MAX) = NULL,
    @FilterCondition NVARCHAR(500) = NULL,
    @Priority INT = 0,
    @ContinueOnError BIT = 1,
    @Enabled BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO MQTT.TopicTableMapping
    (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, StoredProcName,
     ColumnMappingJson, FilterCondition, Priority, ContinueOnError, Enabled)
    VALUES
    (@ReceiverConfigId, @TargetSchema, @TargetTable, @InsertMode, @StoredProcName,
     @ColumnMappingJson, @FilterCondition, @Priority, @ContinueOnError, @Enabled);

    SELECT SCOPE_IDENTITY() AS MappingId;
END
GO

-- =============================================
-- Stored Procedure: Get Configuration Count (for auto-reload)
-- =============================================
CREATE OR ALTER PROCEDURE MQTT.GetReceiverConfigCount
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS ConfigCount
    FROM MQTT.ReceiverConfig
    WHERE Enabled = 1;
END
GO

PRINT '';
PRINT '============================================';
PRINT 'MQTT Receiver Schema Created Successfully';
PRINT '============================================';
PRINT '';
PRINT 'Available Stored Procedures:';
PRINT '  - MQTT.GetActiveReceiverConfigs';
PRINT '  - MQTT.LogReceivedMessage';
PRINT '  - MQTT.UpdateReceivedMessageStatus';
PRINT '  - MQTT.AddReceiverConfig';
PRINT '  - MQTT.AddTopicTableMapping';
PRINT '  - MQTT.GetReceiverConfigCount';
PRINT '';
GO
