# Run Subscriber 1 (Monitor ID: 1)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Starting Subscriber 1 (Monitor Filter: 1) ===" -ForegroundColor Cyan

# Stop any existing subscriber processes
Get-Process -Name "SubscriberService" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "  Monitor Filter: 1" -ForegroundColor Gray
Write-Host "  Topic: monitor/1/messages" -ForegroundColor Gray
Write-Host ""

# Run from the subscriber directory
Push-Location "$PSScriptRoot\src\SubscriberService"

try {
    # Use command line parameters to override config
    dotnet run -- --MonitorFilter "1" --ClientIdSuffix "Monitor1"
}
finally {
    Pop-Location
}
