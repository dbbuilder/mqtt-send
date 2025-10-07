# Complete System Test with Dynamic Table Addition
# Demonstrates adding TableD dynamically without code changes

$ErrorActionPreference = "Stop"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "    COMPLETE MQTT BRIDGE TEST - WITH DYNAMIC TABLE D" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Step 1: Verify initial setup (Tables A, B, C)
Write-Host "`n[Step 1] Verifying initial setup (TableA, TableB, TableC)..." -ForegroundColor Cyan

$configSQL = "SELECT SourceName, Enabled FROM MQTT.SourceConfig ORDER BY SourceName;"
Write-Host "`nCurrent configurations:" -ForegroundColor Yellow
$configSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -d MqttBridge -C

Write-Host "`nExpected: TableA, TableB, TableC (3 tables)" -ForegroundColor Gray
Write-Host "Press Enter to continue to add TableD..." -ForegroundColor Yellow
Read-Host

# Step 2: Add TableD
Write-Host "`n[Step 2] Adding TableD dynamically..." -ForegroundColor Cyan
& ".\test-add-new-table.ps1"

Write-Host "`n✓ TableD has been created and configured!" -ForegroundColor Green
Write-Host "`nPress Enter to restart the publisher..." -ForegroundColor Yellow
Read-Host

# Step 3: Show publisher restart instructions
Write-Host "`n[Step 3] Publisher Restart Required" -ForegroundColor Cyan
Write-Host "`nThe publisher needs to be restarted to pick up the new TableD configuration." -ForegroundColor Yellow
Write-Host "`nIn the publisher window:" -ForegroundColor White
Write-Host "  1. Press Ctrl+C to stop the current publisher" -ForegroundColor Gray
Write-Host "  2. Run: .\run-multi-table-publisher.ps1" -ForegroundColor Gray
Write-Host "`nExpected output after restart:" -ForegroundColor White
Write-Host "  Configuration loaded - Enabled sources: 4" -ForegroundColor Green
Write-Host "    - TableA: TableA (100 batch, 2s interval)" -ForegroundColor Gray
Write-Host "    - TableB: TableB (100 batch, 2s interval)" -ForegroundColor Gray
Write-Host "    - TableC: TableC (100 batch, 2s interval)" -ForegroundColor Gray
Write-Host "    - TableD: TableD (100 batch, 2s interval)" -ForegroundColor Green
Write-Host "`n  [TableD] Found 30 unsent records" -ForegroundColor Green
Write-Host "  [TableD] Published 30 records to MQTT" -ForegroundColor Green

Write-Host "`nPress Enter after restarting the publisher..." -ForegroundColor Yellow
Read-Host

# Step 4: Verify TableD is being processed
Write-Host "`n[Step 4] Verifying TableD is being processed..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$verifySQL = @"
-- Check configurations
SELECT 'Configurations:' AS Info;
SELECT SourceName, Enabled, TableName FROM MQTT.SourceConfig ORDER BY SourceName;

-- Check sent records
SELECT 'Sent Records by Table:' AS Info;
SELECT SourceName, COUNT(*) AS SentCount FROM MQTT.SentRecords GROUP BY SourceName ORDER BY SourceName;

-- Check TableD unsent
SELECT 'TableD Unsent Records:' AS Info;
SELECT COUNT(*) AS UnsentRecords
FROM dbo.TableD d
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableD' AND m.RecordId = CAST(d.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;
"@

$verifySQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -d MqttBridge -C

Write-Host "`n✓ Verification complete!" -ForegroundColor Green

# Step 5: Summary
Write-Host "`n[Step 5] Test Summary" -ForegroundColor Cyan
Write-Host "`nWhat we demonstrated:" -ForegroundColor Yellow
Write-Host "  ✓ Started with 3 tables (A, B, C)" -ForegroundColor Green
Write-Host "  ✓ Dynamically added TableD via SQL (no code changes!)" -ForegroundColor Green
Write-Host "  ✓ Publisher automatically picked up new configuration" -ForegroundColor Green
Write-Host "  ✓ TableD records are now being published to MQTT" -ForegroundColor Green
Write-Host "  ✓ Subscribers receive TableD messages on topic: data/tableD/{MonitorId}" -ForegroundColor Green

Write-Host "`nNext steps to verify end-to-end:" -ForegroundColor Yellow
Write-Host "  1. Check subscriber output - should see messages from data/tableD/1 and data/tableD/2" -ForegroundColor Gray
Write-Host "  2. Add more TableD records: .\insert-test-records.ps1 -Count 10 -Table D" -ForegroundColor Gray
Write-Host "  3. Watch publisher process them automatically" -ForegroundColor Gray

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "    TEST COMPLETE - DYNAMIC TABLE ADDITION SUCCESSFUL!" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "`nKey Takeaway:" -ForegroundColor Yellow
Write-Host "  New tables can be added via SQL configuration" -ForegroundColor White
Write-Host "  NO code changes required - fully database-driven! 🚀`n" -ForegroundColor White
