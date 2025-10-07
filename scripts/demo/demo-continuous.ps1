# Continuous Demo - Complete Test with Auto-Generated Messages
# This script helps you set up a continuous test scenario

Write-Host "`n=== Continuous MQTT Demo Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo will continuously generate messages for testing." -ForegroundColor White
Write-Host ""

# Check if services are running
$pubRunning = Get-Process -Name "PublisherService" -ErrorAction SilentlyContinue
$subRunning = Get-Process -Name "SubscriberService" -ErrorAction SilentlyContinue

if (-not $pubRunning -or -not $subRunning) {
    Write-Host "⚠ Services don't appear to be running!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please start the services first:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Terminal 1 - Subscriber for Monitor 1:" -ForegroundColor White
    Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
    Write-Host "  dotnet run --environment Subscriber1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Terminal 2 - Subscriber for Monitor 2:" -ForegroundColor White
    Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
    Write-Host "  dotnet run --environment Subscriber2" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Terminal 3 - Publisher:" -ForegroundColor White
    Write-Host "  cd src\PublisherService" -ForegroundColor Gray
    Write-Host "  dotnet run" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Then run this script again in Terminal 4" -ForegroundColor White
    Write-Host ""
    exit
}

Write-Host "✓ Services are running!" -ForegroundColor Green
Write-Host ""

# Clear existing messages
Write-Host "Clearing existing messages..." -ForegroundColor Yellow
$clearSql = "DELETE FROM MqttBridge.dbo.Messages"
$clearSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1 | Out-Null
Write-Host "✓ Messages cleared" -ForegroundColor Green
Write-Host ""

# Show what will happen
Write-Host "=== Starting Continuous Demo ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Auto-generator will:" -ForegroundColor White
Write-Host "  • Generate 2 messages every 5 seconds" -ForegroundColor Gray
Write-Host "  • Alternate between Monitor 1 and Monitor 2" -ForegroundColor Gray
Write-Host "  • Send realistic sensor data (temperature, humidity, pressure, flow)" -ForegroundColor Gray
Write-Host ""
Write-Host "Watch the terminals to see:" -ForegroundColor White
Write-Host "  • Terminal 1 (Subscriber 1) - Receives Monitor 1 messages only" -ForegroundColor Gray
Write-Host "  • Terminal 2 (Subscriber 2) - Receives Monitor 2 messages only" -ForegroundColor Gray
Write-Host "  • Terminal 3 (Publisher) - Publishes all messages to MQTT" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 2

# Start auto-generator
& "$PSScriptRoot\auto-send-messages.ps1" -IntervalSeconds 5 -MessagesPerBatch 1 -MonitorIds @("1", "2")
