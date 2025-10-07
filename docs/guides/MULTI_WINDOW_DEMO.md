# Multi-Window MQTT Bridge Demo Guide

This guide demonstrates the **complete bidirectional MQTT bridge** using multiple windows to show real-time message flow.

## Demo Architecture

```
Window 1: Orchestrator       Window 2: Receiver          Window 3: Publisher
(Control Center)             (MQTT → Database)           (Database → MQTT)
    │                              │                           │
    │ Commands                     │ Subscribe                 │ Publish
    ▼                              ▼                           ▼
┌─────────┐                  ┌──────────┐              ┌──────────┐
│  demo   │──────────────────│   MQTT   │──────────────│   MQTT   │
│  .ps1   │                  │ Receiver │              │Publisher │
└─────────┘                  └──────────┘              └──────────┘
    │                              │                           │
    │                              ▼                           ▲
    │                        ┌──────────┐                      │
    └────────────────────────│    SQL   │──────────────────────┘
                             │  Server  │
                             └──────────┘
                                   ▲
                             Window 4: Database
                             (SQL Query Window)
```

## Setup: 4-Window Layout

### Window 1: Orchestrator (Bottom Left) - CONTROL CENTER
**Purpose:** Command and control center for the demo

**Setup:**
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\demo.ps1
```

**What you'll see:**
```
========================================
 MQTT Bridge Demo Orchestrator
========================================

Available Commands:
  Setup & Initialization:
    ./demo.ps1 -Action init-db
    ./demo.ps1 -Action clear-data

  Service Management:
    ./demo.ps1 -Action start-receiver
    ./demo.ps1 -Action start-publisher
    ./demo.ps1 -Action stop-all
  ...

========================================
 Current Status
========================================
  [INFO] Receiver: Not running
  [INFO] Publisher: Not running
  [OK] Database: Connected (4 records in RawSensorData)
  [OK] MQTT Broker: Running (mosquitto container)
```

---

### Window 2: Receiver Service (Top Left) - INBOUND TRAFFIC
**Purpose:** Shows real-time MQTT message reception and database insertion

**How to start:**
```powershell
# From Window 1 (Orchestrator):
.\demo.ps1 -Action start-receiver

# This will open a NEW window automatically showing:
```

**What you'll see:**
```
MQTT Receiver Service

[15:33:15 INF] Starting MQTT Receiver Service
[15:33:16 INF] MQTT Receiver started at: 10/06/2025 22:33:16 +00:00
[15:33:16 INF] Auto-reload enabled - checking for config changes every 30s
[15:33:17 INF] Loaded 2 receiver configuration(s)
[15:33:17 INF]   - PressureSensors: Topic='sensor/+/pressure', Mappings=1
[15:33:17 INF]   - TemperatureSensors: Topic='sensor/+/temperature', Mappings=3
[15:33:17 INF] Connected to MQTT broker
[15:33:17 INF] Subscribed to topic: 'sensor/+/pressure' (QoS: AtLeastOnce)
[15:33:17 INF] Subscribed to topic: 'sensor/+/temperature' (QoS: AtLeastOnce)

====================================
[15:33:35 INF] RECEIVED MQTT MESSAGE
[15:33:35 INF] Topic: sensor/device1/temperature
[15:33:35 INF] Payload: {"device_id":"device1","sensor_type":"temperature","value":85.0,"unit":"F"}
====================================
[15:33:35 INF] Processing message with config: TemperatureSensors
[15:33:35 INF] ✓ Inserted into dbo.RawSensorData
[15:33:35 INF] ✓ Inserted into dbo.SensorAlerts
[15:33:35 INF] ✓ Executed stored procedure dbo.UpdateSensorAggregate
[15:33:35 INF] Message processed successfully to 3 table(s)
```

**Key Things to Watch For:**
- ✅ Connection to MQTT broker
- ✅ Topic subscriptions (with wildcards)
- ✅ Message reception with full JSON payload
- ✅ One-to-many routing (1 message → 3 tables)
- ✅ Success indicators for each table

---

### Window 3: Publisher Service (Top Right) - OUTBOUND TRAFFIC
**Purpose:** Shows database change detection and MQTT publishing

**How to start:**
```powershell
# From Window 1 (Orchestrator):
.\demo.ps1 -Action start-publisher

