# Initialize MQTT Receiver Demo
# Sets up database schema and loads demo configuration

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "MQTT Receiver Demo - Initialization" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Initialize receiver schema
Write-Host "Step 1: Creating receiver database schema..." -ForegroundColor Yellow
Get-Content sql\INIT_RECEIVER_SCHEMA.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -C

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create receiver schema" -ForegroundColor Red
    exit 1
}

Write-Host "  OK - Receiver schema created" -ForegroundColor Green
Write-Host ""

# Step 2: Load demo configuration
Write-Host "Step 2: Loading demo configuration..." -ForegroundColor Yellow
Get-Content sql\RECEIVER_DEMO_CONFIG.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -C

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to load demo configuration" -ForegroundColor Red
    exit 1
}

Write-Host "  OK - Demo configuration loaded" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "=====================================" -ForegroundColor Green
Write-Host "INITIALIZATION COMPLETE" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Demo Configuration Summary:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configured Topics:" -ForegroundColor Yellow
Write-Host "  1. sensor/+/temperature  →  3 tables (Raw, Alerts, Aggregates)" -ForegroundColor Gray
Write-Host "  2. sensor/+/pressure     →  1 table  (Raw)" -ForegroundColor Gray
Write-Host ""
Write-Host "Table Mappings:" -ForegroundColor Yellow
Write-Host "  - dbo.RawSensorData      (all sensor readings)" -ForegroundColor Gray
Write-Host "  - dbo.SensorAlerts       (high temperature alerts)" -ForegroundColor Gray
Write-Host "  - dbo.SensorAggregates   (hourly aggregations)" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\run-receiver.ps1" -ForegroundColor White
Write-Host "  2. Test: .\test-send-mqtt-message.ps1" -ForegroundColor White
Write-Host ""
