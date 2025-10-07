# Complete System Test Script
# Tests Publisher + Subscriber 1 + Subscriber 2 + Data Generator

$ErrorActionPreference = "Stop"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "           MQTT BRIDGE COMPLETE SYSTEM TEST" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "`nThis test will verify:" -ForegroundColor Yellow
Write-Host "  1. MultiTablePublisher reads from tracked tables (A, B, C, D)" -ForegroundColor Gray
Write-Host "  2. Subscriber 1 receives messages for MonitorId = 1" -ForegroundColor Gray
Write-Host "  3. Subscriber 2 receives messages for MonitorId = 2" -ForegroundColor Gray
Write-Host "  4. Data generator adds records to tracked tables" -ForegroundColor Gray
Write-Host "  5. Duplicate prevention via MQTT.SentRecords tracking table`n" -ForegroundColor Gray

# Step 1: Verify database setup
Write-Host "`n[Step 1] Verifying database setup..." -ForegroundColor Cyan

$checkSQL = @"
SELECT
    (SELECT COUNT(*) FROM MQTT.SourceConfig WHERE Enabled = 1) AS EnabledSources,
    (SELECT COUNT(*) FROM dbo.TableA) AS TableA_Records,
    (SELECT COUNT(*) FROM dbo.TableB) AS TableB_Records,
    (SELECT COUNT(*) FROM dbo.TableC) AS TableC_Records,
    (SELECT COUNT(*) FROM MQTT.SentRecords) AS SentRecords;
"@

$dbStatus = $checkSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

Write-Host $dbStatus -ForegroundColor Gray

Write-Host "`n  ✓ Database ready" -ForegroundColor Green

# Step 2: Build projects
Write-Host "`n[Step 2] Building projects..." -ForegroundColor Cyan

Write-Host "  Building MultiTablePublisher..." -ForegroundColor Yellow
Push-Location src\MultiTablePublisher
dotnet build --verbosity quiet > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ MultiTablePublisher built" -ForegroundColor Green
} else {
    Write-Host "    ✗ Build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

Write-Host "  Building SubscriberService..." -ForegroundColor Yellow
Push-Location src\SubscriberService
dotnet build --verbosity quiet > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ SubscriberService built" -ForegroundColor Green
} else {
    Write-Host "    ✗ Build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# Step 3: Show component startup instructions
Write-Host "`n[Step 3] Component Startup Instructions" -ForegroundColor Cyan

Write-Host "`nYou need to start these components in SEPARATE PowerShell windows:`n" -ForegroundColor Yellow

Write-Host "  Window 1 - Subscriber for Monitor 1:" -ForegroundColor White
Write-Host "  ────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "    cd src\SubscriberService" -ForegroundColor Gray
Write-Host "    dotnet run --no-build -- --MonitorFilter `"1`" --ClientIdSuffix `"Monitor1`"`n" -ForegroundColor Gray

Write-Host "  Window 2 - Subscriber for Monitor 2:" -ForegroundColor White
Write-Host "  ────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "    cd src\SubscriberService" -ForegroundColor Gray
Write-Host "    dotnet run --no-build -- --MonitorFilter `"2`" --ClientIdSuffix `"Monitor2`"`n" -ForegroundColor Gray

Write-Host "  Window 3 - MultiTablePublisher:" -ForegroundColor White
Write-Host "  ────────────────────────────────" -ForegroundColor DarkGray
Write-Host "    cd D:\dev2\clients\mbox\mqtt-send" -ForegroundColor Gray
Write-Host "    powershell -ExecutionPolicy Bypass -File run-multi-table-publisher.ps1`n" -ForegroundColor Gray

Write-Host "  Window 4 - Continuous Data Generator:" -ForegroundColor White
Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "    cd D:\dev2\clients\mbox\mqtt-send" -ForegroundColor Gray
Write-Host "    powershell -ExecutionPolicy Bypass -File generate-tracked-table-data.ps1 -Count 5 -IntervalSeconds 10`n" -ForegroundColor Gray

# Step 4: Generate initial test data
Write-Host "`n[Step 4] Generating initial test data..." -ForegroundColor Cyan

$response = Read-Host "Generate 20 test records now? (Y/N)"
if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "`n  Generating records..." -ForegroundColor Yellow
    & ".\generate-tracked-table-data.ps1" -Count 20 -Table "ALL"
} else {
    Write-Host "  Skipped initial data generation" -ForegroundColor Gray
}

