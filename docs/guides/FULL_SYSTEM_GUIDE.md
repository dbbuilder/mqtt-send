# MQTT Bridge Complete System Guide
## End-to-End Bidirectional Flow with Real-Time Monitoring

---

## System Architecture

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────────┐
│   TableA/B/C    │────────>│  Publisher   │────────>│  MQTT Broker    │
│  (Source Data)  │         │   Service    │         │  (Mosquitto)    │
│  MonitorId 1,2  │         │              │         │  Port: 1883     │
└─────────────────┘         └──────────────┘         └────────┬────────┘
                                                               │
      ┌────────────────────────────────────────────────────────┘
      │
      ▼
┌──────────────┐         ┌──────────────┐         ┌─────────────────┐
│  Receiver    │────────>│ RawSensorData│         │   Dashboard     │
│   Service    │         │   (Target)   │         │  localhost:5000 │
└──────────────┘         └──────────────┘         └─────────────────┘
      │
      └────────────> Logging.ApplicationLogs (All Services)
```

### Data Flow

1. **Publisher Flow (Database → MQTT)**
   - Polls `TableA`, `TableB`, `TableC` every 2 seconds
   - Publishes to topics: `data/tableA/{MonitorId}`, `data/tableB/{MonitorId}`, `data/tableC/{MonitorId}`
   - MonitorId values: 1, 2
   - Tracks sent messages in `MQTT.SentRecords`

2. **Receiver Flow (MQTT → Database)**
   - Subscribes to: `data/tableA/+`, `data/tableB/+`, `data/tableC/+`
   - Receives messages published by Publisher
   - Stores in `RawSensorData` table
   - Tracks received messages in `MQTT.ReceivedMessages`

3. **Monitoring Flow**
   - Dashboard queries both `SentRecords` and `ReceivedMessages`
   - Shows real-time statistics, recent messages, and live flow
   - Updates every 5 seconds via SignalR

4. **Logging Flow**
   - All services log to `Logging.ApplicationLogs`
   - Errors, warnings, and information events
   - Queryable via stored procedures

---

## Prerequisites

### Required Software
- ✅ **SQL Server** (localhost,1433) with database `MqttBridge`
- ✅ **Mosquitto MQTT Broker** (localhost:1883)
- ✅ **.NET 9.0 SDK** (for ReceiverService, MonitorDashboard)
- ✅ **.NET 6.0 SDK** (for PublisherService)
- ✅ **PowerShell** (for orchestration scripts)

### Database Setup
All required database objects are already created:
- ✅ `MQTT.SourceConfig` - Publisher configurations (3 sources)
- ✅ `MQTT.ReceiverConfig` - Receiver subscriptions (3 configs)
- ✅ `MQTT.TopicTableMapping` - Routing rules (3 mappings)
- ✅ `MQTT.SentRecords` - Publisher tracking
- ✅ `MQTT.ReceivedMessages` - Receiver tracking
- ✅ `Logging.ApplicationLogs` - Centralized logging
- ✅ `dbo.TableA`, `dbo.TableB`, `dbo.TableC` - Source data
- ✅ `dbo.RawSensorData` - Destination data

---

## Quick Start (Recommended)

### Option 1: Using the Full System Script

```powershell
# Navigate to project directory
cd D:\dev2\clients\mbox\mqtt-send

# Check current status
.\Start-FullSystem.ps1 -Action status

# Start all services
.\Start-FullSystem.ps1 -Action start

# Open dashboard (automatic)
# http://localhost:5000

# Test data flow
.\Start-FullSystem.ps1 -Action test

# View logs
.\Start-FullSystem.ps1 -Action logs

# Stop all services
.\Start-FullSystem.ps1 -Action stop

# Restart everything
.\Start-FullSystem.ps1 -Action restart
```

**What the script does:**
1. ✅ Checks MQTT Broker is running
2. ✅ Builds all three services
3. ✅ Starts Publisher (in new window)
4. ✅ Starts Receiver (in new window)
5. ✅ Starts Dashboard (in new window)
6. ✅ Opens browser to dashboard
7. ✅ Shows system status

---

## Manual Setup (Step-by-Step)

### Step 1: Start MQTT Broker

```powershell
# In Terminal 1
mosquitto -c mosquitto.conf -v
```

**Verify:** You should see:
```
[INFO] mosquitto version 2.x starting
[INFO] Opening ipv4 listen socket on port 1883
```

---

### Step 2: Stop All Running Services

```powershell
# Stop old processes to allow rebuild
Get-Process | Where-Object {$_.ProcessName -match "ReceiverService|PublisherService|MonitorDashboard|MultiTablePublisher"} | Stop-Process -Force
```

---

### Step 3: Build All Services

```powershell
cd D:\dev2\clients\mbox\mqtt-send

