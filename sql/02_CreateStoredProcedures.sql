-- =============================================
-- Stored Procedures for MQTT Bridge System
-- =============================================

-- Drop existing procedures
IF OBJECT_ID('dbo.GetPendingMessages', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetPendingMessages
GO

IF OBJECT_ID('dbo.UpdateMessageStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.UpdateMessageStatus
GO

IF OBJECT_ID('dbo.CleanupExpiredMessages', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CleanupExpiredMessages
GO

IF OBJECT_ID('dbo.GetMessageStats', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetMessageStats
GO

-- =============================================
-- Procedure: GetPendingMessages
-- Description: Retrieves pending messages ordered by MonitorId, Priority, and CreatedDate
-- =============================================
CREATE PROCEDURE dbo.GetPendingMessages
    @BatchSize INT = 100
AS
BEGIN
    SET NOCOUNT ON

    SELECT TOP (@BatchSize)
        MessageId,
        MonitorId,
        MessageContent,
        Priority,
        CreatedDate,
        ProcessedDate,
        Status,
        RetryCount,
        ErrorMessage,
        CorrelationId
    FROM dbo.Messages
    WHERE Status = 'Pending'
    ORDER BY MonitorId, Priority ASC, CreatedDate ASC
END
GO

-- =============================================
-- Procedure: UpdateMessageStatus
-- Description: Updates message status after processing attempt
-- =============================================
CREATE PROCEDURE dbo.UpdateMessageStatus
    @MessageId BIGINT,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @IncrementRetryCount BIT = 0
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRY
        UPDATE dbo.Messages
        SET
            Status = @Status,
            ProcessedDate = CASE WHEN @Status = 'Published' THEN SYSUTCDATETIME() ELSE ProcessedDate END,
            ErrorMessage = @ErrorMessage,
            RetryCount = CASE WHEN @IncrementRetryCount = 1 THEN RetryCount + 1 ELSE RetryCount END
        WHERE MessageId = @MessageId

        SELECT @@ROWCOUNT AS RowsAffected
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@ErrorMsg, 16, 1)
    END CATCH
END
GO

-- =============================================
-- Procedure: CleanupExpiredMessages
-- Description: Removes old messages based on retention policy
-- =============================================
CREATE PROCEDURE dbo.CleanupExpiredMessages
    @RetentionDays INT = 30
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME())
    DECLARE @DeletedCount INT

    BEGIN TRY
        DELETE FROM dbo.Messages
        WHERE CreatedDate < @CutoffDate
        AND Status IN ('Published', 'Failed')

        SET @DeletedCount = @@ROWCOUNT

        SELECT
            @DeletedCount AS DeletedCount,
            @CutoffDate AS CutoffDate,
            @RetentionDays AS RetentionDays
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@ErrorMsg, 16, 1)
    END CATCH
END
GO

-- =============================================
-- Procedure: GetMessageStats
-- Description: Returns processing statistics
-- =============================================
CREATE PROCEDURE dbo.GetMessageStats
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        Status,
        COUNT(*) AS MessageCount,
        MIN(CreatedDate) AS OldestMessage,
        MAX(CreatedDate) AS NewestMessage,
        AVG(DATEDIFF(SECOND, CreatedDate, COALESCE(ProcessedDate, SYSUTCDATETIME()))) AS AvgProcessingTimeSeconds
    FROM dbo.Messages
    GROUP BY Status

    SELECT
        MonitorId,
        COUNT(*) AS MessageCount,
        MAX(CreatedDate) AS LastMessageDate
    FROM dbo.Messages
    WHERE Status = 'Pending'
    GROUP BY MonitorId
    ORDER BY MessageCount DESC
END
GO

PRINT 'Stored procedures created successfully'
GO
