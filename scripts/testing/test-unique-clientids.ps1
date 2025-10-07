# Test Unique ClientIds
# This script verifies that each service has a unique MQTT ClientId

Write-Host "`n=== Testing Unique ClientIds ===" -ForegroundColor Cyan
Write-Host "`nThis will verify that:" -ForegroundColor Yellow
Write-Host "  1. Publisher has unique ClientId (PublisherService-{ProcessId})" -ForegroundColor Gray
Write-Host "  2. Subscriber 1 has unique ClientId (SubscriberService-Monitor1-{ProcessId})" -ForegroundColor Gray
Write-Host "  3. Subscriber 2 has unique ClientId (SubscriberService-Monitor2-{ProcessId})" -ForegroundColor Gray
Write-Host "  4. All subscribers stay connected without disconnections`n" -ForegroundColor Gray

Write-Host "Open 4 terminals and run these commands:`n" -ForegroundColor Cyan

Write-Host "Terminal 1 - Subscriber Monitor 1:" -ForegroundColor Green
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  `$env:ASPNETCORE_ENVIRONMENT=`"Subscriber1`"" -ForegroundColor Gray
Write-Host "  dotnet run --no-build`n" -ForegroundColor Gray

Write-Host "Terminal 2 - Subscriber Monitor 2:" -ForegroundColor Green
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  `$env:ASPNETCORE_ENVIRONMENT=`"Subscriber2`"" -ForegroundColor Gray
Write-Host "  dotnet run --no-build`n" -ForegroundColor Gray

Write-Host "Terminal 3 - Publisher:" -ForegroundColor Green
Write-Host "  cd src\PublisherService" -ForegroundColor Gray
Write-Host "  dotnet run --no-build`n" -ForegroundColor Gray

Write-Host "Terminal 4 - Auto Generator:" -ForegroundColor Green
Write-Host "  powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1`n" -ForegroundColor Gray

Write-Host "Expected Output:" -ForegroundColor Cyan
Write-Host "  - Each service should log its unique MQTT ClientId on startup" -ForegroundColor Gray
Write-Host "  - Look for 'MQTT ClientId: ' in the logs" -ForegroundColor Gray
Write-Host "  - All subscribers should stay connected (no 'NormalDisconnection' messages)" -ForegroundColor Gray
Write-Host "  - Subscriber 1 receives only Monitor 1 messages" -ForegroundColor Gray
Write-Host "  - Subscriber 2 receives only Monitor 2 messages" -ForegroundColor Gray
Write-Host "`n"