# This will open a NEW window automatically showing:
```

**What you'll see:**
```
MQTT Publisher Service

[15:35:10 INF] Starting MQTT Multi-Table Publisher
[15:35:10 INF] Connected to MQTT broker at localhost:1883
[15:35:10 INF] Loaded 3 table monitor(s):
[15:35:10 INF]   - ProductUpdates: dbo.Products (ChangeTracking)
[15:35:10 INF]   - OrderNotifications: dbo.Orders (ChangeTracking)
[15:35:10 INF]   - InventoryAlerts: dbo.Inventory (ChangeTracking)
[15:35:10 INF] Starting change detection loop...

[15:36:15 INF] Detected 1 change(s) in dbo.Products
[15:36:15 INF] Publishing to topic: products/updates
[15:36:15 INF] Payload: {"ProductId":101,"Name":"Widget","Price":29.99,"UpdatedAt":"2025-10-06T22:36:15Z"}
[15:36:15 INF] ✓ Published successfully (QoS: AtLeastOnce)
```

**Key Things to Watch For:**
- ✅ Connection to MQTT broker
- ✅ Table monitoring configuration
- ✅ Change detection (polling every N seconds)
- ✅ JSON payload generation
- ✅ MQTT topic publishing
- ✅ Success confirmation

---

### Window 4: Database Query Window (Bottom Right) - DATA VERIFICATION
**Purpose:** Live database queries to verify data flow

**How to start:**
```powershell
# Open a new PowerShell window:
cd D:\dev2\clients\mbox\mqtt-send

# Or use SQL Server Management Studio / Azure Data Studio
```

**Useful Queries:**
```sql
-- Watch raw sensor data (from Receiver)
SELECT TOP 5 * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;

-- Watch sensor alerts (filtered messages)
SELECT * FROM dbo.SensorAlerts ORDER BY AlertTime DESC;

-- Watch aggregates (stored procedure results)
SELECT * FROM dbo.SensorAggregates ORDER BY LastReading DESC;

-- Watch published messages (from Publisher)
SELECT TOP 5 * FROM MQTT.PublishedMessages ORDER BY PublishedAt DESC;

-- Monitor receiver message log
SELECT TOP 5 Topic, Status, TargetTablesProcessed, ReceivedAt
FROM MQTT.ReceivedMessages
ORDER BY ReceivedAt DESC;

-- Live count refresh (run repeatedly)
SELECT
    (SELECT COUNT(*) FROM dbo.RawSensorData) AS RawSensorData,
    (SELECT COUNT(*) FROM dbo.SensorAlerts) AS SensorAlerts,
    (SELECT COUNT(*) FROM dbo.SensorAggregates) AS SensorAggregates;
```

---

## Demo Script: Complete Walkthrough

### Phase 1: Setup (2 minutes)

**Window 1 (Orchestrator):**
```powershell
# 1. Show current status
.\demo.ps1

# 2. Clear any old test data
.\demo.ps1 -Action clear-data
```

**Expected Output:**
```
[OK] Test data cleared
```

---

### Phase 2: Start Services (1 minute)

**Window 1 (Orchestrator):**
```powershell
# 3. Start Receiver (opens Window 2)
.\demo.ps1 -Action start-receiver

# Wait 3 seconds for initialization

# 4. Start Publisher (opens Window 3)
.\demo.ps1 -Action start-publisher
```

**Window 2 (Receiver) - Watch For:**
```
[INF] Connected to MQTT broker
[INF] Subscribed to topic: 'sensor/+/temperature'
[INF] Subscribed to topic: 'sensor/+/pressure'
```

**Window 3 (Publisher) - Watch For:**
```
[INF] Connected to MQTT broker at localhost:1883
[INF] Loaded 3 table monitor(s)
```

---

### Phase 3: Demonstrate Receiver (MQTT → Database) (3 minutes)

**Narration:**
> "Let's demonstrate the **Receiver** first - it listens to MQTT topics and routes messages to multiple database tables based on configuration."

**Window 1 (Orchestrator):**
```powershell
# 5. Send test messages
.\demo.ps1 -Action send-test
```

**What Happens:**

**Window 1 shows:**
```
[Test 1: Normal Temperature (70F)]
[OK] Sent: 70F to sensor/device1/temperature

