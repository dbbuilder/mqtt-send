# Run Publisher Service

$ErrorActionPreference = "Stop"

Write-Host "`n=== Starting Publisher Service ===" -ForegroundColor Cyan

# Stop any existing publisher processes
Get-Process -Name "PublisherService" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "  Polling Interval: 5 seconds" -ForegroundColor Gray
Write-Host "  Batch Size: 100" -ForegroundColor Gray
Write-Host ""

# Run from the publisher directory
Push-Location "$PSScriptRoot\src\PublisherService"

try {
    dotnet run
}
finally {
    Pop-Location
}
