<#
.SYNOPSIS
    Start the complete MQTT Bridge system with bidirectional flow and monitoring

.DESCRIPTION
    This script manages the full MQTT Bridge system:
    - Publisher: TableA/B/C -> MQTT (data/tableA/1, data/tableA/2, etc.)
    - Receiver: MQTT -> RawSensorData
    - Dashboard: Real-time monitoring web UI
    - Logging: All errors and events to database

.PARAMETER Action
    Action to perform: start, stop, status, restart, logs

.EXAMPLE
    .\Start-FullSystem.ps1 -Action start
    .\Start-FullSystem.ps1 -Action status
    .\Start-FullSystem.ps1 -Action stop
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('start', 'stop', 'status', 'restart', 'logs', 'test')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$BaseDir = $PSScriptRoot

# ============================================
# Helper Functions
# ============================================

function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Warning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }

function Test-ProcessRunning {
    param([string]$ProcessName)
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    return $null -ne $process
}

function Test-DockerContainerRunning {
    param([string]$ContainerName)
    try {
        $container = docker ps --filter "name=$ContainerName" --filter "status=running" --format "{{.Names}}" 2>$null
        return $container -eq $ContainerName
    } catch {
        return $false
    }
}

function Stop-ServiceProcess {
    param([string]$ProcessName)
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Info "Stopping $ProcessName (PID: $($processes.Id -join ', '))"
        $processes | Stop-Process -Force
        Start-Sleep -Seconds 2
        Write-Success "$ProcessName stopped"
    } else {
        Write-Info "$ProcessName is not running"
    }
}

function Get-SystemStatus {
    Write-Info "=== MQTT BRIDGE SYSTEM STATUS ==="
    Write-Host ""

    # Check MQTT Broker (Docker container)
    $mqttRunning = Test-DockerContainerRunning -ContainerName "mosquitto"
    if ($mqttRunning) {
        Write-Success "MQTT Broker (Mosquitto): RUNNING (Docker)"
    } else {
        Write-Error "MQTT Broker (Mosquitto): STOPPED"
    }

    # Check Publisher
    $publisherRunning = Test-ProcessRunning -ProcessName "MultiTablePublisher"
    if ($publisherRunning) {
        Write-Success "Publisher Service: RUNNING"
    } else {
        Write-Warning "Publisher Service: STOPPED"
    }

    # Check Receiver
    $receiverRunning = Test-ProcessRunning -ProcessName "ReceiverService"
    if ($receiverRunning) {
        Write-Success "Receiver Service: RUNNING"
    } else {
        Write-Warning "Receiver Service: STOPPED"
    }

    # Check Dashboard
    $dashboardRunning = Test-ProcessRunning -ProcessName "MonitorDashboard"
    if ($dashboardRunning) {
        Write-Success "Monitor Dashboard: RUNNING (http://localhost:5000)"
    } else {
        Write-Warning "Monitor Dashboard: STOPPED"
    }

    Write-Host ""
    Write-Info "=== DATABASE STATUS ==="

    # Check database statistics
    $query = @"
SELECT
    (SELECT COUNT(*) FROM MQTT.SentRecords) as PublishedMessages,
    (SELECT COUNT(*) FROM MQTT.ReceivedMessages) as ReceivedMessages,
    (SELECT COUNT(*) FROM dbo.RawSensorData) as RawSensorRecords,
    (SELECT COUNT(*) FROM Logging.ApplicationLogs) as LogEntries
"@

    try {
        $result = sqlcmd -S "localhost,1433" -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q $query -h -1 -W
        Write-Host $result
    } catch {
        Write-Error "Could not connect to database"
    }
}

# ============================================
# Main Actions
# ============================================