[Test 2: High Temperature Alert (85F)]
[OK] Sent: 85F to sensor/device1/temperature (should trigger alert)

[Test 3: Very High Temperature (90F)]
[OK] Sent: 90F to sensor/device1/temperature (high alert)

[Test 4: Pressure Sensor (101.3 kPa)]
[OK] Sent: 101.3 kPa to sensor/device2/pressure
```

**Window 2 (Receiver) shows in REAL-TIME:**
```
====================================
RECEIVED MQTT MESSAGE
Topic: sensor/device1/temperature
Payload: {"device_id":"device1","value":70.0...}
====================================
Processing message with config: TemperatureSensors
✓ Inserted into dbo.RawSensorData
✓ Executed stored procedure dbo.UpdateSensorAggregate
Message processed successfully to 2 table(s)

====================================
RECEIVED MQTT MESSAGE
Topic: sensor/device1/temperature
Payload: {"device_id":"device1","value":85.0...}
====================================
Processing message with config: TemperatureSensors
✓ Inserted into dbo.RawSensorData
✓ Inserted into dbo.SensorAlerts        ← HIGH TEMP ALERT!
✓ Executed stored procedure dbo.UpdateSensorAggregate
Message processed successfully to 3 table(s)
```

**Window 4 (Database) - Run Query:**
```sql
-- See the results immediately
SELECT * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;
-- Shows 4 rows (all messages)

SELECT * FROM dbo.SensorAlerts;
-- Shows 2 rows (Value > 75: 85F and 90F)

SELECT * FROM dbo.SensorAggregates;
-- Shows 1 row: Avg=81.67, Min=70, Max=90, Count=3
```

**Key Points to Highlight:**
1. ✅ **One-to-Many Routing** - Single message goes to 3 tables
2. ✅ **Conditional Filtering** - Only high temps (>75) go to SensorAlerts
3. ✅ **Stored Procedure** - Real-time statistics calculated automatically
4. ✅ **Topic Wildcards** - `sensor/+/temperature` matches any device

---

### Phase 4: Demonstrate Publisher (Database → MQTT) (3 minutes)

**Narration:**
> "Now let's demonstrate the **Publisher** - it monitors database tables for changes and publishes them to MQTT."

**Window 4 (Database) - Insert New Data:**
```sql
-- Simulate a product update
INSERT INTO dbo.Products (ProductId, Name, Price, Category, UpdatedAt)
VALUES (201, 'Super Widget', 49.99, 'Electronics', GETUTCDATE());

-- Or update existing
UPDATE dbo.Products
SET Price = 39.99, UpdatedAt = GETUTCDATE()
WHERE ProductId = 101;
```

**Window 3 (Publisher) shows in REAL-TIME:**
```
[15:38:22 INF] Detected 1 change(s) in dbo.Products
[15:38:22 INF] Change Type: Insert
[15:38:22 INF] Publishing to topic: products/updates
[15:38:22 INF] Payload: {
  "ProductId": 201,
  "Name": "Super Widget",
  "Price": 49.99,
  "Category": "Electronics",
  "UpdatedAt": "2025-10-06T22:38:22Z"
}
[15:38:22 INF] ✓ Published successfully (QoS: AtLeastOnce)
```

**Window 2 (Receiver) - IF Subscribed to products/updates:**
```
====================================
RECEIVED MQTT MESSAGE
Topic: products/updates
Payload: {"ProductId":201,"Name":"Super Widget"...}
====================================
```

**Key Points to Highlight:**
1. ✅ **Change Detection** - Automatic polling of database changes
2. ✅ **Multi-Table Support** - Can monitor multiple tables simultaneously
3. ✅ **JSON Payload** - Automatic serialization
4. ✅ **Bidirectional** - Can create a feedback loop (DB → MQTT → DB)

---

### Phase 5: View Results (2 minutes)

**Window 1 (Orchestrator):**
```powershell
# 6. Show comprehensive results
.\demo.ps1 -Action view-data
```

**Expected Output:**
```
========================================
 Database Contents
========================================

