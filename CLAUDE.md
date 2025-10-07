# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A production-ready .NET 9.0 bidirectional MQTT-SQL Server bridge system featuring:
- **ReceiverService**: Routes MQTT messages to multiple database tables (one-to-many routing)
- **MultiTablePublisher**: Monitors database changes and publishes to MQTT
- **MonitorDashboard**: Blazor-based monitoring UI (optional)

**Key Innovation**: Database-driven configuration with auto-reload - no code changes or restarts needed when adding new topics/tables.

## Architecture

```
MQTT Broker (localhost:1883)
    ↕
ReceiverService (MQTT → SQL)
    ↓
SQL Server (localhost:1433)
    ↓ (Change Tracking)
MultiTablePublisher (SQL → MQTT)
```

### Core Services

**ReceiverService** (`src/ReceiverService/`)
- Subscribes to MQTT topics (wildcards supported: `+`, `#`)
- Routes single message to multiple tables based on priority
- Supports Direct SQL, Stored Procedures, Views
- Conditional filtering (e.g., only insert if `Value > 75`)
- Auto-reloads config every 30 seconds

**MultiTablePublisher** (`src/MultiTablePublisher/`)
- Monitors multiple tables for changes via SQL Change Tracking
- Publishes changes to MQTT with configurable intervals
- Auto-reconnects with exponential backoff

**MonitorDashboard** (`src/MonitorDashboard/`)
- Blazor Server real-time dashboard
- Message volume charts, table statistics, health monitoring

## Development Commands

### Quick Start Demo
```powershell
# First time setup (creates database schema + demo config)
scripts/demo/demo.ps1 -Action init-db

# Run complete 3-minute demo with dashboard
scripts/demo/demo.ps1 -Action full-demo-with-dashboard
```

### Manual Service Control
```powershell
# Start receiver (opens new window)
scripts/demo/demo.ps1 -Action start-receiver

# Start publisher (opens new window)
scripts/demo/demo.ps1 -Action start-publisher

# Start dashboard (browser at http://localhost:5000)
scripts/demo/demo.ps1 -Action start-dashboard

# Send test messages
scripts/demo/demo.ps1 -Action send-test

# View database results
scripts/demo/demo.ps1 -Action view-data

# Clear test data
scripts/demo/demo.ps1 -Action clear-data

# Stop all services
scripts/demo/demo.ps1 -Action stop-all
```

### Build Commands
```bash
# Build all services
dotnet build --configuration Release

# Build specific service
dotnet build src/ReceiverService/ReceiverService.csproj --configuration Release

# Run service directly
dotnet run --project src/ReceiverService/ReceiverService.csproj

# Publish for deployment
dotnet publish -c Release -o ./publish
```

### Database Operations
```bash
# Initialize database (first time)
scripts/demo/demo.ps1 -Action init-db

# Or use setup script:
scripts/setup/init-receiver-demo.ps1

# Or manually run SQL scripts:
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/INIT_RECEIVER_SCHEMA.sql
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/LOAD_RECEIVER_DEMO.sql
```

### Testing
```bash
# Complete system test
scripts/testing/test-complete-system.ps1

# Send test MQTT messages
scripts/testing/test-send-mqtt-message.ps1

# Verify system status
scripts/utility/verify-system-status.ps1
```

### MQTT Testing
```bash
# Check mosquitto container
docker ps | grep mosquitto

# Start mosquitto (if not running)
docker run -d --name mosquitto -p 1883:1883 eclipse-mosquitto

# Monitor MQTT messages
docker exec mosquitto mosquitto_sub -t "sensor/#" -v

# Send manual MQTT message
docker exec mosquitto mosquitto_pub -t "sensor/device1/temperature" -m '{"device_id":"device1","value":85.0}'
```

## Database Configuration System

### Adding New MQTT Topic (No Code Changes!)

```sql
-- 1. Add topic configuration
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, MessageFormat, FieldMappingJson, QoS, Enabled)
VALUES (
    'HumiditySensors',
    'sensor/+/humidity',  -- Wildcard matches sensor/*/humidity
    'JSON',
    '{"DeviceId": "$.device_id", "Value": "$.value"}',
    1,
    1
);

-- 2. Add table mapping (can map to multiple tables!)
INSERT INTO MQTT.TopicTableMapping (
    ReceiverConfigId,
    TargetTable,
    InsertMode,      -- 'Direct', 'StoredProc', 'View'
    Priority,        -- Lower number = higher priority
    FilterExpression, -- Optional: e.g. 'Value > 75'
    Enabled
)
VALUES (
    SCOPE_IDENTITY(),
    'RawSensorData',
    'Direct',
    100,
    NULL,
    1
);
```

