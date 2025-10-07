# Test Command Line Parameters
# Now uses command line params instead of environment variables

Write-Host "`n=== Testing with Command Line Parameters ===" -ForegroundColor Cyan
Write-Host "`nMuch more reliable than environment variables!`n" -ForegroundColor Green

Write-Host "Open 4 terminals and run these commands:`n" -ForegroundColor Yellow

Write-Host "Terminal 1 - Subscriber Monitor 1:" -ForegroundColor Green
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run --no-build -- --MonitorFilter `"1`" --ClientIdSuffix `"Monitor1`"`n" -ForegroundColor White

Write-Host "Terminal 2 - Subscriber Monitor 2:" -ForegroundColor Green
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run --no-build -- --MonitorFilter `"2`" --ClientIdSuffix `"Monitor2`"`n" -ForegroundColor White

Write-Host "Terminal 3 - Publisher:" -ForegroundColor Green
Write-Host "  cd src\PublisherService" -ForegroundColor Gray
Write-Host "  dotnet run --no-build`n" -ForegroundColor White

Write-Host "Terminal 4 - Auto Generator:" -ForegroundColor Green
Write-Host "  powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1`n" -ForegroundColor White

Write-Host "Or use the launcher scripts:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File run-subscriber1.ps1" -ForegroundColor Gray
Write-Host "  powershell -ExecutionPolicy Bypass -File run-subscriber2.ps1" -ForegroundColor Gray
Write-Host "  powershell -ExecutionPolicy Bypass -File run-publisher.ps1" -ForegroundColor Gray
Write-Host "  powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1" -ForegroundColor Gray

Write-Host "`nExpected Output:" -ForegroundColor Cyan
Write-Host "  Subscriber 1: Monitor Filter: 1" -ForegroundColor Gray
Write-Host "  Subscriber 2: Monitor Filter: 2" -ForegroundColor Gray
Write-Host "  Both subscribers receive and parse 12-field records" -ForegroundColor Gray
Write-Host "`n"
