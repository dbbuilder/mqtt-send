# MQTT Bridge Demo Orchestrator
# Manages both Publisher and Receiver services for demonstration

param(
    [ValidateSet('menu', 'start-receiver', 'start-publisher', 'start-dashboard', 'send-test', 'view-data', 'full-demo', 'full-demo-with-dashboard', 'stop-all', 'init-db', 'clear-data')]
    [string]$Action = 'menu',

    [string]$Topic,
    [decimal]$Value
)

$ErrorActionPreference = "Stop"

# Auto-detect SQL Server address
$script:SqlServerAddress = $null

function Get-SqlServerAddress {
    if ($null -eq $script:SqlServerAddress) {
        $script:SqlServerAddress = & "$PSScriptRoot\..\utility\Get-SqlServerAddress.ps1" -Quiet
        if ([string]::IsNullOrEmpty($script:SqlServerAddress)) {
            Write-Host "ERROR: SQL Server not accessible" -ForegroundColor Red
            Write-Host "Tried: localhost,1433 and 172.31.208.1,1433" -ForegroundColor Yellow
            Write-Host "Please ensure SQL Server is running and accessible." -ForegroundColor Yellow
            exit 1
        }
    }
    return $script:SqlServerAddress
}

# Color functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "  [ERROR] $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [INFO] $Text" -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "[$Text]" -ForegroundColor Cyan
}

# Initialize database
function Initialize-Database {
    Write-Header "Database Initialization"

    Write-Info "Initializing receiver schema and demo data..."
    & "$PSScriptRoot\..\setup\init-receiver-demo.ps1"

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database initialized successfully"
    } else {
        Write-Error "Database initialization failed"
        exit 1
    }
}

# Clear test data
function Clear-TestData {
    Write-Header "Clearing Test Data"

    Write-Info "Clearing all test data from tables..."

    $sqlServer = Get-SqlServerAddress
    $certFlag = if ($sqlServer -match "localhost") { "-C" } else { "" }

    $clearSql = @"
TRUNCATE TABLE dbo.RawSensorData;
DELETE FROM dbo.SensorAlerts;
DELETE FROM dbo.SensorAggregates;
DELETE FROM MQTT.ReceivedMessages;
SELECT 'Cleared all test data' AS Status;
"@

    sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q $clearSql -h -1

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Test data cleared"
    } else {
        Write-Error "Failed to clear test data"
    }
}

# Start Receiver Service
function Start-ReceiverService {
    Write-Header "Starting MQTT Receiver Service"

    # Check if already running
    $existingProcess = Get-Process -Name "ReceiverService" -ErrorAction SilentlyContinue
    if ($existingProcess) {
        Write-Info "Receiver appears to be already running (PID: $($existingProcess.Id))"
        return
    }

    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    Write-Info "Building receiver..."
    dotnet build "$projectRoot\src\ReceiverService\ReceiverService.csproj" --configuration Release -v quiet

    Write-Info "Starting receiver in new window..."

    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; Write-Host 'MQTT Receiver Service' -ForegroundColor Green; dotnet run --project src/ReceiverService/ReceiverService.csproj --configuration Release --no-build"

    Start-Sleep -Seconds 3
    Write-Success "Receiver started in new window"
}

# Start Publisher Service
function Start-PublisherService {
    Write-Header "Starting MQTT Publisher Service"

    # Check if already running
    $existingProcess = Get-Process -Name "MultiTablePublisher" -ErrorAction SilentlyContinue
    if ($existingProcess) {
        Write-Info "Publisher appears to be already running (PID: $($existingProcess.Id))"
        return
    }

    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    Write-Info "Building publisher..."
    dotnet build "$projectRoot\src\MultiTablePublisher\MultiTablePublisher.csproj" --configuration Release -v quiet

    Write-Info "Starting publisher in new window..."

    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; Write-Host 'MQTT Publisher Service' -ForegroundColor Green; dotnet run --project src/MultiTablePublisher/MultiTablePublisher.csproj --configuration Release --no-build"

    Start-Sleep -Seconds 3
    Write-Success "Publisher started in new window"
}