function Start-AllServices {
    Write-Info "Starting MQTT Bridge System..."
    Write-Host ""

    # Step 1: Check MQTT Broker (Docker)
    if (-not (Test-DockerContainerRunning -ContainerName "mosquitto")) {
        Write-Error "MQTT Broker is not running. Please start it with:"
        Write-Host "  cd docker" -ForegroundColor Yellow
        Write-Host "  docker-compose up -d mosquitto" -ForegroundColor Yellow
        return
    }
    Write-Success "MQTT Broker is running (Docker)"

    # Step 2: Build all services
    Write-Info "Building all services..."

    Push-Location "$BaseDir\src\ReceiverService"
    dotnet build --configuration Release --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ReceiverService build failed"
        Pop-Location
        return
    }
    Pop-Location

    Push-Location "$BaseDir\src\MultiTablePublisher"
    dotnet build --configuration Release --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MultiTablePublisher build failed"
        Pop-Location
        return
    }
    Pop-Location

    Push-Location "$BaseDir\src\MonitorDashboard"
    dotnet build --configuration Release --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MonitorDashboard build failed"
        Pop-Location
        return
    }
    Pop-Location

    Write-Success "All services built successfully"

    # Step 3: Start Publisher
    if (-not (Test-ProcessRunning -ProcessName "MultiTablePublisher")) {
        Write-Info "Starting Publisher Service..."
        Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
Set-Location '$BaseDir'
Write-Host 'PUBLISHER SERVICE' -ForegroundColor Green
Write-Host 'Reading from TableA/B/C and publishing to MQTT' -ForegroundColor Cyan
Write-Host ''
dotnet run --project src/MultiTablePublisher/MultiTablePublisher.csproj --configuration Release --no-build
"@
        Start-Sleep -Seconds 3
        Write-Success "Publisher Service started"
    } else {
        Write-Warning "Publisher Service already running"
    }

    # Step 4: Start Receiver
    if (-not (Test-ProcessRunning -ProcessName "ReceiverService")) {
        Write-Info "Starting Receiver Service..."
        Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
Set-Location '$BaseDir'
Write-Host 'RECEIVER SERVICE' -ForegroundColor Green
Write-Host 'Subscribing to MQTT topics and writing to RawSensorData' -ForegroundColor Cyan
Write-Host ''
dotnet run --project src/ReceiverService/ReceiverService.csproj --configuration Release --no-build
"@
        Start-Sleep -Seconds 3
        Write-Success "Receiver Service started"
    } else {
        Write-Warning "Receiver Service already running"
    }

    # Step 5: Start Dashboard
    if (-not (Test-ProcessRunning -ProcessName "MonitorDashboard")) {
        Write-Info "Starting Monitor Dashboard..."
        Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
Set-Location '$BaseDir'
Write-Host 'MONITOR DASHBOARD' -ForegroundColor Green
Write-Host 'Real-time monitoring at http://localhost:5000' -ForegroundColor Cyan
Write-Host ''
dotnet run --project src/MonitorDashboard/MonitorDashboard.csproj --configuration Release --no-build --urls http://localhost:5000
"@
        Start-Sleep -Seconds 5
        Write-Success "Monitor Dashboard started at http://localhost:5000"

        # Open browser
        Start-Process "http://localhost:5000"
    } else {
        Write-Warning "Monitor Dashboard already running at http://localhost:5000"
    }

    Write-Host ""
    Write-Success "=== SYSTEM STARTED ==="
    Write-Info "Dashboard: http://localhost:5000"
    Write-Info "Data Flow: TableA/B/C -> MQTT -> RawSensorData"
    Write-Info "Logging: All services -> Logging.ApplicationLogs"
}

function Stop-AllServices {
    Write-Info "Stopping all MQTT Bridge services..."

    Stop-ServiceProcess -ProcessName "MonitorDashboard"
    Stop-ServiceProcess -ProcessName "ReceiverService"
    Stop-ServiceProcess -ProcessName "MultiTablePublisher"

    Write-Success "All services stopped"
}

function Show-Logs {
    Write-Info "Recent application logs from database..."
    $query = @"
SELECT TOP 20
    CONVERT(VARCHAR, Timestamp, 120) as Time,
    ServiceName,
    Level,
    Message
FROM Logging.ApplicationLogs
ORDER BY Timestamp DESC
"@
    sqlcmd -S "localhost,1433" -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q $query -W
}

function Test-DataFlow {
    Write-Info "Testing bidirectional data flow..."
    Write-Host ""

    # Check recent published messages
    Write-Info "Recent Published Messages (Database -> MQTT):"
    $query1 = @"
SELECT TOP 5
    CONVERT(VARCHAR, SentAt, 120) as SentAt,
    SourceName,
    Topic
FROM MQTT.SentRecords
ORDER BY SentAt DESC
"@
    sqlcmd -S "localhost,1433" -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q $query1 -W

    Write-Host ""

    # Check recent received messages
    Write-Info "Recent Received Messages (MQTT -> Database):"
    $query2 = @"
SELECT TOP 5
    CONVERT(VARCHAR, ReceivedAt, 120) as ReceivedAt,
    Topic,
    Status,
    TargetTablesProcessed
FROM MQTT.ReceivedMessages
ORDER BY ReceivedAt DESC
"@
    sqlcmd -S "localhost,1433" -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q $query2 -W

    Write-Host ""

    # Check RawSensorData
    Write-Info "Recent RawSensorData Records:"
    $query3 = @"
SELECT TOP 5
    CONVERT(VARCHAR, ReceivedAt, 120) as ReceivedAt,
    DeviceId,
    SensorType,
    Value,
    Unit
FROM dbo.RawSensorData
ORDER BY ReceivedAt DESC
"@
    sqlcmd -S "localhost,1433" -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q $query3 -W
}

# ============================================
# Execute Action
# ============================================

switch ($Action) {
    'start' { Start-AllServices }
    'stop' { Stop-AllServices }
    'status' { Get-SystemStatus }
    'restart' {
        Stop-AllServices
        Start-Sleep -Seconds 2
        Start-AllServices
    }
    'logs' { Show-Logs }
    'test' { Test-DataFlow }
}
