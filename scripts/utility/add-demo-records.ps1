# Add Demo Records for Testing
# Adds Monitor 1 and Monitor 2 records to all tables

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Adding Demo Records ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running ADD_DEMO_RECORDS.sql..." -ForegroundColor Yellow

Get-Content sql\ADD_DEMO_RECORDS.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -C

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "  OK - Demo records added successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Records added:" -ForegroundColor Yellow
    Write-Host "  - TableA: 2 records (Monitor 1 and Monitor 2)" -ForegroundColor Gray
    Write-Host "  - TableB: 2 records (Monitor 1 and Monitor 2)" -ForegroundColor Gray
    Write-Host "  - TableC: 2 records (Monitor 1 and Monitor 2)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Publisher will process within 2 seconds!" -ForegroundColor Yellow
    Write-Host "  - Subscriber 1 will receive 3 Monitor 1 records" -ForegroundColor Green
    Write-Host "  - Subscriber 2 will receive 3 Monitor 2 records" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  ERROR - Failed to add demo records!" -ForegroundColor Red
    Write-Host ""
    exit 1
}