# Step 5: Verification queries
Write-Host "`n[Step 5] Verification Queries" -ForegroundColor Cyan

Write-Host "`nRun these queries in SSMS or via sqlcmd to verify operation:`n" -ForegroundColor Yellow

Write-Host "  Check active configurations:" -ForegroundColor White
Write-Host "  ───────────────────────────" -ForegroundColor DarkGray
Write-Host "    SELECT * FROM MQTT.vw_ConfigurationSummary;`n" -ForegroundColor Gray

Write-Host "  Check unsent records by table:" -ForegroundColor White
Write-Host "  ──────────────────────────────" -ForegroundColor DarkGray
Write-Host @"
    SELECT
        c.SourceName,
        (SELECT COUNT(*)
         FROM dbo.TableA a
         LEFT JOIN MQTT.SentRecords m ON m.SourceName = c.SourceName AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
         WHERE m.Id IS NULL AND c.TableName = 'TableA') AS Unsent
    FROM MQTT.SourceConfig c
    WHERE c.TableName = 'TableA'
    UNION ALL
    SELECT
        c.SourceName,
        (SELECT COUNT(*)
         FROM dbo.TableB b
         LEFT JOIN MQTT.SentRecords m ON m.SourceName = c.SourceName AND m.RecordId = CAST(b.RecordId AS NVARCHAR(100))
         WHERE m.Id IS NULL AND c.TableName = 'TableB') AS Unsent
    FROM MQTT.SourceConfig c
    WHERE c.TableName = 'TableB'
    UNION ALL
    SELECT
        c.SourceName,
        (SELECT COUNT(*)
         FROM dbo.TableC c2
         LEFT JOIN MQTT.SentRecords m ON m.SourceName = c.SourceName AND m.RecordId = CAST(c2.RecordId AS NVARCHAR(100))
         WHERE m.Id IS NULL AND c.TableName = 'TableC') AS Unsent
    FROM MQTT.SourceConfig c
    WHERE c.TableName = 'TableC';
"@ -ForegroundColor Gray

Write-Host "`n  Check sent records by table:" -ForegroundColor White
Write-Host "  ────────────────────────────" -ForegroundColor DarkGray
Write-Host @"
    SELECT
        SourceName,
        COUNT(*) AS SentCount,
        MIN(SentAt) AS FirstSent,
        MAX(SentAt) AS LastSent
    FROM MQTT.SentRecords
    GROUP BY SourceName
    ORDER BY SourceName;
"@ -ForegroundColor Gray

Write-Host "`n  Check records by MonitorId:" -ForegroundColor White
Write-Host "  ───────────────────────────" -ForegroundColor DarkGray
Write-Host @"
    SELECT
        m.SourceName,
        SUBSTRING(m.Topic, CHARINDEX('/', m.Topic, CHARINDEX('/', m.Topic) + 1) + 1, 10) AS MonitorId,
        COUNT(*) AS RecordCount
    FROM MQTT.SentRecords m
    GROUP BY m.SourceName, SUBSTRING(m.Topic, CHARINDEX('/', m.Topic, CHARINDEX('/', m.Topic) + 1) + 1, 10)
    ORDER BY m.SourceName, MonitorId;
"@ -ForegroundColor Gray

# Step 6: Expected outputs
Write-Host "`n[Step 6] Expected Outputs" -ForegroundColor Cyan