# Start Monitor Dashboard
function Start-DashboardService {
    Write-Header "Starting Monitor Dashboard"

    # Check if already running
    $existingProcess = Get-Process -Name "MonitorDashboard" -ErrorAction SilentlyContinue
    if ($existingProcess) {
        Write-Info "Dashboard appears to be already running (PID: $($existingProcess.Id))"
        Write-Info "Dashboard URL: http://localhost:5000"
        return
    }

    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    Write-Info "Building dashboard..."
    dotnet build "$projectRoot\src\MonitorDashboard\MonitorDashboard.csproj" --configuration Release -v quiet

    Write-Info "Starting dashboard..."
    Write-Info "Dashboard will be available at: http://localhost:5000"

    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; Write-Host 'MQTT Bridge Monitor Dashboard' -ForegroundColor Magenta; Write-Host 'Dashboard URL: http://localhost:5000' -ForegroundColor Yellow; dotnet run --project src/MonitorDashboard/MonitorDashboard.csproj --configuration Release --no-build --urls http://localhost:5000"

    Start-Sleep -Seconds 3
    Write-Success "Dashboard started"
    Write-Success "Open browser to: http://localhost:5000"

    # Optionally open browser
    Start-Process "http://localhost:5000"
}

# Send test messages
function Send-TestMessages {
    Write-Header "Sending Test MQTT Messages"

    Write-Step "Test 1: Normal Temperature (70F)"
    $ts1 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    docker exec mosquitto sh -c "mosquitto_pub -t 'sensor/device1/temperature' -m '{`"device_id`":`"device1`",`"sensor_type`":`"temperature`",`"value`":70.0,`"unit`":`"F`",`"timestamp`":`"$ts1`"}' -q 1"
    Write-Success "Sent: 70F to sensor/device1/temperature"
    Start-Sleep -Seconds 1

    Write-Step "Test 2: High Temperature Alert (85F)"
    $ts2 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    docker exec mosquitto sh -c "mosquitto_pub -t 'sensor/device1/temperature' -m '{`"device_id`":`"device1`",`"sensor_type`":`"temperature`",`"value`":85.0,`"unit`":`"F`",`"timestamp`":`"$ts2`"}' -q 1"
    Write-Success "Sent: 85F to sensor/device1/temperature (should trigger alert)"
    Start-Sleep -Seconds 1

    Write-Step "Test 3: Very High Temperature (90F)"
    $ts3 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    docker exec mosquitto sh -c "mosquitto_pub -t 'sensor/device1/temperature' -m '{`"device_id`":`"device1`",`"sensor_type`":`"temperature`",`"value`":90.0,`"unit`":`"F`",`"timestamp`":`"$ts3`"}' -q 1"
    Write-Success "Sent: 90F to sensor/device1/temperature (high alert)"
    Start-Sleep -Seconds 1

    Write-Step "Test 4: Pressure Sensor (101.3 kPa)"
    $ts4 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    docker exec mosquitto sh -c "mosquitto_pub -t 'sensor/device2/pressure' -m '{`"device_id`":`"device2`",`"sensor_type`":`"pressure`",`"value`":101.3,`"unit`":`"kPa`",`"timestamp`":`"$ts4`"}' -q 1"
    Write-Success "Sent: 101.3 kPa to sensor/device2/pressure"

    Write-Info "Waiting for messages to be processed..."
    Start-Sleep -Seconds 3
}

