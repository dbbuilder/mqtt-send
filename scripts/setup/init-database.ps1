# Initialize Database Script
param([switch]$Verbose)

$ErrorActionPreference = "Stop"

Write-Host "`nInitializing Database..." -ForegroundColor Cyan

# Copy SQL files to container
Write-Host "  Copying SQL files to container..." -ForegroundColor Yellow
docker exec sqlserver mkdir -p /tmp/sql
docker cp sql/00_CreateDatabase.sql sqlserver:/tmp/sql/
docker cp sql/01_CreateMessagesTable.sql sqlserver:/tmp/sql/
docker cp sql/02_CreateStoredProcedures.sql sqlserver:/tmp/sql/
docker cp sql/03_SeedData.sql sqlserver:/tmp/sql/

$sqlScripts = @(
    "/tmp/sql/00_CreateDatabase.sql",
    "/tmp/sql/01_CreateMessagesTable.sql",
    "/tmp/sql/02_CreateStoredProcedures.sql",
    "/tmp/sql/03_SeedData.sql"
)

foreach ($script in $sqlScripts) {
    $scriptName = Split-Path -Leaf $script
    Write-Host "  Executing $scriptName..." -ForegroundColor Yellow

    # Execute using sqlcmd -i flag
    docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -C -i $script

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to execute $scriptName" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n Database initialized successfully!" -ForegroundColor Green
Write-Host "  - Database: MqttBridge" -ForegroundColor Gray
Write-Host "  - Table: Messages with indexes" -ForegroundColor Gray
Write-Host "  - Stored Procedures: 4 created" -ForegroundColor Gray
Write-Host "  - Seed Data: 11 test messages" -ForegroundColor Gray
Write-Host ""
