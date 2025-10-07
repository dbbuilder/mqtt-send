# Setup Database-Driven MQTT Bridge System
# All configuration stored in MQTT schema tables

$ErrorActionPreference = "Stop"

Write-Host "`n=== Setting Up Database-Driven MQTT Bridge System ===`n" -ForegroundColor Cyan

# Step 1: Create MQTT schema and core tables
Write-Host "Step 1: Creating MQTT schema and tables..." -ForegroundColor Yellow
Get-Content sql\SETUP_MQTT_SYSTEM.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  - Failed to create MQTT system!" -ForegroundColor Red
    exit 1
}
Write-Host "  + MQTT system created successfully`n" -ForegroundColor Green

# Step 2: Create sample tables and configurations
Write-Host "Step 2: Creating sample tables and configurations..." -ForegroundColor Yellow
Get-Content sql\SETUP_SAMPLE_TABLES.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  - Failed to create sample tables!" -ForegroundColor Red
    exit 1
}
Write-Host "  + Sample tables created successfully`n" -ForegroundColor Green

# Step 3: Verify setup
Write-Host "Step 3: Verifying setup..." -ForegroundColor Yellow

$verifySQL = "SELECT * FROM MQTT.vw_ConfigurationSummary; SELECT * FROM MQTT.vw_Metrics;"
$result = $verifySQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

Write-Host $result -ForegroundColor Gray

# Step 4: Build MultiTablePublisher
Write-Host "`nStep 4: Building MultiTablePublisher..." -ForegroundColor Yellow
Push-Location src\MultiTablePublisher
dotnet build
if ($LASTEXITCODE -ne 0) {
    Write-Host "  - Build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "  + Build successful`n" -ForegroundColor Green

Write-Host "=== Setup Complete! ===`n" -ForegroundColor Green
Write-Host "Database-Driven Configuration:" -ForegroundColor Cyan
Write-Host "  - Schema: MQTT" -ForegroundColor Gray
Write-Host "  - Config Table: MQTT.SourceConfig" -ForegroundColor Gray
Write-Host "  - Tracking Table: MQTT.SentRecords" -ForegroundColor Gray
Write-Host "  - All access via stored procedures (no dynamic SQL)`n" -ForegroundColor Gray

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Start MultiTablePublisher: .\run-multi-table-publisher.ps1" -ForegroundColor Gray
Write-Host "  2. Start Subscribers to receive messages" -ForegroundColor Gray
Write-Host "  3. Add more records: .\insert-test-records.ps1`n" -ForegroundColor Gray

Write-Host "To add new source tables:" -ForegroundColor Cyan
Write-Host "  EXEC MQTT.AddSourceConfiguration @SourceName='TableD', @TableName='TableD', ...`n" -ForegroundColor White
