# Verification Script: Check TableD Publishing Results
# Run this after the publisher has processed TableD

$ErrorActionPreference = "Stop"

Write-Host "`n=== TableD Publishing Verification ===`n" -ForegroundColor Cyan

# Check 1: Configuration exists
Write-Host "Check 1: TableD configuration exists..." -ForegroundColor Yellow
$configSQL = "SELECT SourceName, Enabled, TableName, TopicPattern, BatchSize, PollingIntervalSeconds FROM MQTT.SourceConfig WHERE SourceName = 'TableD';"
$configResult = $configSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Configuration exists`n" -ForegroundColor Green
    Write-Host $configResult -ForegroundColor Gray
} else {
    Write-Host "  ✗ Configuration not found!" -ForegroundColor Red
    exit 1
}

# Check 2: Records sent to MQTT
Write-Host "`nCheck 2: Records sent to MQTT..." -ForegroundColor Yellow
$sentSQL = "SELECT COUNT(*) AS SentCount FROM MQTT.SentRecords WHERE SourceName = 'TableD';"
$sentResult = $sentSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

$sentCount = [int]($sentResult -replace '\s+', '')

if ($sentCount -gt 0) {
    Write-Host "  ✓ $sentCount records sent to MQTT`n" -ForegroundColor Green
} else {
    Write-Host "  ✗ No records sent yet (publisher may not have run)`n" -ForegroundColor Yellow
}

# Check 3: No duplicates
Write-Host "Check 3: No duplicate records..." -ForegroundColor Yellow
$unsentSQL = @"
SELECT COUNT(*) AS UnsentRecords
FROM dbo.TableD d
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableD' AND m.RecordId = CAST(d.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;
"@
$unsentResult = $unsentSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

$unsentCount = [int]($unsentResult -replace '\s+', '')

if ($unsentCount -eq 0) {
    Write-Host "  ✓ All records sent (no duplicates)`n" -ForegroundColor Green
} elseif ($sentCount -eq 0) {
    Write-Host "  ℹ $unsentCount records waiting (publisher hasn't run yet)`n" -ForegroundColor Yellow
} else {
    Write-Host "  ℹ $unsentCount records still unsent (publisher may need more time)`n" -ForegroundColor Yellow
}

# Check 4: Throughput metrics
if ($sentCount -gt 0) {
    Write-Host "Check 4: Throughput metrics..." -ForegroundColor Yellow
    $metricsSQL = @"
SELECT
    SourceName,
    COUNT(*) AS RecordsSent,
    MIN(SentAt) AS FirstSent,
    MAX(SentAt) AS LastSent,
    DATEDIFF(SECOND, MIN(SentAt), MAX(SentAt)) AS DurationSeconds
FROM MQTT.SentRecords
WHERE SourceName = 'TableD'
GROUP BY SourceName;
"@
    $metricsSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C
    Write-Host "  ✓ Metrics retrieved`n" -ForegroundColor Green
}

# Check 5: Sample sent records
if ($sentCount -gt 0) {
    Write-Host "Check 5: Sample sent records..." -ForegroundColor Yellow
    $sampleSQL = "SELECT TOP 5 RecordId, Topic, SentAt, CorrelationId FROM MQTT.SentRecords WHERE SourceName = 'TableD' ORDER BY SentAt DESC;"
    $sampleSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C
    Write-Host "  ✓ Sample records shown`n" -ForegroundColor Green
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan

if ($sentCount -eq 0) {
    Write-Host "`n⚠️  TableD configuration exists but no records sent yet." -ForegroundColor Yellow
    Write-Host "   Make sure the MultiTablePublisher is running:`n" -ForegroundColor White
    Write-Host "   powershell -ExecutionPolicy Bypass -File run-multi-table-publisher.ps1`n" -ForegroundColor Gray
} elseif ($unsentCount -eq 0) {
    Write-Host "`n✓ SUCCESS! TableD is fully integrated:" -ForegroundColor Green
    Write-Host "  • Configuration active" -ForegroundColor Gray
    Write-Host "  • All $sentCount records published to MQTT" -ForegroundColor Gray
    Write-Host "  • No duplicates detected" -ForegroundColor Gray
    Write-Host "  • Tracking table working correctly`n" -ForegroundColor Gray

    Write-Host "Test re-running publisher to verify no duplicates:" -ForegroundColor Yellow
    Write-Host "  1. Restart the publisher (Ctrl+C and re-run)" -ForegroundColor White
    Write-Host "  2. Check logs - should show '0 unsent records' for TableD" -ForegroundColor White
    Write-Host "  3. Run this verification script again`n" -ForegroundColor White
} else {
    Write-Host "`n⚠️  TableD partially published:" -ForegroundColor Yellow
    Write-Host "  • $sentCount records sent" -ForegroundColor Gray
    Write-Host "  • $unsentCount records still waiting" -ForegroundColor Gray
    Write-Host "  • Publisher may need more time or restart`n" -ForegroundColor Gray
}

Write-Host "To add more test records:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File insert-test-records.ps1 -Table TableD -Count 10`n" -ForegroundColor Gray
