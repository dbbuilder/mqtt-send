# Run Filtered Subscriber Test
# Starts Publisher and two Subscribers (one for Monitor 1, one for Monitor 2)

Write-Host "`n=== Starting Filtered Subscriber Test ===" -ForegroundColor Cyan

# Stop any running services first
Write-Host "`nStopping any running services..." -ForegroundColor Yellow
$pubProcess = Get-Process -Name "PublisherService" -ErrorAction SilentlyContinue
$subProcess = Get-Process -Name "SubscriberService" -ErrorAction SilentlyContinue

if ($pubProcess -or $subProcess) {
    if ($pubProcess) { Stop-Process -Name "PublisherService" -Force }
    if ($subProcess) { Stop-Process -Name "SubscriberService" -Force }
    Start-Sleep -Seconds 2
    Write-Host " Services stopped" -ForegroundColor Green
}

# Check if data is ready
Write-Host "`nChecking test data..." -ForegroundColor Yellow

$checkSql = @"
SELECT
    MonitorId,
    COUNT(*) as MessageCount,
    SUM(CASE WHEN Status = 'Pending' THEN 1 ELSE 0 END) as PendingCount
FROM MqttBridge.dbo.Messages
WHERE MonitorId IN ('1', '2')
GROUP BY MonitorId
ORDER BY MonitorId
"@

$dataCheck = $checkSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1

if ($dataCheck -notmatch "1" -or $dataCheck -notmatch "2") {
    Write-Host " No test data found!" -ForegroundColor Red
    Write-Host " Run: powershell -ExecutionPolicy Bypass -File setup-filtered-test.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host " Test data ready!" -ForegroundColor Green

# Instructions
Write-Host "`n=== Open THREE Terminal Windows ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Terminal 1 - Subscriber for Monitor 1:" -ForegroundColor Yellow
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run --environment Subscriber1" -ForegroundColor White
Write-Host "  (Will receive only Monitor 1 messages - 5 messages)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Terminal 2 - Subscriber for Monitor 2:" -ForegroundColor Yellow
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run --environment Subscriber2" -ForegroundColor White
Write-Host "  (Will receive only Monitor 2 messages - 5 messages)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Terminal 3 - Publisher:" -ForegroundColor Yellow
Write-Host "  cd src\PublisherService" -ForegroundColor Gray
Write-Host "  dotnet run" -ForegroundColor White
Write-Host "  (Will publish all 10 messages to MQTT)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "=== Expected Results ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Subscriber 1 Terminal:" -ForegroundColor Yellow
Write-Host "  - Will show 5 messages" -ForegroundColor Gray
Write-Host "  - All with MonitorId: 1" -ForegroundColor Gray
Write-Host "  - Topics: monitor/1/messages" -ForegroundColor Gray
Write-Host "  - Content: temperature & humidity data" -ForegroundColor Gray
Write-Host ""
Write-Host "Subscriber 2 Terminal:" -ForegroundColor Yellow
Write-Host "  - Will show 5 messages" -ForegroundColor Gray
Write-Host "  - All with MonitorId: 2" -ForegroundColor Gray
Write-Host "  - Topics: monitor/2/messages" -ForegroundColor Gray
Write-Host "  - Content: pressure & flow data" -ForegroundColor Gray
Write-Host ""
Write-Host "Publisher Terminal:" -ForegroundColor Yellow
Write-Host "  - Will publish all 10 messages" -ForegroundColor Gray
Write-Host "  - Batch complete - Success: 10, Failures: 0" -ForegroundColor Gray
Write-Host ""
Write-Host "This proves MQTT topic filtering works perfectly!" -ForegroundColor Green
Write-Host "Each subscriber receives ONLY the messages for their MonitorId!" -ForegroundColor Green
Write-Host ""
