# Setup Multi-Table MQTT Bridge System
# Initializes tracking table and source tables with sample data

$ErrorActionPreference = "Stop"

Write-Host "`n=== Setting Up Multi-Table MQTT Bridge System ===`n" -ForegroundColor Cyan

# Step 1: Create tracking table
Write-Host "Step 1: Creating tracking table..." -ForegroundColor Yellow
Get-Content sql\01_CreateTrackingTable.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  - Failed to create tracking table!" -ForegroundColor Red
    exit 1
}
Write-Host "  + Tracking table created successfully`n" -ForegroundColor Green

# Step 2: Create source tables (A, B, C) with sample data
Write-Host "Step 2: Creating source tables A, B, C with sample data..." -ForegroundColor Yellow
Get-Content sql\02_CreateSourceTables.sql -Raw | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  - Failed to create source tables!" -ForegroundColor Red
    exit 1
}
Write-Host "  + Source tables created successfully`n" -ForegroundColor Green

# Step 3: Verify setup
Write-Host "Step 3: Verifying setup..." -ForegroundColor Yellow

$verifySQL = @"
SELECT 'TableA' AS TableName, COUNT(*) AS RecordCount FROM dbo.TableA
UNION ALL
SELECT 'TableB', COUNT(*) FROM dbo.TableB
UNION ALL
SELECT 'TableC', COUNT(*) FROM dbo.TableC
UNION ALL
SELECT 'MqttSentRecords', COUNT(*) FROM dbo.MqttSentRecords;
"@

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
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review configuration: config\source-tables-local.json" -ForegroundColor Gray
Write-Host "  2. Start MultiTablePublisher: .\run-multi-table-publisher.ps1" -ForegroundColor Gray
Write-Host "  3. Start Subscribers to receive messages" -ForegroundColor Gray
Write-Host "  4. Add more records to TableA/B/C to see them published`n" -ForegroundColor Gray

Write-Host "Test adding more records:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File insert-test-records.ps1`n" -ForegroundColor White
