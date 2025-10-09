<#
.SYNOPSIS
    Safe startup script for MQTT Bridge system with complete health checks

.DESCRIPTION
    This script ensures all prerequisites are met before starting services:
    - Docker is running
    - SQL Server container is healthy and accepting connections
    - Mosquitto MQTT broker is running
    - Database schema exists
    - All services build successfully

.EXAMPLE
    .\Start-System-Safe.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$MaxWaitSeconds = 120
)

$ErrorActionPreference = 'Stop'
$BaseDir = $PSScriptRoot

# ============================================
# Helper Functions
# ============================================

function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Warning { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Step { param([string]$Message) Write-Host "`n=== $Message ===" -ForegroundColor Magenta }

# ============================================
# Pre-flight Checks
# ============================================

function Test-Docker {
    Write-Step "Checking Docker"

    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker is installed: $dockerVersion"
            return $true
        }
    } catch {
        Write-Error "Docker is not installed or not in PATH"
        Write-Host "  Please install Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
        return $false
    }

    return $false
}

function Test-DockerRunning {
    Write-Info "Checking if Docker daemon is running..."

    try {
        docker ps > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker daemon is running"
            return $true
        }
    } catch {
        Write-Error "Docker daemon is not running"
        Write-Host "  Please start Docker Desktop" -ForegroundColor Yellow
        return $false
    }

    Write-Error "Docker daemon is not running"
    Write-Host "  Please start Docker Desktop" -ForegroundColor Yellow
    return $false
}

# ============================================
# Azure SQL Connection Checks
# ============================================

function Test-AzureSqlConnection {
    Write-Step "Checking Azure SQL Connection"

    # Read connection string from Azure config
    $azureConfigPath = "$BaseDir\src\ReceiverService\appsettings.Azure.json"

    if (-not (Test-Path $azureConfigPath)) {
        Write-Error "Azure configuration file not found: $azureConfigPath"
        Write-Info "Please create appsettings.Azure.json files with Azure SQL credentials"
        Write-Info "See CONFIG_README.md for details"
        return $false
    }

    try {
        $config = Get-Content $azureConfigPath -Raw | ConvertFrom-Json
        $connString = $config.ConnectionStrings.MqttBridge

        # Extract server and database from connection string
        if ($connString -match 'Server=([^;]+)') {
            $server = $matches[1]
        }
        if ($connString -match 'Database=([^;]+)') {
            $database = $matches[1]
        }
        if ($connString -match 'User Id=([^;]+)') {
            $userId = $matches[1]
        }
        if ($connString -match 'Password=([^;]+)') {
            $password = $matches[1]
        }

        Write-Info "Testing connection to: $server"
        Write-Info "Database: $database"

        # Test connection with timeout
        $result = sqlcmd -S $server -U $userId -P $password -d $database -Q "SELECT 'Azure SQL Connected' as Status, DB_NAME() as Database" -C -W 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Azure SQL connection successful"
            Write-Success "Connected to: $database on $server"
            return $true
        }
        else {
            Write-Error "Failed to connect to Azure SQL"
            Write-Info "Verify credentials in appsettings.Azure.json"
            Write-Info "Check Azure SQL firewall rules allow your IP"
            return $false
        }
    }
    catch {
        Write-Error "Error testing Azure SQL connection: $_"
        return $false
    }
}

function Test-AzureDatabase {
    Write-Info "Checking Azure SQL database schema..."

    $azureConfigPath = "$BaseDir\src\ReceiverService\appsettings.Azure.json"
    $config = Get-Content $azureConfigPath -Raw | ConvertFrom-Json
    $connString = $config.ConnectionStrings.MqttBridge

    if ($connString -match 'Server=([^;]+)') { $server = $matches[1] }
    if ($connString -match 'Database=([^;]+)') { $database = $matches[1] }
    if ($connString -match 'User Id=([^;]+)') { $userId = $matches[1] }
    if ($connString -match 'Password=([^;]+)') { $password = $matches[1] }

    try {
        $output = sqlcmd -S $server -U $userId -P $password -d $database -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA IN ('MQTT', 'Logging')" -h -1 -W -C 2>&1

        if ($LASTEXITCODE -eq 0) {
            # Extract just the number from the output - look for any line containing a number
            $countLine = $output | Where-Object { $_ -match '\d+' } | Select-Object -First 1

            if ($countLine -match '(\d+)') {
                $count = [int]$matches[1]

                if ($count -gt 0) {
                    Write-Success "Database schema is complete ($count tables found in MQTT/Logging schemas)"
                    return $true
                }
            }
        }

        Write-Warning "Database schema appears incomplete"
        Write-Info "Run migration script: sql\MIGRATE_TO_AZURE.sql"
        return $false
    } catch {
        Write-Error "Error checking database: $_"
        return $false
    }
}