# Build Receiver
dotnet build src/ReceiverService/ReceiverService.csproj --configuration Release

# Build Publisher
dotnet build src/MultiTablePublisher/MultiTablePublisher.csproj --configuration Release

# Build Dashboard
dotnet build src/MonitorDashboard/MonitorDashboard.csproj --configuration Release
```

**Verify:** All builds should complete without errors.

---

### Step 4: Start Publisher Service

```powershell
# In Terminal 2
cd D:\dev2\clients\mbox\mqtt-send
dotnet run --project src/MultiTablePublisher/MultiTablePublisher.csproj --configuration Release --no-build
```

**Expected Output:**
```
[INFO] Starting Publisher Service
[INFO] Connected to MQTT broker at localhost:1883
[INFO] Monitoring 3 tables: TableA, TableB, TableC
[INFO] Published to data/tableA/1
[INFO] Published to data/tableA/2
[INFO] Published to data/tableB/1
...
```

**What it does:**
- Connects to localhost:1883 MQTT broker
- Every 2 seconds:
  - Reads new records from TableA/B/C (MonitorId 1 or 2)
  - Publishes to `data/tableA/1`, `data/tableA/2`, etc.
  - Logs to `MQTT.SentRecords`
  - Logs to `Logging.ApplicationLogs`

---

### Step 5: Start Receiver Service

```powershell
# In Terminal 3
cd D:\dev2\clients\mbox\mqtt-send
dotnet run --project src/ReceiverService/ReceiverService.csproj --configuration Release --no-build
```

**Expected Output:**
```
[INFO] Starting MQTT Receiver Service
[INFO] Connected to MQTT broker at localhost:1883
[INFO] Subscribed to: data/tableA/+
[INFO] Subscribed to: data/tableB/+
[INFO] Subscribed to: data/tableC/+
[INFO] Message received on topic: data/tableA/1
[INFO] Inserted into RawSensorData
...
```

**What it does:**
- Connects to localhost:1883 MQTT broker
- Subscribes to 3 topics: `data/tableA/+`, `data/tableB/+`, `data/tableC/+`
- Receives messages from Publisher
- Parses JSON payload
- Inserts into `RawSensorData`
- Logs to `MQTT.ReceivedMessages`
- Logs to `Logging.ApplicationLogs`

---

### Step 6: Start Monitor Dashboard

```powershell
# In Terminal 4
cd D:\dev2\clients\mbox\mqtt-send
dotnet run --project src/MonitorDashboard/MonitorDashboard.csproj --configuration Release --no-build --urls http://localhost:5000
```

**Expected Output:**
```
[INFO] Starting Monitor Dashboard
[INFO] Now listening on: http://localhost:5000
[INFO] Application started. Press Ctrl+C to shut down.
```

**Open Browser:**
```
http://localhost:5000
```

**What you'll see:**
- **System Overview**: Receiver/Publisher connection status
- **Publisher Section**:
  - 3 table monitors (TableA, TableB, TableC)
  - Recent publications
  - Statistics (messages sent today)
- **Receiver Section**:
  - 3 active subscriptions (data/tableA/+, data/tableB/+, data/tableC/+)
  - Recent received messages
  - Statistics (messages received today)
- **Live Message Flow**:
  - Red "PUBLISHED" badges (DB → MQTT)
  - Blue "RECEIVED" badges (MQTT → DB)
  - Real-time updates every 5 seconds

---

## Verification Steps

### 1. Verify Publisher is Sending

```sql
-- Check recent sent messages
SELECT TOP 10
    CONVERT(VARCHAR, SentAt, 120) as SentAt,
    SourceName,
    Topic,
    RecordId
