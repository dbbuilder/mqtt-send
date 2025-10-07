# MQTT Bridge System

**Bidirectional MQTT ↔ SQL Server Integration with Database-Driven Configuration**

A production-ready .NET 9.0 system for seamless integration between MQTT messaging and SQL Server, featuring:
- ✅ **One-to-Many Message Routing** (single MQTT message → multiple database tables)
- ✅ **Database-Driven Configuration** (no code changes needed)
- ✅ **Auto-Reload** (configuration changes detected automatically)
- ✅ **Bidirectional** (publish & subscribe)
- ✅ **External MQTT Broker Support** (non-Azure)

---

## 🚀 Quick Start

### 3-Minute Demo
```powershell
cd D:\dev2\clients\mbox\mqtt-send

# First time setup (once)
.\demo.ps1 -Action init-db

# Run complete demo
.\demo.ps1 -Action full-demo
```

This will:
1. Clear test data
2. Start Receiver service (new window)
3. Send 4 test MQTT messages
4. Display results showing one-to-many routing

**See:** [QUICK_START_DEMO.md](QUICK_START_DEMO.md) for detailed walkthrough

---

## 📊 System Architecture

```
┌─────────────────────┐
│  External MQTT      │
│  Broker             │
│  (localhost:1883)   │
└──────────┬──────────┘
           │
           │ Subscribe                     Publish
           │                                  ▲
    ┌──────▼────────┐                        │
    │  MQTT         │                  ┌─────┴────────┐
    │  Receiver     │                  │  MQTT        │
    │  Service      │                  │  Publisher   │
    └───────┬───────┘                  │  Service     │
            │                          └─────▲────────┘
            │                                │
            │ One-to-Many Routing            │ Change Detection
            │                                │
    ┌───────▼────────────────────────────────┴───┐
    │           SQL Server Database              │
    │  • ReceiverConfig (topics)                 │
    │  • TopicTableMapping (routing)             │
    │  • RawSensorData, Alerts, Aggregates       │
    │  • Change Tracking (for publisher)         │
    └────────────────────────────────────────────┘
```

---

## 🎯 Key Features

### MQTT Receiver (MQTT → Database)
- **Dynamic Topic Subscriptions** - MQTT wildcards (`+`, `#`) supported
- **One-to-Many Routing** - Single message → Multiple tables based on priority
- **Conditional Filtering** - Route based on message content (e.g., `Value > 75`)
- **Multiple Insert Modes** - Direct SQL, Stored Procedures, or Views
- **Auto-Reload** - Detects config changes every 30s without restart
- **JSON Parsing** - Flexible field mapping with JSONPath support
- **Error Isolation** - One table failure doesn't block others

### MQTT Publisher (Database → MQTT)
- **Multi-Table Monitoring** - Track changes across multiple tables
- **Change Tracking** - SQL Server native change detection
- **Auto-Reconnect** - Exponential backoff for resilience
- **JSON Serialization** - Automatic payload generation
- **Configurable Polling** - Adjustable intervals per table

---

## 📁 Project Structure

```
mqtt-send/
├── demo.ps1                          # 🎮 Demo orchestrator (START HERE)
├── README.md                         # 📖 This file
├── QUICK_START_DEMO.md              # ⚡ 3-minute quick start
├── MULTI_WINDOW_DEMO.md             # 🖥️ Multi-window demo walkthrough
├── ORCHESTRATOR_README.md           # 📋 Orchestrator documentation
├── RECEIVER_README.md               # 📡 Receiver system guide
├── PROJECT_SUMMARY.md               # 📊 Complete project overview
├── DEMO_RESULTS.md                  # ✅ Test results & analysis
│
├── src/
│   ├── ReceiverService/             # 📥 MQTT → Database
│   │   ├── Worker.cs                # Main service with auto-reload
│   │   ├── Services/
│   │   │   └── MessageProcessor.cs  # Message parsing & routing
│   │   └── Models/
│   │       └── ReceiverConfiguration.cs
│   │
│   └── MultiTablePublisher/         # 📤 Database → MQTT
│       └── Worker.cs                # Change detection & publishing
│
├── sql/
│   ├── INIT_RECEIVER_SCHEMA.sql     # Receiver database schema
│   ├── LOAD_RECEIVER_DEMO.sql       # Demo configuration
│   └── INIT_PUBLISHER_SCHEMA.sql    # Publisher database schema
│
└── scripts/
    ├── init-receiver-demo.ps1       # Initialize receiver demo
    ├── run-receiver.ps1             # Start receiver service
    └── test-send-mqtt-message.ps1   # Send test messages
```