[Raw Sensor Data (All Messages)]
Id | DeviceId | SensorType   | Value   | Unit | Timestamp
---|----------|--------------|---------|------|----------
 4 | device1  | temperature  | 90.0000 | F    | 2025-10-06 22:35:00
 3 | device2  | pressure     | 101.3   | kPa  | 2025-10-06 22:30:10
 2 | device1  | temperature  | 70.0000 | F    | 2025-10-06 22:30:05
 1 | device1  | temperature  | 85.0000 | F    | 2025-10-06 22:30:00

[Sensor Alerts (High Temperature)]
Id | DeviceId | Value   | Threshold | AlertTime
---|----------|---------|-----------|----------
 2 | device1  | 90.0000 | 75.0      | 2025-10-06 22:35:00
 1 | device1  | 85.0000 | 75.0      | 2025-10-06 22:30:00

[Sensor Aggregates (Hourly Stats)]
DeviceId | SensorType  | AvgValue | MinValue | MaxValue | ReadingCount
---------|-------------|----------|----------|----------|-------------
device1  | temperature | 81.6667  | 70.0000  | 90.0000  | 3

[Summary Counts]
RawSensorData: 4
SensorAlerts: 2
SensorAggregates: 1
```

---

### Phase 6: Configuration Change Demo (Advanced - Optional) (2 minutes)

**Narration:**
> "The Receiver can auto-reload configuration changes without restart!"

**Window 4 (Database) - Add New Topic:**
```sql
-- Add a new topic configuration
DECLARE @NewConfigId INT;

INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, MessageFormat, FieldMappingJson, QoS, Enabled)
VALUES (
    'HumiditySensors',
    'sensor/+/humidity',
    'JSON',
    '{"DeviceId": "$.device_id", "Value": "$.value", "Unit": "$.unit"}',
    1,
    1
);

SET @NewConfigId = SCOPE_IDENTITY();

-- Add table mapping
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetSchema, TargetTable, InsertMode, Priority, Enabled)
VALUES (@NewConfigId, 'dbo', 'RawSensorData', 'Direct', 100, 1);
```

**Window 2 (Receiver) - Watch for Auto-Reload (within 30 seconds):**
```
[15:39:15 INF] Configuration change detected (3 configs)
[15:39:15 INF] Unsubscribing from all current topics...
[15:39:15 INF] Reloading configuration from database...
[15:39:15 INF] Loaded 3 receiver configuration(s)
[15:39:15 INF]   - HumiditySensors: Topic='sensor/+/humidity', Mappings=1    ← NEW!
[15:39:15 INF]   - PressureSensors: Topic='sensor/+/pressure', Mappings=1
[15:39:15 INF]   - TemperatureSensors: Topic='sensor/+/temperature', Mappings=3
[15:39:15 INF] Subscribing to topics...
[15:39:15 INF] Subscribed to topic: 'sensor/+/humidity' (QoS: AtLeastOnce)   ← NEW!
[15:39:15 INF] Subscribed to topic: 'sensor/+/pressure' (QoS: AtLeastOnce)
[15:39:15 INF] Subscribed to topic: 'sensor/+/temperature' (QoS: AtLeastOnce)
```

**Test the new topic:**
```powershell
# Window 1:
docker exec mosquitto sh -c 'mosquitto_pub -t "sensor/device1/humidity" -m "{\"device_id\":\"device1\",\"value\":65.5,\"unit\":\"%\"}" -q 1'
```

**Window 2 shows:**
```
RECEIVED MQTT MESSAGE
Topic: sensor/device1/humidity    ← NEW TOPIC!
Payload: {"device_id":"device1","value":65.5,"unit":"%"}
✓ Inserted into dbo.RawSensorData
```

---

### Phase 7: Cleanup (30 seconds)

**Window 1 (Orchestrator):**
```powershell
# 7. Stop all services
.\demo.ps1 -Action stop-all
```

**Expected Output:**
```
========================================
 Stopping All Services