# View database data
function View-DatabaseData {
    Write-Header "Database Contents"

    $sqlServer = Get-SqlServerAddress
    $certFlag = if ($sqlServer -match "localhost") { "-C" } else { "" }

    Write-Step "Raw Sensor Data (All Messages)"
    sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q "SELECT TOP 10 Id, DeviceId, SensorType, Value, Unit, CONVERT(VARCHAR(19), Timestamp, 120) AS Timestamp FROM dbo.RawSensorData ORDER BY ReceivedAt DESC" -s "|" -W

    Write-Step "Sensor Alerts (High Temperature)"
    sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q "SELECT * FROM dbo.SensorAlerts" -s "|" -W

    Write-Step "Sensor Aggregates (Hourly Stats)"
    sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q "SELECT DeviceId, SensorType, AvgValue, MinValue, MaxValue, ReadingCount, CONVERT(VARCHAR(19), FirstReading, 120) AS FirstReading FROM dbo.SensorAggregates" -s "|" -W

    Write-Step "Summary Counts"
    sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q "SELECT COUNT(*) AS RawSensorData FROM dbo.RawSensorData; SELECT COUNT(*) AS SensorAlerts FROM dbo.SensorAlerts; SELECT COUNT(*) AS SensorAggregates FROM dbo.SensorAggregates;" -W

    Write-Step "Active Receiver Configuration"
    sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q "SELECT rc.ConfigName, rc.TopicPattern, COUNT(tm.Id) AS Mappings FROM MQTT.ReceiverConfig rc LEFT JOIN MQTT.TopicTableMapping tm ON tm.ReceiverConfigId = rc.Id WHERE rc.Enabled = 1 GROUP BY rc.ConfigName, rc.TopicPattern" -s "|" -W
}

# Stop all services
function Stop-AllServices {
    Write-Header "Stopping All Services"

    $receiverProcesses = Get-Process -Name "ReceiverService" -ErrorAction SilentlyContinue
    if ($receiverProcesses) {
        Write-Info "Stopping receiver processes..."
        $receiverProcesses | Stop-Process -Force
        Write-Success "Receiver stopped"
    } else {
        Write-Info "No receiver processes found"
    }

    $publisherProcesses = Get-Process -Name "MultiTablePublisher" -ErrorAction SilentlyContinue
    if ($publisherProcesses) {
        Write-Info "Stopping publisher processes..."
        $publisherProcesses | Stop-Process -Force
        Write-Success "Publisher stopped"
    } else {
        Write-Info "No publisher processes found"
    }

    $dashboardProcesses = Get-Process -Name "MonitorDashboard" -ErrorAction SilentlyContinue
    if ($dashboardProcesses) {
        Write-Info "Stopping dashboard processes..."
        $dashboardProcesses | Stop-Process -Force
        Write-Success "Dashboard stopped"
    } else {
        Write-Info "No dashboard processes found"
    }

    Write-Success "All services stopped"
}

# Check prerequisites
function Check-Prerequisites {
    # Run prerequisite checker
    & "$PSScriptRoot\..\utility\Test-Prerequisites.ps1"

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        $response = Read-Host "Prerequisites check failed. Continue anyway? (Y/N)"
        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Host "Demo cancelled. Please resolve prerequisites and try again." -ForegroundColor Yellow
            exit 1
        }
        Write-Host ""
    }
}

# Full demo workflow
function Run-FullDemo {
    # Check prerequisites first
    Check-Prerequisites

    Write-Header "MQTT Bridge Full Demo"

    Write-Info "This demo will:"
    Write-Host "  1. Clear existing test data" -ForegroundColor Gray
    Write-Host "  2. Start the MQTT Receiver service" -ForegroundColor Gray
    Write-Host "  3. Send test messages to various topics" -ForegroundColor Gray
    Write-Host "  4. Display the received data from database" -ForegroundColor Gray
    Write-Host "  5. Show the one-to-many routing in action" -ForegroundColor Gray
    Write-Host ""

    # Clear test data
    Clear-TestData

    # Start receiver
    Start-ReceiverService

    Write-Info "Waiting for receiver to fully initialize..."
    Start-Sleep -Seconds 5

    # Send test messages
    Send-TestMessages

    # View results
    View-DatabaseData

    Write-Header "Demo Summary"
    Write-Success "Receiver is processing messages in separate window"
    Write-Success "Messages have been routed to multiple tables based on configuration"
    Write-Host ""
    Write-Host "One-to-Many Routing Results:" -ForegroundColor Yellow
    Write-Host "  - All 4 messages -> dbo.RawSensorData" -ForegroundColor Gray
    Write-Host "  - High temp messages (Value > 75) -> dbo.SensorAlerts" -ForegroundColor Gray
    Write-Host "  - Temperature stats -> dbo.SensorAggregates (via stored proc)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  - Run 'scripts/demo/demo.ps1 -Action send-test' to send more messages" -ForegroundColor Gray
    Write-Host "  - Run 'scripts/demo/demo.ps1 -Action view-data' to see current data" -ForegroundColor Gray
    Write-Host "  - Run 'scripts/demo/demo.ps1 -Action stop-all' to stop all services" -ForegroundColor Gray
    Write-Host ""
}