**Result**: Within 30 seconds, ReceiverService automatically:
1. Detects the new configuration
2. Subscribes to `sensor/+/humidity`
3. Starts routing messages to database

### Key Database Tables

**MQTT.ReceiverConfig** - Topic subscriptions
- `TopicPattern`: MQTT topic with wildcards (`+`, `#`)
- `FieldMappingJson`: JSONPath mapping for field extraction

**MQTT.TopicTableMapping** - One-to-many routing
- `TargetTable`: Destination table name
- `InsertMode`: Direct | StoredProc | View
- `Priority`: Execution order (100 = high, 90 = medium, 80 = low)
- `FilterExpression`: Conditional routing (e.g., `Value > 75`)

**MQTT.SourceTableConfig** - Publisher configuration
- Defines which tables to monitor for changes
- Specifies MQTT topic pattern for publishing

## Project Structure

```
mqtt-send/
├── README.md                        # Main project overview
├── CLAUDE.md                        # This file
├── STREAMLINED_WORKFLOWS.md         # Demo, Testing, Deployment workflows ⭐
├── REQUIREMENTS.md                  # Original requirements
├── TODO.md                          # Implementation checklist
│
├── docs/                            # Documentation (organized)
│   ├── README.md                    # Documentation index
│   ├── guides/                      # User guides and walkthroughs
│   │   ├── QUICK_START_DEMO.md     # 3-minute demo (START HERE)
│   │   ├── MULTI_WINDOW_DEMO.md    # Multi-window demo setup
│   │   ├── RECEIVER_README.md      # ReceiverService deep dive
│   │   └── DASHBOARD_README.md     # Dashboard features
│   ├── architecture/                # System architecture docs
│   │   ├── PROJECT_SUMMARY.md      # Complete technical overview
│   │   └── DATABASE_DRIVEN_MQTT_SYSTEM.md
│   ├── deployment/                  # Deployment guides
│   │   ├── AZURE_DEPLOYMENT.md     # Complete Azure deployment
│   │   └── DEPLOYMENT_QUICKSTART.md
│   ├── testing/                     # Testing documentation
│   │   ├── TESTING_GUIDE.md
│   │   └── MULTI_TABLE_TESTING_GUIDE.md
│   └── reference/                   # Reference documentation
│       └── ADDING_NEW_TABLES.md    # How to extend the system
│
├── scripts/                         # Organized PowerShell scripts
│   ├── demo/                        # Demo and presentation
│   │   └── demo.ps1                # Main orchestrator ⭐
│   ├── setup/                       # Initial setup scripts
│   │   └── init-receiver-demo.ps1
│   ├── services/                    # Service management
│   │   ├── run-receiver.ps1
│   │   └── run-publisher.ps1
│   ├── testing/                     # Testing scripts
│   │   ├── test-complete-system.ps1 ⭐
│   │   └── test-send-mqtt-message.ps1
│   ├── utility/                     # Helper utilities
│   │   └── verify-system-status.ps1
│   └── deployment/                  # Deployment automation
│       └── Deploy-ToAzure.ps1
│
├── src/                             # Source code
│   ├── ReceiverService/             # MQTT → Database
│   │   ├── Worker.cs                # Main service with auto-reload
│   │   ├── Services/
│   │   │   └── MessageProcessor.cs  # One-to-many routing
│   │   └── Models/
│   │       └── ReceiverConfiguration.cs
│   ├── MultiTablePublisher/         # Database → MQTT
│   │   └── Worker.cs
│   └── MonitorDashboard/            # Blazor real-time dashboard
│       └── Pages/Index.razor
│
├── sql/                             # Database scripts
│   ├── INIT_RECEIVER_SCHEMA.sql     # Receiver tables
│   ├── LOAD_RECEIVER_DEMO.sql       # Demo configuration
│   └── INIT_PUBLISHER_SCHEMA.sql    # Publisher tables
│
├── docker/                          # Docker configuration
│   └── mosquitto/                   # Mosquitto MQTT broker
└── config/                          # Configuration files
```

## Configuration Files

**src/ReceiverService/appsettings.json**
```json
{
  "ConnectionStrings": {
    "MqttBridge": "Server=localhost,1433;Database=MqttBridge;User Id=sa;Password=YourStrong@Passw0rd"
  },
  "MqttSettings": {
    "BrokerAddress": "localhost",
    "BrokerPort": 1883,
    "ClientId": "ReceiverService",
    "CleanSession": false,
    "AutoReconnectDelay": 5
  }
}
```

**src/MultiTablePublisher/appsettings.json**
- Similar structure but with `SourceTableConfig` loading

## Development Patterns

### One-to-Many Routing Example

A single MQTT message can route to **3 different tables**:

