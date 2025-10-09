-- =============================================
-- Seed SourceConfig with Complete Field Mappings
-- This fixes the empty FieldMapping issue and adds TableD
-- =============================================

-- Update TableA configuration
UPDATE MQTT.SourceConfig
SET
    FieldMappingJson = '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Temperature","Unit":"Unit","Location":"Location","Timestamp":"Timestamp","CreatedAt":"CreatedAt"}',
    PrimaryKeyColumn = 'RecordId',
    MonitorIdColumn = 'MonitorId',
    WhereClause = 'Published = 0',
    OrderByClause = 'CreatedAt ASC',
    BatchSize = 1000,
    PollingIntervalSeconds = 2,
    QosLevel = 1,
    RetainFlag = 0,
    Description = 'Temperature sensor data from TableA'
WHERE SourceName = 'TableA';

PRINT 'Updated TableA configuration';

-- Update TableB configuration
UPDATE MQTT.SourceConfig
SET
    FieldMappingJson = '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Temperature","Unit":"Unit","Location":"Location","Timestamp":"Timestamp","CreatedAt":"CreatedAt"}',
    PrimaryKeyColumn = 'RecordId',
    MonitorIdColumn = 'MonitorId',
    WhereClause = 'Published = 0',
    OrderByClause = 'CreatedAt ASC',
    BatchSize = 1000,
    PollingIntervalSeconds = 2,
    QosLevel = 1,
    RetainFlag = 0,
    Description = 'Temperature sensor data from TableB'
WHERE SourceName = 'TableB';

PRINT 'Updated TableB configuration';

-- Update TableC configuration
UPDATE MQTT.SourceConfig
SET
    FieldMappingJson = '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Temperature","Unit":"Unit","Location":"Location","Timestamp":"Timestamp","CreatedAt":"CreatedAt"}',
    PrimaryKeyColumn = 'RecordId',
    MonitorIdColumn = 'MonitorId',
    WhereClause = 'Published = 0',
    OrderByClause = 'CreatedAt ASC',
    BatchSize = 1000,
    PollingIntervalSeconds = 2,
    QosLevel = 1,
    RetainFlag = 0,
    Description = 'Temperature sensor data from TableC'
WHERE SourceName = 'TableC';

PRINT 'Updated TableC configuration';

-- Create TableD if it doesn't exist
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'TableD')
BEGIN
    CREATE TABLE dbo.TableD (
        RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
        MonitorId INT NOT NULL,
        SensorType NVARCHAR(50) NOT NULL,
        Temperature DECIMAL(5,2) NOT NULL,
        Unit NVARCHAR(10) NOT NULL,
        Location NVARCHAR(100) NULL,
        Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        Published BIT NOT NULL DEFAULT 0
    );
    PRINT 'Created TableD';
END
ELSE
BEGIN
    PRINT 'TableD already exists';
END

-- Add TableD to SourceConfig (disabled by default)
IF NOT EXISTS (SELECT * FROM MQTT.SourceConfig WHERE SourceName = 'TableD')
BEGIN
    INSERT INTO MQTT.SourceConfig (
        SourceName,
        Enabled,
        TableName,
        SchemaName,
        Description,
        PrimaryKeyColumn,
        MonitorIdColumn,
        WhereClause,
        OrderByClause,
        BatchSize,
        PollingIntervalSeconds,
        TopicPattern,
        QosLevel,
        RetainFlag,
        FieldMappingJson
    )
    VALUES (
        'TableD',
        0,  -- Disabled by default
        'TableD',
        'dbo',
        'Temperature sensor data from TableD (NEW)',
        'RecordId',
        'MonitorId',
        'Published = 0',
        'CreatedAt ASC',
        1000,
        2,
        'data/tableD/{MonitorId}',
        1,
        0,
        '{"RecordId":"RecordId","MonitorId":"MonitorId","SensorType":"SensorType","Temperature":"Temperature","Unit":"Unit","Location":"Location","Timestamp":"Timestamp","CreatedAt":"CreatedAt"}'
    );
    PRINT 'Added TableD to SourceConfig (disabled)';
END
ELSE
BEGIN
    PRINT 'TableD already exists in SourceConfig';
END