# Full demo workflow with dashboard
function Run-FullDemoWithDashboard {
    # Check prerequisites first
    Check-Prerequisites

    Write-Header "MQTT Bridge Full Demo (with Dashboard)"

    Write-Info "This demo will:"
    Write-Host "  1. Clear existing test data" -ForegroundColor Gray
    Write-Host "  2. Start the MQTT Receiver service" -ForegroundColor Gray
    Write-Host "  3. Start the MQTT Publisher service" -ForegroundColor Gray
    Write-Host "  4. Start the Monitor Dashboard" -ForegroundColor Gray
    Write-Host "  5. Send test messages to various topics" -ForegroundColor Gray
    Write-Host "  6. Display the received data from database" -ForegroundColor Gray
    Write-Host "  7. Show the one-to-many routing in action" -ForegroundColor Gray
    Write-Host ""

    # Clear test data
    Clear-TestData

    # Start all services
    Start-ReceiverService
    Start-PublisherService
    Start-DashboardService

    Write-Info "Waiting for all services to fully initialize..."
    Start-Sleep -Seconds 8

    # Send test messages
    Send-TestMessages

    Write-Info "Waiting for messages to be processed..."
    Start-Sleep -Seconds 3

    # View results
    View-DatabaseData

    Write-Header "Demo Summary"
    Write-Success "All services are running in separate windows:"
    Write-Success "  - Receiver: Processing MQTT messages -> Database"
    Write-Success "  - Publisher: Publishing database changes -> MQTT"
    Write-Success "  - Dashboard: http://localhost:5000"
    Write-Host ""
    Write-Host "One-to-Many Routing Results:" -ForegroundColor Yellow
    Write-Host "  - All 4 messages -> dbo.RawSensorData" -ForegroundColor Gray
    Write-Host "  - High temp messages (Value > 75) -> dbo.SensorAlerts" -ForegroundColor Gray
    Write-Host "  - Temperature stats -> dbo.SensorAggregates (via stored proc)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  - Open browser to http://localhost:5000 to view real-time dashboard" -ForegroundColor Magenta
    Write-Host "  - Run 'scripts/demo/demo.ps1 -Action send-test' to send more messages" -ForegroundColor Gray
    Write-Host "  - Run 'scripts/demo/demo.ps1 -Action view-data' to see current data" -ForegroundColor Gray
    Write-Host "  - Run 'scripts/demo/demo.ps1 -Action stop-all' to stop all services" -ForegroundColor Gray
    Write-Host ""
}