**Input**: MQTT topic `sensor/device1/temperature`
```json
{"device_id": "device1", "value": 85.0, "unit": "F"}
```

**Output**:
1. **dbo.RawSensorData** (Priority 100) - All messages
2. **dbo.SensorAlerts** (Priority 90) - Only if `Value > 75`
3. **dbo.SensorAggregates** (Priority 80) - Via stored procedure

### Auto-Reload Mechanism

Both services check database config every 30 seconds:
- **ReceiverService**: Unsubscribes old topics → Reloads config → Subscribes to new topics
- **MultiTablePublisher**: Reloads table monitoring list

### Error Isolation

If one table insertion fails, others continue:
```
[INF] Processing message from topic 'sensor/device1/temperature'
[INF] ✓ Inserted into RawSensorData (Priority 100)
[ERR] ✗ Failed to insert into SensorAlerts (Priority 90): Column 'InvalidField' not found
[INF] ✓ Inserted into SensorAggregates (Priority 80)
[INF] Message processing complete - 2/3 mappings successful
```

## Testing and Troubleshooting

### End-to-End Test Flow
1. Clear data: `scripts/demo/demo.ps1 -Action clear-data`
2. Start receiver: `scripts/demo/demo.ps1 -Action start-receiver` (watch Window 2)
3. Send test message: `scripts/demo/demo.ps1 -Action send-test`
4. View results: `scripts/demo/demo.ps1 -Action view-data`

### Automated Testing
```powershell
# Complete system test
scripts/testing/test-complete-system.ps1

# Continuous load testing
scripts/demo/auto-send-messages-dynamic.ps1
```

### Common Issues

**Services won't start?**
```powershell
scripts/demo/demo.ps1 -Action stop-all
dotnet build --configuration Release
scripts/demo/demo.ps1 -Action start-receiver
```

**Database connection failed?**
```bash
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "SELECT @@VERSION"
```

**MQTT broker not running?**
```bash
docker ps | grep mosquitto
docker start mosquitto
```

**Configuration not reloading?**
- Check database connection in logs
- Verify `Enabled = 1` in config tables
- Wait 30 seconds for auto-reload cycle

### Verification Queries

```sql
-- Check received messages
SELECT TOP 10 * FROM MQTT.ReceivedMessages ORDER BY ReceivedAt DESC;

-- Check routing results
SELECT * FROM dbo.RawSensorData;
SELECT * FROM dbo.SensorAlerts WHERE Value > 75;
SELECT * FROM dbo.SensorAggregates;

-- Check configuration
SELECT * FROM MQTT.ReceiverConfig WHERE Enabled = 1;
SELECT * FROM MQTT.TopicTableMapping WHERE Enabled = 1 ORDER BY Priority;
```

## Technology Stack

- **.NET 9.0** - Runtime and SDK
- **C# 13** - Language features
- **MQTTnet** - MQTT client library
- **Serilog** - Structured logging
- **SQL Server 2022** - Database with Change Tracking
- **Blazor Server** - Dashboard UI
- **Docker** - Mosquitto MQTT broker
- **PowerShell 5.1+** - Orchestration scripts

## Prerequisites

- Windows with PowerShell 5.1+
- .NET 9.0 SDK
- SQL Server (localhost:1433) with credentials `sa / YourStrong@Passw0rd`
- Docker Desktop (for Mosquitto container)
- sqlcmd utility

## Documentation Guide

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **README.md** | Project overview | **START HERE** |
| **STREAMLINED_WORKFLOWS.md** | Demo, Testing, Deployment | **Quick reference** ⭐ |
| **docs/README.md** | Documentation index | Finding specific docs |
| **docs/guides/QUICK_START_DEMO.md** | 3-minute walkthrough | First demo |
| **docs/guides/RECEIVER_README.md** | Receiver deep dive | Understanding routing |
| **docs/architecture/PROJECT_SUMMARY.md** | Complete technical details | Full architecture |
| **docs/deployment/AZURE_DEPLOYMENT.md** | Azure deployment | Production deployment |

## Code Quality Standards

- **No warnings**: Code compiles clean in Release mode
- **Structured logging**: Use Serilog with `[INF]`, `[ERR]`, `[WRN]` prefixes
- **Error handling**: Try-catch on all external operations (SQL, MQTT)
- **Async/await**: All I/O operations are async
- **Nullable handling**: Proper null checks on all external data
- **Case-insensitive**: Field mappings use case-insensitive comparisons

## Azure Deployment

See `AZURE_DEPLOYMENT.md` for complete Azure deployment guide with:
- Azure SQL Database setup
- Azure Container Instances for Mosquitto
- Azure App Service for .NET services
- Azure Key Vault for secrets
- Application Insights for monitoring
