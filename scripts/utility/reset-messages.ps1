# Reset Messages to Pending Status
# This script resets all messages back to Pending so you can test again

param(
    [switch]$AddNew,
    [int]$NewCount = 5
)

Write-Host "`n=== Reset Messages for Testing ===" -ForegroundColor Cyan

# Reset existing messages to Pending
Write-Host "`nResetting existing messages to Pending..." -ForegroundColor Yellow

$resetSql = @"
UPDATE MqttBridge.dbo.Messages
SET
    Status = 'Pending',
    ProcessedDate = NULL,
    RetryCount = 0,
    ErrorMessage = NULL

SELECT
    COUNT(*) as TotalMessages,
    COUNT(CASE WHEN Status = 'Pending' THEN 1 END) as PendingCount
FROM MqttBridge.dbo.Messages
"@

$result = $resetSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host " Messages reset successfully!" -ForegroundColor Green
    Write-Host $result
} else {
    Write-Host " Failed to reset messages!" -ForegroundColor Red
    Write-Host $result
    exit 1
}

# Optionally add new test messages
if ($AddNew) {
    Write-Host "`nAdding $NewCount new test messages..." -ForegroundColor Yellow

    $newMessagesSql = @"
INSERT INTO MqttBridge.dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
"@

    for ($i = 1; $i -le $NewCount; $i++) {
        $timestamp = (Get-Date).AddMinutes($i).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $temp = 70 + $i
        $humidity = 40 + $i

        $comma = if ($i -lt $NewCount) { "," } else { "" }
        $newMessagesSql += "`n    ('TEST_MONITOR', '{\"test\": $i, \"temperature\": $temp, \"humidity\": $humidity, \"timestamp\": `"$timestamp`"}', 0, 'Pending')$comma"
    }

    $newMessagesSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host " $NewCount new messages added!" -ForegroundColor Green
    } else {
        Write-Host " Failed to add new messages!" -ForegroundColor Red
    }
}

# Show current status
Write-Host "`nCurrent Message Status:" -ForegroundColor Cyan

$statusSql = @"
SELECT
    MonitorId,
    COUNT(*) as MessageCount,
    Status
FROM MqttBridge.dbo.Messages
GROUP BY MonitorId, Status
ORDER BY MonitorId, Status
"@

$statusSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

Write-Host "`n Ready to test again!" -ForegroundColor Green
Write-Host "  The Publisher will pick up these messages on its next poll cycle (5 seconds)" -ForegroundColor Gray
Write-Host ""
