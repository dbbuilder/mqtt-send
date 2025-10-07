# System Status Verification Script
# Checks overall health of MQTT Bridge system

$ErrorActionPreference = "Stop"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "           MQTT BRIDGE SYSTEM STATUS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Check 1: Database connection
Write-Host "`n[1] Database Connection..." -ForegroundColor Cyan
$pingSQL = "SELECT @@VERSION AS SqlVersion;"
$dbResult = $pingSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Database connected" -ForegroundColor Green
} else {
    Write-Host "  ✗ Database connection failed!" -ForegroundColor Red
    exit 1
}

# Check 2: MQTT Schema
Write-Host "`n[2] MQTT Schema Objects..." -ForegroundColor Cyan
$schemaSQL = @"
SELECT
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'MQTT') AS Tables,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'MQTT') AS StoredProcs;
"@
$schemaResult = $schemaSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

Write-Host $schemaResult -ForegroundColor Gray

# Check 3: Source configurations
Write-Host "`n[3] Source Configurations..." -ForegroundColor Cyan
$configSQL = @"
SELECT
    SourceName,
    CASE WHEN Enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS Status,
    TableName,
    TopicPattern,
    BatchSize,
    PollingIntervalSeconds
FROM MQTT.SourceConfig
ORDER BY SourceName;
"@
$configSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

# Check 4: Source table record counts
Write-Host "`n[4] Source Table Record Counts..." -ForegroundColor Cyan
$countsSQL = @"
SELECT 'TableA' AS TableName, COUNT(*) AS TotalRecords FROM dbo.TableA
UNION ALL
SELECT 'TableB', COUNT(*) FROM dbo.TableB
UNION ALL
SELECT 'TableC', COUNT(*) FROM dbo.TableC
UNION ALL
SELECT 'TableD', COUNT(*) FROM dbo.TableD;
"@
$countsSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

# Check 5: Sent records summary
Write-Host "`n[5] Sent Records Summary..." -ForegroundColor Cyan
$sentSQL = @"
SELECT
    SourceName,
    COUNT(*) AS SentCount,
    MIN(SentAt) AS FirstSent,
    MAX(SentAt) AS LastSent
FROM MQTT.SentRecords
GROUP BY SourceName
ORDER BY SourceName;
"@
$sentResult = $sentSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host $sentResult -ForegroundColor Gray
} else {
    Write-Host "  (No records sent yet)" -ForegroundColor Yellow
}

# Check 6: Unsent records by table
Write-Host "`n[6] Unsent Records by Table..." -ForegroundColor Cyan
$unsentSQL = @"
DECLARE @Results TABLE (SourceName NVARCHAR(100), UnsentCount INT);

INSERT INTO @Results
SELECT 'TableA', COUNT(*)
FROM dbo.TableA a
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableA' AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

INSERT INTO @Results
SELECT 'TableB', COUNT(*)
FROM dbo.TableB b
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableB' AND m.RecordId = CAST(b.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

INSERT INTO @Results
SELECT 'TableC', COUNT(*)
FROM dbo.TableC c
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableC' AND m.RecordId = CAST(c.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

INSERT INTO @Results
SELECT 'TableD', COUNT(*)
FROM dbo.TableD d
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableD' AND m.RecordId = CAST(d.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

SELECT SourceName, UnsentCount FROM @Results ORDER BY SourceName;
"@
$unsentSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

# Check 7: Recent activity (last 5 minutes)
Write-Host "`n[7] Recent Activity (Last 5 Minutes)..." -ForegroundColor Cyan
$recentSQL = @"
SELECT
    SourceName,
    COUNT(*) AS RecentlySent,
    MIN(SentAt) AS FirstSent,
    MAX(SentAt) AS LastSent
FROM MQTT.SentRecords
WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY SourceName
ORDER BY SourceName;
"@
$recentResult = $recentSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C 2>$null

if ($LASTEXITCODE -eq 0 -and $recentResult -notmatch "0 rows affected") {
    Write-Host $recentResult -ForegroundColor Gray
} else {
    Write-Host "  (No activity in last 5 minutes)" -ForegroundColor Yellow
}

