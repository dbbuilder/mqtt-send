# MQTT Message Bridge - Complete Setup and Test Script
# This script sets up and tests the complete MQTT message bridge system

param(
    [switch]$SkipDocker,
    [switch]$SkipBuild,
    [switch]$WaitForInput
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MQTT Message Bridge - Setup & Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Start Docker services
if (-not $SkipDocker) {
    Write-Host "[Step 1] Starting Docker services..." -ForegroundColor Yellow

    Push-Location docker
    docker-compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to start Docker services. Is Docker Desktop running?" -ForegroundColor Red
        exit 1
    }
    Pop-Location

    Write-Host "Waiting for SQL Server to be ready (30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    Write-Host "✓ Docker services started" -ForegroundColor Green
}

# Step 2: Initialize database
Write-Host "`n[Step 2] Initializing database..." -ForegroundColor Yellow

$sqlScripts = @(
    "sql\00_CreateDatabase.sql",
    "sql\01_CreateMessagesTable.sql",
    "sql\02_CreateStoredProcedures.sql",
    "sql\03_SeedData.sql"
)

foreach ($script in $sqlScripts) {
    Write-Host "  Executing $script..." -ForegroundColor Gray

    # Read the SQL file content
    $sqlContent = Get-Content $script -Raw

    # Execute using docker exec
    $sqlContent | docker exec -i sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -b

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to execute $script" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✓ Database initialized with seed data" -ForegroundColor Green

# Step 3: Build Publisher Service
if (-not $SkipBuild) {
    Write-Host "`n[Step 3] Building Publisher Service..." -ForegroundColor Yellow

    Push-Location src\PublisherService
    dotnet restore
    dotnet build --configuration Debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to build Publisher Service" -ForegroundColor Red
        exit 1
    }
    Pop-Location

    Write-Host "✓ Publisher Service built" -ForegroundColor Green
}

# Step 4: Build Subscriber Service
if (-not $SkipBuild) {
    Write-Host "`n[Step 4] Building Subscriber Service..." -ForegroundColor Yellow

    Push-Location src\SubscriberService
    dotnet restore
    dotnet build --configuration Debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to build Subscriber Service" -ForegroundColor Red
        exit 1
    }
    Pop-Location

    Write-Host "✓ Subscriber Service built" -ForegroundColor Green
}

# Display instructions
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete! Ready to Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Open Terminal 1 and run:" -ForegroundColor White
Write-Host "     cd src\SubscriberService" -ForegroundColor Gray
Write-Host "     dotnet run --environment Development" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Open Terminal 2 and run:" -ForegroundColor White
Write-Host "     cd src\PublisherService" -ForegroundColor Gray
Write-Host "     dotnet run --environment Development" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Watch messages flow from SQL → MQTT → Subscriber!" -ForegroundColor White
Write-Host ""
Write-Host "Expected Results:" -ForegroundColor Yellow
Write-Host "  ✓ 11 seed messages published" -ForegroundColor Green
Write-Host "  ✓ Subscriber receives all messages" -ForegroundColor Green
Write-Host "  ✓ Database shows Status='Published'" -ForegroundColor Green
Write-Host ""
Write-Host "See TESTING_GUIDE.md for detailed testing instructions" -ForegroundColor Cyan
Write-Host ""