# Show menu
function Show-Menu {
    Write-Header "MQTT Bridge Demo Orchestrator"

    Write-Host "Available Commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Setup & Initialization:" -ForegroundColor Cyan
    Write-Host "    ./demo.ps1 -Action init-db          - Initialize database schema and demo config" -ForegroundColor Gray
    Write-Host "    ./demo.ps1 -Action clear-data       - Clear all test data from tables" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Service Management:" -ForegroundColor Cyan
    Write-Host "    ./demo.ps1 -Action start-receiver   - Start MQTT Receiver service" -ForegroundColor Gray
    Write-Host "    ./demo.ps1 -Action start-publisher  - Start MQTT Publisher service" -ForegroundColor Gray
    Write-Host "    ./demo.ps1 -Action start-dashboard  - Start Monitor Dashboard (http://localhost:5000)" -ForegroundColor Gray
    Write-Host "    ./demo.ps1 -Action stop-all         - Stop all running services" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Testing:" -ForegroundColor Cyan
    Write-Host "    ./demo.ps1 -Action send-test        - Send test MQTT messages" -ForegroundColor Gray
    Write-Host "    ./demo.ps1 -Action view-data        - View database contents" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Complete Demo:" -ForegroundColor Cyan
    Write-Host "    ./demo.ps1 -Action full-demo                  - Run complete demo workflow" -ForegroundColor Gray
    Write-Host "    ./demo.ps1 -Action full-demo-with-dashboard   - Run complete demo with dashboard" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  ./demo.ps1 -Action full-demo-with-dashboard   # Complete demo with dashboard" -ForegroundColor DarkGray
    Write-Host "  ./demo.ps1 -Action full-demo                  # Demo without dashboard" -ForegroundColor DarkGray
    Write-Host "  ./demo.ps1 -Action start-receiver             # Just start receiver" -ForegroundColor DarkGray
    Write-Host "  ./demo.ps1 -Action send-test                  # Send test messages" -ForegroundColor DarkGray
    Write-Host ""

    # Show status
    Write-Header "Current Status"

    # Check receiver
    $receiverRunning = Get-Process -Name "ReceiverService" -ErrorAction SilentlyContinue
    if ($receiverRunning) {
        Write-Success "Receiver: Running (PID: $($receiverRunning.Id))"
    } else {
        Write-Info "Receiver: Not running"
    }

    # Check publisher
    $publisherRunning = Get-Process -Name "MultiTablePublisher" -ErrorAction SilentlyContinue
    if ($publisherRunning) {
        Write-Success "Publisher: Running (PID: $($publisherRunning.Id))"
    } else {
        Write-Info "Publisher: Not running"
    }

    # Check dashboard
    $dashboardRunning = Get-Process -Name "MonitorDashboard" -ErrorAction SilentlyContinue
    if ($dashboardRunning) {
        Write-Success "Dashboard: Running (http://localhost:5000)"
    } else {
        Write-Info "Dashboard: Not running"
    }

    # Check database
    Write-Host ""
    Write-Info "Checking database connection..."
    $sqlServer = & "$PSScriptRoot\..\utility\Get-SqlServerAddress.ps1" -Quiet
    if (-not [string]::IsNullOrEmpty($sqlServer)) {
        $certFlag = if ($sqlServer -match "localhost") { "-C" } else { "" }
        $dbTest = sqlcmd -S $sqlServer -U sa -P "YourStrong@Passw0rd" $certFlag -d MqttBridge -Q "SELECT COUNT(*) FROM dbo.RawSensorData" -h -1 2>&1
        if ($LASTEXITCODE -eq 0) {
            $count = $dbTest.Trim()
            Write-Success "Database: Connected at $sqlServer ($count records in RawSensorData)"
        } else {
            Write-Error "Database: Connection failed"
        }
    } else {
        Write-Error "Database: SQL Server not accessible"
    }

    # Check Docker
    Write-Host ""
    Write-Info "Checking MQTT broker..."
    $mosquitto = docker ps --filter "name=mosquitto" --format "{{.Names}}" 2>&1
    if ($mosquitto -eq "mosquitto") {
        Write-Success "MQTT Broker: Running (mosquitto container)"
    } else {
        Write-Error "MQTT Broker: Not running (mosquitto container not found)"
    }

    Write-Host ""
}

# Main execution
try {
    switch ($Action) {
        'init-db' {
            Initialize-Database
        }
        'clear-data' {
            Clear-TestData
        }
        'start-receiver' {
            Start-ReceiverService
        }
        'start-publisher' {
            Start-PublisherService
        }
        'start-dashboard' {
            Start-DashboardService
        }
        'send-test' {
            Send-TestMessages
        }
        'view-data' {
            View-DatabaseData
        }
        'full-demo' {
            Run-FullDemo
        }
        'full-demo-with-dashboard' {
            Run-FullDemoWithDashboard
        }
        'stop-all' {
            Stop-AllServices
        }
        'menu' {
            Show-Menu
        }
        default {
            Show-Menu
        }
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