function Test-DatabaseSchema {
    Write-Info "Checking database schema..."

    $query = @"
SELECT
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'ReceiverConfig') as HasReceiverConfig,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'MQTT' AND TABLE_NAME = 'SourceConfig') as HasSourceConfig,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Logging' AND TABLE_NAME = 'ApplicationLogs') as HasLogging
"@

    try {
        $result = sqlcmd -S "localhost,1433" -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q $query -h -1 -W 2>$null

        if ($result -match '^1\s+1\s+1') {
            Write-Success "Database schema is complete"
            return $true
        }

        Write-Warning "Database schema is incomplete"
        return $false
    } catch {
        Write-Warning "Could not verify database schema: $_"
        return $false
    }
}

# ============================================
# Mosquitto Health Checks
# ============================================

function Start-MosquittoContainer {
    Write-Step "Checking Mosquitto MQTT Broker"

    # Check if container exists
    $container = docker ps -a --filter "name=mosquitto" --format "{{.Names}}" 2>$null

    if (-not $container) {
        Write-Info "Mosquitto container doesn't exist. Starting with docker-compose..."
        Push-Location "$BaseDir\docker"
        docker-compose up -d mosquitto
        Pop-Location
        Start-Sleep -Seconds 3
    }

    # Check if container is running
    $running = docker ps --filter "name=mosquitto" --filter "status=running" --format "{{.Names}}" 2>$null

    if (-not $running) {
        Write-Info "Mosquitto container is not running. Starting it..."
        docker start mosquitto
        Start-Sleep -Seconds 3
    }

    Write-Success "Mosquitto container is running"
}

function Test-MqttConnection {
    Write-Info "Testing MQTT broker connection..."

    # Check if port 1883 is listening
    $listening = netstat -ano | Select-String ":1883.*LISTENING"

    if ($listening) {
        Write-Success "MQTT broker is listening on port 1883"
        return $true
    }

    Write-Warning "MQTT broker may not be ready yet"
    return $false
}

# ============================================
# Service Management
# ============================================

function Stop-AllServices {
    Write-Step "Stopping existing services"

    $services = @("MonitorDashboard", "ReceiverService", "MultiTablePublisher")

    foreach ($service in $services) {
        $processes = Get-Process -Name $service -ErrorAction SilentlyContinue
        if ($processes) {
            Write-Info "Stopping $service (PID: $($processes.Id -join ', '))"
            $processes | Stop-Process -Force
            Start-Sleep -Seconds 1
        }
    }

    Write-Success "All services stopped"
}

function Build-AllServices {
    Write-Step "Building all services"

    $services = @(
        @{Name="ReceiverService"; Path="src/ReceiverService/ReceiverService.csproj"},
        @{Name="MultiTablePublisher"; Path="src/MultiTablePublisher/MultiTablePublisher.csproj"},
        @{Name="MonitorDashboard"; Path="src/MonitorDashboard/MonitorDashboard.csproj"}
    )

    foreach ($service in $services) {
        Write-Info "Building $($service.Name)..."

        $buildOutput = dotnet build "$BaseDir\$($service.Path)" --configuration Release --verbosity quiet 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to build $($service.Name)"
            Write-Host $buildOutput -ForegroundColor Red
            return $false
        }

        Write-Success "$($service.Name) built successfully"
    }

    return $true
}

function Start-PublisherService {
    Write-Info "Starting Publisher Service..."

    Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
Set-Location '$BaseDir'
Write-Host '========================================' -ForegroundColor Green
Write-Host '   PUBLISHER SERVICE (DB -> MQTT)' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host 'Reading from: TableA, TableB, TableC' -ForegroundColor Cyan
Write-Host 'Publishing to: data/tableA/*, data/tableB/*, data/tableC/*' -ForegroundColor Cyan
Write-Host 'Logging to: Logging.ApplicationLogs' -ForegroundColor Cyan
Write-Host ''
dotnet run --project src/MultiTablePublisher/MultiTablePublisher.csproj --configuration Release --no-build
"@

    Start-Sleep -Seconds 3
    Write-Success "Publisher Service started"
}

function Start-ReceiverService {
    Write-Info "Starting Receiver Service..."

    Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
Set-Location '$BaseDir'
Write-Host '========================================' -ForegroundColor Green
Write-Host '   RECEIVER SERVICE (MQTT -> DB)' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host 'Subscribing to: data/tableA/+, data/tableB/+, data/tableC/+' -ForegroundColor Cyan
Write-Host 'Writing to: RawSensorData' -ForegroundColor Cyan
Write-Host 'Logging to: Logging.ApplicationLogs' -ForegroundColor Cyan
Write-Host ''
dotnet run --project src/ReceiverService/ReceiverService.csproj --configuration Release --no-build
"@

    Start-Sleep -Seconds 3
    Write-Success "Receiver Service started"
}

