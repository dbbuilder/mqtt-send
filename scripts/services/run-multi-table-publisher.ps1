# Run Multi-Table Publisher

$ErrorActionPreference = "Stop"

Write-Host "`n=== Starting Multi-Table MQTT Publisher ===`n" -ForegroundColor Cyan

# Stop any existing instances
Get-Process -Name "MultiTablePublisher" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "Configuration: config\source-tables-local.json" -ForegroundColor Gray
Write-Host "Enabled tables:" -ForegroundColor Gray

# Show enabled tables from config
$config = Get-Content config\source-tables-local.json -Raw | ConvertFrom-Json
foreach ($source in $config.sources | Where-Object { $_.enabled }) {
    Write-Host "  - $($source.name): $($source.description)" -ForegroundColor Gray
}

Write-Host "`nStarting publisher...`n" -ForegroundColor Yellow

Push-Location src\MultiTablePublisher

try {
    dotnet run --configuration Release --no-build
}
finally {
    Pop-Location
}
