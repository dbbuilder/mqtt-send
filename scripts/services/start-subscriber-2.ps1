# Start Subscriber 2 (MonitorId = 2)

Write-Host "`nStarting Subscriber for MonitorId = 2..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

Push-Location src\SubscriberService

dotnet run --configuration Release --no-build -- --MonitorFilter "2" --ClientIdSuffix "Monitor2"

Pop-Location
