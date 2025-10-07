# Test Enhanced Record Parsing - Quick Start Guide

Write-Host "`n=== Testing Enhanced Record Parsing ===`n" -ForegroundColor Cyan

Write-Host "Open 4 separate terminals and run these commands:`n" -ForegroundColor Yellow

Write-Host "Terminal 1 - Subscriber Monitor 1:" -ForegroundColor Green
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run --environment Subscriber1 --no-build`n" -ForegroundColor Gray

Write-Host "Terminal 2 - Subscriber Monitor 2:" -ForegroundColor Green
Write-Host "  cd src\SubscriberService" -ForegroundColor Gray
Write-Host "  dotnet run --environment Subscriber2 --no-build`n" -ForegroundColor Gray

Write-Host "Terminal 3 - Publisher:" -ForegroundColor Green
Write-Host "  cd src\PublisherService" -ForegroundColor Gray
Write-Host "  dotnet run --no-build`n" -ForegroundColor Gray

Write-Host "Terminal 4 - Auto Generator (Enhanced Records):" -ForegroundColor Green
Write-Host "  powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1`n" -ForegroundColor Gray

Write-Host "Expected Output in Subscribers:" -ForegroundColor Cyan
Write-Host "  - You'll see '>>> PARSING COMPLETE RECORD <<<'" -ForegroundColor Gray
Write-Host "  - All 12 fields displayed individually:" -ForegroundColor Gray
Write-Host "    * Record ID, Monitor ID, Sensor Type, Value, Unit" -ForegroundColor Gray
Write-Host "    * Timestamp, Status, Location, Alert Threshold" -ForegroundColor Gray
Write-Host "    * Batch Number, Sequence Number, Data Quality" -ForegroundColor Gray
Write-Host "`n"
