# Quick Test Script - MQTT Message Bridge
# Stops services, rebuilds, and provides instructions

Write-Host "`n=== MQTT Message Bridge - Quick Test ===" -ForegroundColor Cyan

# Check if services are running
$pubProcess = Get-Process -Name "PublisherService" -ErrorAction SilentlyContinue
$subProcess = Get-Process -Name "SubscriberService" -ErrorAction SilentlyContinue

if ($pubProcess -or $subProcess) {
    Write-Host "`nStopping running services..." -ForegroundColor Yellow
    if ($pubProcess) { Stop-Process -Name "PublisherService" -Force }
    if ($subProcess) { Stop-Process -Name "SubscriberService" -Force }
    Start-Sleep -Seconds 2
}

# Rebuild both services
Write-Host "`nRebuilding services..." -ForegroundColor Yellow

Push-Location src\PublisherService
dotnet build -v q --nologo
if ($LASTEXITCODE -ne 0) {
    Write-Host "Publisher build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

Push-Location src\SubscriberService
dotnet build -v q --nologo
if ($LASTEXITCODE -ne 0) {
    Write-Host "Subscriber build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

Write-Host "`n Build successful!" -ForegroundColor Green

# Show instructions
Write-Host "`n=== Ready to Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open TWO terminal windows:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Terminal 1 - Subscriber:" -ForegroundColor White
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run" -ForegroundColor Gray
Write-Host ""
Write-Host "Terminal 2 - Publisher:" -ForegroundColor White
Write-Host "  cd src\PublisherService" -ForegroundColor Gray
Write-Host "  dotnet run" -ForegroundColor Gray
Write-Host ""
Write-Host "You should see 11 messages flow through the system!" -ForegroundColor Green
Write-Host ""
