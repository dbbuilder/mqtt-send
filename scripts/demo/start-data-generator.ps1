# Start Continuous Data Generator
# Generates records for all tracked tables every 10 seconds

Write-Host "`nStarting Continuous Data Generator..." -ForegroundColor Cyan
Write-Host "Generates 5 records per table every 10 seconds" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

& ".\generate-data-simple.ps1" -Count 5 -IntervalSeconds 10