========================================
[INFO] Stopping receiver processes...
[OK] Receiver stopped
[INFO] Stopping publisher processes...
[OK] Publisher stopped
[OK] All services stopped
```

**Windows 2 & 3 close automatically or show:**
```
Application is shutting down...
```

---

## Window Layout Recommendations

### Recommended Screen Layout (Wide Monitor):
```
┌────────────────────┬────────────────────┐
│  Window 2          │  Window 3          │
│  RECEIVER          │  PUBLISHER         │
│  (MQTT → DB)       │  (DB → MQTT)       │
│                    │                    │
│  Real-time logs    │  Real-time logs    │
│  Message routing   │  Change detection  │
├────────────────────┼────────────────────┤
│  Window 1          │  Window 4          │
│  ORCHESTRATOR      │  DATABASE          │
│  (Control Center)  │  (SQL Queries)     │
│                    │                    │
│  Commands & Status │  Data Verification │
└────────────────────┴────────────────────┘
```

### For Presentations (Projector):
- **Primary Screen:** Windows 2 & 3 (Receiver & Publisher) - MAXIMIZED
- **Secondary Screen:** Windows 1 & 4 (Control & Database)

---

## Narration Script for Stakeholders

### Introduction (30 seconds)
> "This is a **bidirectional MQTT bridge** that connects SQL Server with MQTT messaging. Let me show you how it works with 4 windows demonstrating different components."

### Window Overview (30 seconds)
> - "**Window 1** (bottom left) is our control center for running commands"
> - "**Window 2** (top left) shows the Receiver - MQTT messages flowing INTO the database"
> - "**Window 3** (top right) shows the Publisher - database changes flowing OUT to MQTT"
> - "**Window 4** (bottom right) shows live database queries to verify the data"

### Receiver Demo (2 minutes)
> "Let's start with the Receiver. I'll send 4 test MQTT messages from different IoT sensors..."
>
> [Run send-test command]
>
> "Watch Window 2 - you'll see each message arrive, get parsed, and routed to multiple database tables simultaneously. Notice that message #2 with 85 degrees triggers an alert because it's over our 75-degree threshold."
>
> [Point to Window 4]
>
> "And here in the database, we can see all the data - 4 raw readings, 2 alerts, and real-time statistics calculated by a stored procedure."

### Publisher Demo (2 minutes)
> "Now let's demonstrate the other direction - database to MQTT. I'll insert a new product record..."
>
> [Run SQL INSERT]
>
> "Watch Window 3 - the Publisher detected the database change within seconds and published it to MQTT automatically. Any system subscribed to that MQTT topic would receive this update in real-time."

### Key Features (1 minute)
> "Key features to note:"
> - "**One-to-Many Routing** - each message can go to multiple tables"
> - "**Database-Driven** - all configuration is in SQL Server, no code changes needed"
> - "**Auto-Reload** - configuration changes are detected automatically within 30 seconds"
> - "**Bidirectional** - both publish and subscribe capabilities"

---

## Troubleshooting During Demo

### If Receiver doesn't show messages:
1. Check Window 2 for "Subscribed to topic" confirmations
2. Verify MQTT broker: `docker ps | grep mosquitto`
3. Check connection string in appsettings.json

### If Publisher doesn't detect changes:
1. Ensure change tracking is enabled on the table
2. Check polling interval (default: 5 seconds)
3. Verify MQTT connection in Window 3 logs

### If orchestrator commands fail:
1. Run `.\demo.ps1` to check status
2. Use `.\demo.ps1 -Action stop-all` to clean up
3. Restart services individually

---

## Quick Reference Commands

```powershell
# Setup
.\demo.ps1 -Action init-db          # One-time database setup
.\demo.ps1 -Action clear-data       # Clear test data

# Run Demo
.\demo.ps1 -Action start-receiver   # Opens Window 2
.\demo.ps1 -Action start-publisher  # Opens Window 3
.\demo.ps1 -Action send-test        # Send test messages
.\demo.ps1 -Action view-data        # Show all data

# Cleanup
.\demo.ps1 -Action stop-all         # Stop everything

# Full Automated Demo
.\demo.ps1 -Action full-demo        # Complete workflow
```

---

## Success Criteria

After a successful demo, you should see:
- ✅ All 4 windows running smoothly
- ✅ Receiver logging message receptions in real-time
- ✅ Publisher logging database change detections
- ✅ Database showing data in multiple tables
- ✅ No error messages in any window
- ✅ Stakeholders understanding bidirectional data flow

---

## Next Steps After Demo

1. **Customize Topics** - Add your own MQTT topic configurations
2. **Add Tables** - Configure additional database tables for monitoring
3. **Production Deploy** - Move to Azure Container Apps or Kubernetes
4. **Scale Up** - Add multiple instances for high availability
5. **Monitoring** - Add Application Insights or Prometheus metrics