-- Create helper stored procedure to enable/disable tables
GO
CREATE OR ALTER PROCEDURE MQTT.ToggleSourceTable
    @SourceName NVARCHAR(100),
    @Enable BIT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT * FROM MQTT.SourceConfig WHERE SourceName = @SourceName)
    BEGIN
        RAISERROR('Source table "%s" not found', 16, 1, @SourceName);
        RETURN;
    END

    UPDATE MQTT.SourceConfig
    SET Enabled = @Enable
    WHERE SourceName = @SourceName;

    DECLARE @StatusText NVARCHAR(20) = CASE WHEN @Enable = 1 THEN 'ENABLED' ELSE 'DISABLED' END;

    PRINT 'Source table "' + @SourceName + '" ' + @StatusText;

    SELECT
        SourceName,
        Enabled,
        TableName,
        TopicPattern,
        PollingIntervalSeconds,
        Description
    FROM MQTT.SourceConfig
    WHERE SourceName = @SourceName;
END
GO

-- Create helper stored procedure to add test data
GO
CREATE OR ALTER PROCEDURE MQTT.AddTestDataToTable
    @TableName NVARCHAR(100),
    @MonitorId INT = 1,
    @RecordCount INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @Counter INT = 1;
    DECLARE @SensorTypes TABLE (SensorType NVARCHAR(50));

    INSERT INTO @SensorTypes VALUES ('Temperature'), ('Humidity'), ('Pressure');

    WHILE @Counter <= @RecordCount
    BEGIN
        DECLARE @SensorType NVARCHAR(50);
        DECLARE @Temperature DECIMAL(5,2);

        -- Random sensor type
        SELECT TOP 1 @SensorType = SensorType FROM @SensorTypes ORDER BY NEWID();

        -- Random temperature between 15.0 and 35.0
        SET @Temperature = 15.0 + (RAND() * 20.0);

        SET @Sql = N'
            INSERT INTO dbo.' + @TableName + N' (MonitorId, SensorType, Temperature, Unit, Location, Timestamp, CreatedAt, Published)
            VALUES (@MonitorId, @SensorType, @Temperature, ''C'', ''Lab-' + CAST(@MonitorId AS NVARCHAR(10)) + N''', GETUTCDATE(), GETUTCDATE(), 0)';

        EXEC sp_executesql @Sql,
            N'@MonitorId INT, @SensorType NVARCHAR(50), @Temperature DECIMAL(5,2)',
            @MonitorId = @MonitorId,
            @SensorType = @SensorType,
            @Temperature = @Temperature;

        SET @Counter = @Counter + 1;
    END

    PRINT 'Added ' + CAST(@RecordCount AS NVARCHAR(10)) + ' test records to ' + @TableName;

    -- Show summary
    DECLARE @CountSql NVARCHAR(MAX) = N'SELECT COUNT(*) AS TotalRecords, COUNT(CASE WHEN Published = 0 THEN 1 END) AS UnpublishedRecords FROM dbo.' + @TableName;
    EXEC sp_executesql @CountSql;
END
GO

PRINT '';
PRINT '============================================';
PRINT 'SourceConfig seeding complete!';
PRINT '============================================';
PRINT '';
PRINT 'Current Configuration:';
SELECT
    SourceName,
    Enabled,
    TableName,
    TopicPattern,
    PollingIntervalSeconds,
    CASE WHEN FieldMappingJson IS NULL THEN 'NULL (NEEDS FIX)' ELSE 'Configured' END AS FieldMapping,
    CASE WHEN PrimaryKeyColumn IS NULL THEN 'NULL (NEEDS FIX)' ELSE PrimaryKeyColumn END AS PrimaryKey
FROM MQTT.SourceConfig
ORDER BY SourceName;

PRINT '';
PRINT 'Usage Examples:';
PRINT '---------------';
PRINT '1. Enable TableD:';
PRINT '   EXEC MQTT.ToggleSourceTable @SourceName = ''TableD'', @Enable = 1';
PRINT '';
PRINT '2. Disable TableA:';
PRINT '   EXEC MQTT.ToggleSourceTable @SourceName = ''TableA'', @Enable = 0';
PRINT '';
PRINT '3. Add test data to TableD:';
PRINT '   EXEC MQTT.AddTestDataToTable @TableName = ''TableD'', @MonitorId = 3, @RecordCount = 10';
PRINT '';
PRINT '4. Check all configurations:';
PRINT '   SELECT SourceName, Enabled, TableName, TopicPattern FROM MQTT.SourceConfig ORDER BY SourceName';
PRINT '';
