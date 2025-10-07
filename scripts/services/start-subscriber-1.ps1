# Start Subscriber 1 (MonitorId = 1)

Write-Host "`nStarting Subscriber for MonitorId = 1..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

Push-Location src\SubscriberService

dotnet run --configuration Release --no-build -- --MonitorFilter "1" --ClientIdSuffix "Monitor1"

Pop-Location