---

## 🎬 Demo Options

### Option 1: Automated Demo (1 minute)
```powershell
.\demo.ps1 -Action full-demo
```
Runs complete workflow automatically.

### Option 2: Interactive Demo (5 minutes)
```powershell
# 1. Show status
.\demo.ps1

# 2. Clear old data
.\demo.ps1 -Action clear-data

# 3. Start Receiver (opens new window)
.\demo.ps1 -Action start-receiver

# 4. Start Publisher (opens new window)
.\demo.ps1 -Action start-publisher

# 5. Send test messages
.\demo.ps1 -Action send-test

# 6. View results
.\demo.ps1 -Action view-data

# 7. Stop all
.\demo.ps1 -Action stop-all
```

### Option 3: Multi-Window Demo (10 minutes)
**Best for stakeholder presentations**

See [MULTI_WINDOW_DEMO.md](MULTI_WINDOW_DEMO.md) for complete 4-window setup with:
- Window 1: Orchestrator (control center)
- Window 2: Receiver (MQTT → DB real-time logs)
- Window 3: Publisher (DB → MQTT real-time logs)
- Window 4: Database (SQL queries for verification)

---

## 📖 Documentation

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [QUICK_START_DEMO.md](QUICK_START_DEMO.md) | 3-minute quick start guide | **START HERE** for first demo |
| [MULTI_WINDOW_DEMO.md](MULTI_WINDOW_DEMO.md) | Multi-window demo walkthrough | For stakeholder presentations |
| [ORCHESTRATOR_README.md](ORCHESTRATOR_README.md) | Orchestrator commands & usage | Reference for demo.ps1 |
| [RECEIVER_README.md](RECEIVER_README.md) | Receiver system deep dive | Understanding receiver internals |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Complete project overview | Full technical details |
| [DEMO_RESULTS.md](DEMO_RESULTS.md) | Test results & analysis | Verification & troubleshooting |

---

## 🎯 Example: One-to-Many Routing

A single temperature message routes to **3 different tables** based on configuration:

### Input (MQTT Message):
```json
Topic: sensor/device1/temperature
Payload: {
  "device_id": "device1",
  "sensor_type": "temperature",
  "value": 85.0,
  "unit": "F",
  "timestamp": "2025-10-06T22:30:00Z"
}
```

### Output (Database):

**Table 1: dbo.RawSensorData (Priority 100)** - All messages
```
Id  | DeviceId | SensorType  | Value | Unit | Timestamp
----|----------|-------------|-------|------|----------
1   | device1  | temperature | 85.0  | F    | 2025-10-06 22:30:00
```

**Table 2: dbo.SensorAlerts (Priority 90)** - Only if `Value > 75`
```
Id  | DeviceId | AlertType         | Value | Threshold | AlertTime
----|----------|-------------------|-------|-----------|----------
1   | device1  | HighTemperature   | 85.0  | 75.0      | 2025-10-06 22:30:00
```

**Table 3: dbo.SensorAggregates (Priority 80)** - Via stored procedure
```
DeviceId | SensorType  | AvgValue | MinValue | MaxValue | ReadingCount
---------|-------------|----------|----------|----------|-------------
device1  | temperature | 85.0     | 85.0     | 85.0     | 1
```

**All from a single MQTT message!** ✨

---

## ⚙️ Configuration Example

### Add New MQTT Topic (No Code Changes!)

