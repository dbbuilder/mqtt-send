-- =============================================
-- Messages Table for MQTT Bridge System
-- =============================================

-- Drop table if exists (for clean reinstall)
IF OBJECT_ID('dbo.Messages', 'U') IS NOT NULL
    DROP TABLE dbo.Messages
GO

-- Create Messages table
CREATE TABLE dbo.Messages
(
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

    CONSTRAINT PK_Messages PRIMARY KEY CLUSTERED (MessageId ASC)
)
GO

-- Create index for efficient polling of pending messages
CREATE NONCLUSTERED INDEX IX_Messages_Status_MonitorId_Priority
ON dbo.Messages (Status, MonitorId, Priority, CreatedDate)
INCLUDE (MessageId, MessageContent, CorrelationId, RetryCount)
GO

-- Create index for monitoring specific monitor IDs
CREATE NONCLUSTERED INDEX IX_Messages_MonitorId_CreatedDate
ON dbo.Messages (MonitorId, CreatedDate DESC)
INCLUDE (Status, MessageContent)
GO

-- Create index for cleanup operations
CREATE NONCLUSTERED INDEX IX_Messages_Status_CreatedDate
ON dbo.Messages (Status, CreatedDate)
GO

PRINT 'Messages table created successfully'
GO