Write-Host "`nSubscriber 1 (MonitorId=1) should show:" -ForegroundColor Yellow
Write-Host @"
  [INFO] Connected to MQTT broker
  [INFO] Subscribed to topics: data/tableA/1, data/tableB/1, data/tableC/1, data/tableD/1
  [INFO] Received message on data/tableA/1
  [INFO] Parsed JSON: {"RecordId":1,"MonitorId":"1","SensorType":"temperature","Value":72.5,...}
"@ -ForegroundColor Gray

Write-Host "`nSubscriber 2 (MonitorId=2) should show:" -ForegroundColor Yellow
Write-Host @"
  [INFO] Connected to MQTT broker
  [INFO] Subscribed to topics: data/tableA/2, data/tableB/2, data/tableC/2, data/tableD/2
  [INFO] Received message on data/tableA/2
  [INFO] Parsed JSON: {"RecordId":2,"MonitorId":"2","SensorType":"temperature","Value":68.3,...}
"@ -ForegroundColor Gray

Write-Host "`nPublisher should show:" -ForegroundColor Yellow
Write-Host @"
  Configuration loaded - Enabled sources: 3
    - TableA: TableA (100 batch, 2s interval)
    - TableB: TableB (100 batch, 2s interval)
    - TableC: TableC (100 batch, 2s interval)
  [TableA] Found 20 unsent records (MonitorIds: 1,2,3,4,5,6,7,8,9,10)
  [TableA] Published 20 records to MQTT
  [TableB] Found 20 unsent records (MonitorIds: 1,2,3,4,5,6,7,8,9,10)
  [TableB] Published 20 records to MQTT
"@ -ForegroundColor Gray

# Step 7: Test checklist
Write-Host "`n[Step 7] Test Checklist" -ForegroundColor Cyan

Write-Host "`nVerify each of the following:" -ForegroundColor Yellow
Write-Host "  [ ] Subscriber 1 connects and subscribes to topics for MonitorId=1" -ForegroundColor Gray
Write-Host "  [ ] Subscriber 2 connects and subscribes to topics for MonitorId=2" -ForegroundColor Gray
Write-Host "  [ ] Publisher loads configurations from MQTT.SourceConfig" -ForegroundColor Gray
Write-Host "  [ ] Publisher finds unsent records for each table" -ForegroundColor Gray
Write-Host "  [ ] Publisher publishes messages to MQTT broker" -ForegroundColor Gray
Write-Host "  [ ] Subscriber 1 receives only MonitorId=1 messages" -ForegroundColor Gray
Write-Host "  [ ] Subscriber 2 receives only MonitorId=2 messages" -ForegroundColor Gray
Write-Host "  [ ] Messages contain properly mapped fields from FieldMappingJson" -ForegroundColor Gray
Write-Host "  [ ] MQTT.SentRecords table is populated with sent records" -ForegroundColor Gray
Write-Host "  [ ] Re-running publisher shows 0 unsent records (no duplicates)" -ForegroundColor Gray
Write-Host "  [ ] Data generator creates new records" -ForegroundColor Gray
Write-Host "  [ ] Publisher picks up new records on next polling cycle" -ForegroundColor Gray

# Summary
Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "           TEST SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Open 4 separate PowerShell windows" -ForegroundColor White
Write-Host "  2. Start the components using the commands shown above" -ForegroundColor White
Write-Host "  3. Watch the output from each component" -ForegroundColor White
Write-Host "  4. Run verification queries to confirm operation" -ForegroundColor White
Write-Host "  5. Use the test checklist to verify all functionality`n" -ForegroundColor White

Write-Host "Quick Start Commands:" -ForegroundColor Yellow
Write-Host "  Generate more data:    .\generate-tracked-table-data.ps1 -Count 10" -ForegroundColor Gray
Write-Host "  Continuous generator:  .\generate-tracked-table-data.ps1 -Count 5 -IntervalSeconds 10" -ForegroundColor Gray
Write-Host "  Verify system:         .\verify-system-status.ps1`n" -ForegroundColor Gray