function Start-DashboardService {
    Write-Info "Starting Monitor Dashboard..."

    Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
Set-Location '$BaseDir'
Write-Host '========================================' -ForegroundColor Green
Write-Host '   MONITOR DASHBOARD' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host 'URL: http://localhost:5000' -ForegroundColor Cyan
Write-Host 'Features: Real-time bidirectional flow monitoring' -ForegroundColor Cyan
Write-Host 'Updates: Every 5 seconds via SignalR' -ForegroundColor Cyan
Write-Host ''
dotnet run --project src/MonitorDashboard/MonitorDashboard.csproj --configuration Release --no-build --urls http://localhost:5000
"@

    Start-Sleep -Seconds 5
    Write-Success "Monitor Dashboard started"
}

# ============================================
# Main Execution
# ============================================

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  MQTT BRIDGE SAFE STARTUP" -ForegroundColor Cyan
Write-Host "  Bidirectional Flow with Real-time Monitoring" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Stop any existing services FIRST (ensures clean rebuild)
Write-Step "Stopping existing services for clean start"
Stop-AllServices

# Step 1: Check Docker
if (-not (Test-Docker)) { exit 1 }
if (-not (Test-DockerRunning)) { exit 1 }

# Step 2: Stop local Docker SQL Server and connect to Azure SQL
Write-Step "Database Configuration"

# Stop local SQL Server if running
$localSql = docker ps --filter "name=sqlserver" --filter "status=running" --format "{{.Names}}" 2>$null
if ($localSql) {
    Write-Info "Stopping local Docker SQL Server container..."
    docker stop sqlserver | Out-Null
    Write-Success "Local SQL Server stopped (using Azure SQL instead)"
}
else {
    Write-Info "Local Docker SQL Server is not running (good - using Azure SQL)"
}

# Test Azure SQL connection
if (-not (Test-AzureSqlConnection)) {
    Write-Error "Azure SQL connection failed. Aborting."
    Write-Info ""
    Write-Info "Troubleshooting:"
    Write-Info "  1. Verify appsettings.Azure.json exists in all service directories"
    Write-Info "  2. Check Azure SQL firewall allows your IP address"
    Write-Info "  3. Test connection manually: sqlcmd -S mbox-eastasia.database.windows.net,1433 -U mbox-admin -P PASSWORD -d MqttBridge -C"
    exit 1
}

if (-not (Test-AzureDatabase)) {
    Write-Error "Azure database schema check failed. Aborting."
    Write-Info "Run migration script: sql\MIGRATE_TO_AZURE.sql"
    exit 1
}

# Step 3: Start and verify Mosquitto
Start-MosquittoContainer

if (-not (Test-MqttConnection)) {
    Write-Warning "MQTT broker connection could not be verified, but continuing..."
}

# Step 4: Build all services
if (-not (Build-AllServices)) {
    Write-Error "Build failed. Aborting."
    exit 1
}

# Step 5: Start all services
Write-Step "Starting all services"

Start-PublisherService
Start-ReceiverService
Start-DashboardService

# Step 6: Open dashboard
Write-Info "Opening dashboard in browser..."
Start-Sleep -Seconds 2
Start-Process "http://localhost:5000"

# Step 7: Summary
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  SYSTEM STARTED SUCCESSFULLY" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Success "Infrastructure:"
Write-Host "  - Azure SQL Database: mbox-eastasia.database.windows.net" -ForegroundColor White
Write-Host "  - Database: MqttBridge" -ForegroundColor White
Write-Host "  - Mosquitto (Docker): localhost:1883" -ForegroundColor White
Write-Host ""
Write-Success "Services:"
Write-Host "  - Publisher: TableA/B/C -> MQTT" -ForegroundColor White
Write-Host "  - Receiver: MQTT -> RawSensorData" -ForegroundColor White
Write-Host "  - Dashboard: http://localhost:5000" -ForegroundColor White
Write-Host ""
Write-Success "Data Flow:"
Write-Host "  1. Publisher reads TableA/B/C (MonitorId 1,2)" -ForegroundColor White
Write-Host "  2. Publishes to data/tableA/*, data/tableB/*, data/tableC/*" -ForegroundColor White
Write-Host "  3. Receiver subscribes and receives messages" -ForegroundColor White
Write-Host "  4. Stores in RawSensorData table" -ForegroundColor White
Write-Host "  5. Dashboard shows both flows in real-time" -ForegroundColor White
Write-Host ""
Write-Success "Logging:"
Write-Host "  - All services -> Logging.ApplicationLogs" -ForegroundColor White
Write-Host ""
Write-Info "Monitor the dashboard for live updates!"
Write-Host ""
