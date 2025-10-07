# Add a Single Test Message
# Useful for testing real-time message delivery while services are running

param(
    [string]$MonitorId = "REALTIME_TEST",
    [string]$Message = $null
)

Write-Host "`n=== Adding Test Message ===" -ForegroundColor Cyan

# Generate a test message if not provided
if (-not $Message) {
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $randomValue = Get-Random -Minimum 100 -Maximum 999
    $Message = "{`"test`": `"realtime`", `"value`": $randomValue, `"timestamp`": `"$timestamp`"}"
}

Write-Host "`nMonitorId: $MonitorId" -ForegroundColor Yellow
Write-Host "Message: $Message" -ForegroundColor Yellow

$insertSql = @"
INSERT INTO MqttBridge.dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES ('$MonitorId', '$Message', 0, 'Pending')

SELECT
    MessageId,
    MonitorId,
    MessageContent,
    CreatedDate,
    CorrelationId
FROM MqttBridge.dbo.Messages
WHERE MessageId = SCOPE_IDENTITY()
"@

$result = $insertSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n Message added successfully!" -ForegroundColor Green
    Write-Host $result
    Write-Host "`n Watch the Publisher and Subscriber terminals!" -ForegroundColor Green
    Write-Host "  The message should appear within 5 seconds (polling interval)" -ForegroundColor Gray
} else {
    Write-Host "`n Failed to add message!" -ForegroundColor Red
    Write-Host $result
    exit 1
}

Write-Host ""
