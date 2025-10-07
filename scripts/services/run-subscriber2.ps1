# Run Subscriber 2 (Monitor ID: 2)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Starting Subscriber 2 (Monitor Filter: 2) ===" -ForegroundColor Cyan

# Stop any existing subscriber processes
Get-Process -Name "SubscriberService" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "  Monitor Filter: 2" -ForegroundColor Gray
Write-Host "  Topic: monitor/2/messages" -ForegroundColor Gray
Write-Host ""

# Run from the subscriber directory
Push-Location "$PSScriptRoot\src\SubscriberService"

try {
    # Use command line parameters to override config
    dotnet run -- --MonitorFilter "2" --ClientIdSuffix "Monitor2"
}
finally {
    Pop-Location
}
