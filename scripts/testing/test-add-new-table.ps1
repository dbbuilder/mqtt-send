# Test Script: Add or Remove TableD Dynamically
param([switch]$Reset)

$ErrorActionPreference = "Stop"

if ($Reset) {
    Write-Host ""
    Write-Host "=== Removing TableD ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Running REMOVE_TABLED.sql..." -ForegroundColor Yellow

    Get-Content sql\REMOVE_TABLED.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -C

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  OK - TableD removed successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "Publisher will auto-detect the change within 30 seconds" -ForegroundColor Yellow
        Write-Host "Watch for: Configuration change detected: 4 sources -> 3 sources" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  ERROR - Failed to remove TableD!" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    exit 0
}

# Add TableD
Write-Host ""
Write-Host "=== Adding TableD ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running ADD_TABLED.sql..." -ForegroundColor Yellow

Get-Content sql\ADD_TABLED.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -C

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  ERROR - Failed to add TableD!" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "=== Complete! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "OK - TableD created with 30 sample records" -ForegroundColor Green
Write-Host "OK - MQTT configuration added to MQTT.SourceConfig" -ForegroundColor Green
Write-Host ""
Write-Host "Publisher will auto-detect the change within 30 seconds!" -ForegroundColor Yellow
Write-Host "Watch for: Configuration change detected: 3 sources -> 4 sources" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected Publisher Output:" -ForegroundColor Yellow
Write-Host "  [WARN] Configuration change detected: 3 sources -> 4 sources" -ForegroundColor Gray
Write-Host "  [INFO] Reloading configuration..." -ForegroundColor Gray
Write-Host "  [INFO] Configuration loaded - Enabled sources: 4" -ForegroundColor Gray
Write-Host "  [INFO] [TableD] Found 30 unsent records" -ForegroundColor Green
Write-Host "  [INFO] [TableD] Published 30 records to MQTT" -ForegroundColor Green
Write-Host ""
Write-Host "To remove TableD:" -ForegroundColor Yellow
Write-Host "  powershell test-add-new-table.ps1 -Reset" -ForegroundColor Gray
Write-Host ""