FROM MQTT.SentRecords
ORDER BY SentAt DESC;
```

**Expected Result:** New rows appearing every 2 seconds (when new data exists in TableA/B/C)

---

### 2. Verify Receiver is Receiving

```sql
-- Check received messages
SELECT TOP 10
    CONVERT(VARCHAR, ReceivedAt, 120) as ReceivedAt,
    Topic,
    Status,
    TargetTablesProcessed
FROM MQTT.ReceivedMessages
ORDER BY ReceivedAt DESC;
```

**Expected Result:** New rows appearing as Publisher sends messages

---

### 3. Verify Data in RawSensorData

```sql
-- Check destination table
SELECT TOP 10
    CONVERT(VARCHAR, ReceivedAt, 120) as ReceivedAt,
    DeviceId,
    SensorType,
    Value,
    Unit
FROM dbo.RawSensorData
ORDER BY ReceivedAt DESC;
```

**Expected Result:** Data from TableA/B/C now in RawSensorData with DeviceId = MonitorId

---

### 4. Verify Logging

```sql
-- Check application logs
SELECT TOP 20
    CONVERT(VARCHAR, Timestamp, 120) as Time,
    ServiceName,
    Level,
    Message
FROM Logging.ApplicationLogs
ORDER BY Timestamp DESC;
```

**Expected Result:** Logs from ReceiverService, PublisherService, MonitorDashboard

---

### 5. Verify Dashboard

1. Open **http://localhost:5000**
2. Check **Publisher Status**:
   - Should show "ONLINE" with green badge
   - 3 tables monitored
   - Recent publications list populated
3. Check **Receiver Status**:
   - Should show "ONLINE" with green badge
   - 3 subscriptions active
   - Recent messages list populated
4. Check **Live Message Flow**:
   - Should show both PUBLISHED (red) and RECEIVED (blue) events
   - Updates automatically every 5 seconds

---

## Testing the Full Flow

### Test 1: Add New Source Data

```sql
-- Insert new data into TableA
INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location, Timestamp)
VALUES (1, 'temperature', 75.5, 'F', 'Test Location', GETUTCDATE());
```

**Watch:**
1. **Publisher console**: "Published to data/tableA/1"
2. **Receiver console**: "Message received on topic: data/tableA/1"
3. **Dashboard**: New "PUBLISHED" event, then new "RECEIVED" event
4. **RawSensorData table**: New row appears

**Expected Timeline:**
- T+0s: Insert into TableA
- T+2s: Publisher picks up and publishes
- T+2.1s: Receiver gets message and inserts into RawSensorData
- T+5s: Dashboard shows both events

---

### Test 2: Verify Error Logging

```sql
-- Insert invalid data (will cause receiver error if DeviceId is required)
-- Then check logs
SELECT TOP 10 *
FROM Logging.ApplicationLogs
WHERE Level IN ('Error', 'Warning')
ORDER BY Timestamp DESC;
```

---

## Monitoring Commands

### Check System Status

```powershell
.\Start-FullSystem.ps1 -Action status
```

Shows:
- MQTT Broker status
- Publisher status
- Receiver status
- Dashboard status
- Message counts from database

---

### Check Data Flow

```powershell
.\Start-FullSystem.ps1 -Action test
```

Shows:
- Recent published messages
- Recent received messages
- Recent RawSensorData records

---

### View Logs

```powershell
.\Start-FullSystem.ps1 -Action logs
```

Shows last 20 log entries from all services

---

## Troubleshooting

### Problem: Receiver shows 0 messages

**Solution:**
1. Check Receiver is subscribed to correct topics:
   ```sql
   SELECT ConfigName, TopicPattern, Enabled FROM MQTT.ReceiverConfig;
   ```
   Should show: `data/tableA/+`, `data/tableB/+`, `data/tableC/+`

2. Check Publisher is using correct topics:
   ```sql
   SELECT SourceName, TopicPattern, Enabled FROM MQTT.SourceConfig;
   ```
   Should show: `data/tableA/{MonitorId}`, etc.

3. Restart Receiver to pick up new subscriptions:
   ```powershell
   .\Start-FullSystem.ps1 -Action restart
   ```

---

### Problem: Dashboard shows all services OFFLINE

**Solution:**
1. Check services are actually running:
   ```powershell
   .\Start-FullSystem.ps1 -Action status
   ```

2. Check database connection string in:
   - `src/ReceiverService/appsettings.json`
   - `src/PublisherService/appsettings.json`
   - `src/MonitorDashboard/appsettings.json`

3. All should point to: `Server=localhost,1433;Database=MqttBridge;...`

---

### Problem: MQTT Broker connection failed

**Solution:**
1. Start Mosquitto:
   ```powershell
   mosquitto -c mosquitto.conf -v
   ```

2. Check port 1883 is listening:
   ```powershell
   netstat -ano | findstr ":1883"
   ```

3. Check firewall allows localhost connections

---

### Problem: Build errors "file is locked"

**Solution:**
1. Stop all services first:
   ```powershell
   .\Start-FullSystem.ps1 -Action stop
   ```

2. Then rebuild:
   ```powershell
   dotnet build src/ReceiverService/ReceiverService.csproj --configuration Release
   dotnet build src/MultiTablePublisher/MultiTablePublisher.csproj --configuration Release
   dotnet build src/MonitorDashboard/MonitorDashboard.csproj --configuration Release
   ```

---

## Architecture Details

### Publisher Configuration (MQTT.SourceConfig)

| SourceName | TopicPattern | MonitorIdColumn | PollingInterval |
|------------|--------------|-----------------|-----------------|
| TableA | data/tableA/{MonitorId} | MonitorId | 2 seconds |
| TableB | data/tableB/{MonitorId} | MonitorId | 2 seconds |
| TableC | data/tableC/{MonitorId} | MonitorId | 2 seconds |

### Receiver Configuration (MQTT.ReceiverConfig)

| ConfigName | TopicPattern | TargetTable | Enabled |
|------------|--------------|-------------|---------|
| TableA_Data | data/tableA/+ | RawSensorData | Yes |
| TableB_Data | data/tableB/+ | RawSensorData | Yes |
| TableC_Data | data/tableC/+ | RawSensorData | Yes |

### Field Mappings

**Publisher JSON Payload:**
```json
{
  "RecordId": 123,
  "MonitorId": 1,
  "SensorType": "temperature",
  "Temperature": 75.5,  // or Pressure, FlowRate
  "Unit": "F",
  "Location": "Building A",
  "Timestamp": "2025-10-06T08:00:00"
}
```

**Receiver Field Mapping (to RawSensorData):**
```json
{
  "DeviceId": "$.MonitorId",
  "SensorType": "$.SensorType",
  "Value": "$.Temperature",  // or $.Pressure, $.FlowRate
  "Unit": "$.Unit",
  "Timestamp": "$.Timestamp"
}
```

---

## Performance Notes

- **Publisher**: Checks for new data every 2 seconds
- **Receiver**: Processes messages instantly upon receipt
- **Dashboard**: Updates UI every 5 seconds via SignalR
- **Logging**: Batches log writes every 5 seconds (50 per batch)

---

## Next Steps

1. ✅ **Start the system**: `.\Start-FullSystem.ps1 -Action start`
2. ✅ **Open dashboard**: http://localhost:5000
3. ✅ **Insert test data**: Add rows to TableA/B/C with MonitorId 1 or 2
4. ✅ **Watch the flow**: See PUBLISHED → RECEIVED in dashboard
5. ✅ **Check logs**: `.\Start-FullSystem.ps1 -Action logs`
6. ✅ **Verify data**: Query RawSensorData for received records

---

## Summary

You now have a complete bidirectional MQTT bridge system:

✅ **Publisher**: TableA/B/C → MQTT (data/tableA/1, data/tableA/2, etc.)
✅ **Receiver**: MQTT → RawSensorData
✅ **Dashboard**: Real-time monitoring at http://localhost:5000
✅ **Logging**: All events in Logging.ApplicationLogs
✅ **Tracking**: Full audit trail in SentRecords & ReceivedMessages

**The complete round trip:**
1. Insert data into TableA (MonitorId = 1)
2. Publisher reads and publishes to `data/tableA/1`
3. Receiver subscribes to `data/tableA/+` and receives
4. Receiver inserts into RawSensorData
5. Dashboard shows both PUBLISHED and RECEIVED events
6. All activity logged to database

Enjoy your fully functional MQTT Bridge system! 🎉