```sql
-- 1. Add topic configuration
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, MessageFormat, FieldMappingJson, QoS, Enabled)
VALUES (
    'HumiditySensors',
    'sensor/+/humidity',  -- Wildcard: matches sensor/*/humidity
    'JSON',
    '{"DeviceId": "$.device_id", "Value": "$.value", "Unit": "$.unit"}',
    1,
    1
);

-- 2. Add table mapping
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, InsertMode, Priority, Enabled)
VALUES (
    SCOPE_IDENTITY(),
    'RawSensorData',
    'Direct',
    100,
    1
);
```

**Result:** Within 30 seconds, the Receiver automatically:
1. Detects the new configuration
2. Subscribes to `sensor/+/humidity`
3. Starts routing humidity messages to database

**No restart required!** 🚀

---

## 🔧 Technology Stack

- **.NET 9.0** - Runtime and SDK
- **C# 13** - Language features
- **MQTTnet** - MQTT client library
- **Serilog** - Structured logging
- **SQL Server 2022** - Database
- **Docker** - Mosquitto MQTT broker
- **PowerShell 5.1+** - Orchestration

---

## 📋 Prerequisites

- Windows with PowerShell 5.1+
- .NET 9.0 SDK
- SQL Server (localhost:1433)
- Docker Desktop (for mosquitto container)
- sqlcmd utility

---

## 🚀 Installation

### 1. Clone Repository
```powershell
cd D:\dev2\clients\mbox
git clone <repository-url> mqtt-send
cd mqtt-send
```

### 2. Start MQTT Broker
```powershell
docker run -d --name mosquitto -p 1883:1883 eclipse-mosquitto
```

### 3. Initialize Database
```powershell
.\demo.ps1 -Action init-db
```

### 4. Build Services
```powershell
dotnet build --configuration Release
```

### 5. Run Demo
```powershell
.\demo.ps1 -Action full-demo
```

---

## 🐛 Troubleshooting

### Services won't start?
```powershell
.\demo.ps1 -Action stop-all
dotnet build --configuration Release
.\demo.ps1 -Action start-receiver
```

### Database connection failed?
```powershell
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "SELECT @@VERSION"
```

### MQTT broker not running?
```powershell
docker ps | grep mosquitto
docker start mosquitto
```

See [DEMO_RESULTS.md](DEMO_RESULTS.md) for detailed troubleshooting.

---

## ✅ Verified Features

- ✅ **One-to-Many Routing** - 1 message → 3 tables verified
- ✅ **Stored Procedures** - Parameter introspection working
- ✅ **Case-Insensitive Matching** - Field lookups working
- ✅ **Topic Wildcards** - `+` and `#` patterns working
- ✅ **Auto-Reload** - Configuration changes detected
- ✅ **Error Isolation** - Partial failures handled gracefully
- ✅ **Zero Warnings** - Production-ready code quality

---

## 🎓 Learning Path

1. **Quick Start** → [QUICK_START_DEMO.md](QUICK_START_DEMO.md) (5 min)
2. **Multi-Window Demo** → [MULTI_WINDOW_DEMO.md](MULTI_WINDOW_DEMO.md) (15 min)
3. **Deep Dive** → [RECEIVER_README.md](RECEIVER_README.md) (30 min)
4. **Full Overview** → [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) (45 min)

---

## 🚀 Getting Started Checklist

- [ ] Prerequisites installed (SQL Server, Docker, .NET 9)
- [ ] Repository cloned
- [ ] Database initialized (`.\demo.ps1 -Action init-db`)
- [ ] Services built (`dotnet build --configuration Release`)
- [ ] Demo runs successfully (`.\demo.ps1 -Action full-demo`)
- [ ] Multi-window demo works (`.\demo.ps1 -Action start-receiver`)
- [ ] Documentation reviewed ([QUICK_START_DEMO.md](QUICK_START_DEMO.md))

**Ready to demo!** 🎉

---

**Built with ❤️ using .NET 9.0 and MQTTnet**
