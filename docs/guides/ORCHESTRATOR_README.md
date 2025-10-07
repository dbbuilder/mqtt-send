# MQTT Bridge Demo Orchestrator

A PowerShell-based orchestrator for managing and demonstrating the MQTT Bridge system (Publisher and Receiver services).

## Quick Start

```powershell
# Run the complete demo
.\demo.ps1 -Action full-demo

# Or start with the menu
.\demo.ps1
```

## Available Commands

### Setup & Initialization
```powershell
# Initialize database schema and demo configuration
.\demo.ps1 -Action init-db

# Clear all test data from tables
.\demo.ps1 -Action clear-data
```

### Service Management
```powershell
# Start MQTT Receiver service (new window)
.\demo.ps1 -Action start-receiver

# Start MQTT Publisher service (new window)
.\demo.ps1 -Action start-publisher

# Stop all running services
.\demo.ps1 -Action stop-all
```

### Testing
```powershell
# Send test MQTT messages
.\demo.ps1 -Action send-test

# View database contents and statistics
.\demo.ps1 -Action view-data
```

### Complete Demo
```powershell
# Run the complete demo workflow
.\demo.ps1 -Action full-demo
```

## Full Demo Workflow

The `full-demo` command performs the following steps:

1. **Clear Test Data** - Removes existing test data from all tables
2. **Start Receiver** - Launches the MQTT Receiver service in a new window
3. **Wait for Initialization** - Allows 5 seconds for the receiver to connect and subscribe
4. **Send Test Messages** - Sends 4 test MQTT messages:
   - Normal temperature (70°F)
   - High temperature (85°F) - triggers alert
   - Very high temperature (90°F) - triggers alert
   - Pressure sensor (101.3 kPa)
5. **Display Results** - Shows data in all tables demonstrating one-to-many routing

## Demo Features Demonstrated

### One-to-Many Routing
Each temperature message is routed to multiple tables:
- **All messages** → `dbo.RawSensorData` (Priority 100)
- **Value > 75** → `dbo.SensorAlerts` (Priority 90, filtered)
- **All temperatures** → `dbo.SensorAggregates` (Priority 80, via stored procedure)

### Database-Driven Configuration
- Topic patterns: `sensor/+/temperature`, `sensor/+/pressure`
- Dynamic subscriptions with MQTT wildcards
- Conditional filtering based on message content
- Multiple insert modes (Direct SQL, Stored Procedures)

### Auto-Reload Capability
The receiver automatically detects configuration changes every 30 seconds and reloads subscriptions without restart.

## Status Checking

The orchestrator displays real-time status of:
- **Receiver Service** - Running/Not Running (with PID)
- **Publisher Service** - Running/Not Running (with PID)
- **Database Connection** - Connected with record count
- **MQTT Broker** - Running/Not Running (Docker container)

## Prerequisites

- **Windows** with PowerShell 5.1+
- **.NET 9.0 SDK**
- **SQL Server** (localhost:1433)
- **Docker** with mosquitto container running
- **sqlcmd** utility installed

## Service Windows

Services are started in separate PowerShell windows for easy monitoring:

### Receiver Window
Shows real-time message processing:
```
[15:33:35 INF] RECEIVED MQTT MESSAGE
[15:33:35 INF] Topic: sensor/device1/temperature
[15:33:35 INF] Payload: {"device_id":"device1"...}
[15:33:35 INF] ✓ Inserted into dbo.RawSensorData
[15:33:35 INF] ✓ Inserted into dbo.SensorAlerts
[15:33:35 INF] ✓ Executed stored procedure
[15:33:35 INF] Message processed successfully to 3 table(s)
```

### Publisher Window
Shows outbound MQTT publishing from database changes.

## Troubleshooting

### Services Won't Start
```powershell
# Stop all services first
.\demo.ps1 -Action stop-all

# Then try starting again
.\demo.ps1 -Action start-receiver
```

### Database Connection Failed
```powershell
# Verify SQL Server is running
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "SELECT @@VERSION"
```

### MQTT Broker Not Running
```powershell
# Check Docker containers
docker ps

# Start mosquitto if needed
docker start mosquitto
```

### Clear Test Data
```powershell
# Clear all test data and start fresh
.\demo.ps1 -Action clear-data
.\demo.ps1 -Action send-test
```

## Example Workflows

### First Time Setup
```powershell
# 1. Initialize database
.\demo.ps1 -Action init-db

# 2. Run full demo
.\demo.ps1 -Action full-demo
```

### Daily Development
```powershell
# 1. Check status
.\demo.ps1

# 2. Start receiver for development
.\demo.ps1 -Action start-receiver

# 3. Send test messages
.\demo.ps1 -Action send-test

# 4. View results
.\demo.ps1 -Action view-data

# 5. Stop when done
.\demo.ps1 -Action stop-all
```

### Demo for Stakeholders
```powershell
# Single command for complete demonstration
.\demo.ps1 -Action full-demo
```

## Database Tables Populated

After running the demo, you can query:

```sql
-- Raw sensor data (all messages)
SELECT * FROM dbo.RawSensorData;

-- High temperature alerts (filtered)
SELECT * FROM dbo.SensorAlerts;

-- Hourly aggregates (via stored procedure)
SELECT * FROM dbo.SensorAggregates;

-- Message processing log
SELECT * FROM MQTT.ReceivedMessages;
```

## Configuration Files

The orchestrator uses:
- `src/ReceiverService/appsettings.json` - Receiver configuration
- `src/MultiTablePublisher/appsettings.json` - Publisher configuration
- `sql/LOAD_RECEIVER_DEMO.sql` - Demo database configuration

## Service Process Names

The orchestrator tracks services by process name:
- **Receiver**: `ReceiverService.exe`
- **Publisher**: `MultiTablePublisher.exe`

## Exit Codes

- `0` - Success
- `1` - Error (with error message displayed)

## Related Documentation

- **RECEIVER_README.md** - Detailed receiver system documentation
- **DEMO_RESULTS.md** - Test results and analysis
- **DEMO.md** - Original publisher demo documentation

## Tips

- Use `Ctrl+C` in service windows to gracefully stop services
- Check service windows for detailed logs and error messages
- The orchestrator is idempotent - safe to run commands multiple times
- Services start in new windows so you can monitor all components simultaneously