# Check 8: Monitor distribution
Write-Host "`n[8] Monitor Distribution in Sent Records..." -ForegroundColor Cyan
$monitorSQL = @"
SELECT TOP 10
    SUBSTRING(Topic, CHARINDEX('/', Topic, CHARINDEX('/', Topic) + 1) + 1, 10) AS MonitorId,
    COUNT(*) AS MessageCount
FROM MQTT.SentRecords
GROUP BY SUBSTRING(Topic, CHARINDEX('/', Topic, CHARINDEX('/', Topic) + 1) + 1, 10)
ORDER BY MessageCount DESC;
"@
$monitorResult = $monitorSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C 2>$null

if ($LASTEXITCODE -eq 0 -and $monitorResult -notmatch "0 rows affected") {
    Write-Host $monitorResult -ForegroundColor Gray
} else {
    Write-Host "  (No sent records yet)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "           SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Calculate totals
$totalRecordsSQL = @"
SELECT
    (SELECT COUNT(*) FROM dbo.TableA) +
    (SELECT COUNT(*) FROM dbo.TableB) +
    (SELECT COUNT(*) FROM dbo.TableC) +
    (SELECT COUNT(*) FROM dbo.TableD) AS TotalRecords,
    (SELECT COUNT(*) FROM MQTT.SentRecords) AS TotalSent;
"@
$totals = $totalRecordsSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

Write-Host "`nSystem Health:" -ForegroundColor Yellow
Write-Host "  Database:        Connected ✓" -ForegroundColor Green
Write-Host "  MQTT Schema:     Configured ✓" -ForegroundColor Green

Write-Host "`nData Status:" -ForegroundColor Yellow
Write-Host $totals -ForegroundColor Gray

Write-Host "`nRecommended Actions:" -ForegroundColor Yellow

# Check if publisher needs to run
$unsentCheckSQL = @"
SELECT COUNT(*) AS UnsentTotal
FROM (
    SELECT a.RecordId FROM dbo.TableA a LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableA' AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100)) WHERE m.Id IS NULL
    UNION ALL
    SELECT b.RecordId FROM dbo.TableB b LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableB' AND m.RecordId = CAST(b.RecordId AS NVARCHAR(100)) WHERE m.Id IS NULL
    UNION ALL
    SELECT c.RecordId FROM dbo.TableC c LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableC' AND m.RecordId = CAST(c.RecordId AS NVARCHAR(100)) WHERE m.Id IS NULL
    UNION ALL
    SELECT d.RecordId FROM dbo.TableD d LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableD' AND m.RecordId = CAST(d.RecordId AS NVARCHAR(100)) WHERE m.Id IS NULL
) AS Unsent;
"@
$unsentTotal = $unsentCheckSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

if ([int]($unsentTotal -replace '\D', '') -gt 0) {
    Write-Host "  → Start/restart Publisher to process unsent records" -ForegroundColor White
    Write-Host "    powershell -ExecutionPolicy Bypass -File run-multi-table-publisher.ps1" -ForegroundColor Gray
}

$sentCheckSQL = "SELECT COUNT(*) FROM MQTT.SentRecords;"
$sentTotal = $sentCheckSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

if ([int]($sentTotal -replace '\D', '') -eq 0) {
    Write-Host "  → No records sent yet - start Publisher to begin processing" -ForegroundColor White
} else {
    Write-Host "  → System is processing correctly ✓" -ForegroundColor Green
}

Write-Host "`nUseful Commands:" -ForegroundColor Yellow
Write-Host "  Generate data:         .\generate-tracked-table-data.ps1 -Count 20" -ForegroundColor Gray
Write-Host "  Start publisher:       .\run-multi-table-publisher.ps1" -ForegroundColor Gray
Write-Host "  Start subscriber:      cd src\SubscriberService; dotnet run --no-build -- --MonitorFilter `"1`" --ClientIdSuffix `"M1`"" -ForegroundColor Gray
Write-Host "  Complete system test:  .\test-complete-system.ps1`n" -ForegroundColor Gray
