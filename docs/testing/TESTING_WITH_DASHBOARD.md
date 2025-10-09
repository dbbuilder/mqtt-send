# Testing the MQTT Bridge with Dashboard Buttons

## 🎯 Interactive Testing - No Scripts Needed!

The dashboard now has **built-in test buttons** - no need to run PowerShell scripts anymore!

---

## 🚀 Start the System

```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\Start-System-Safe.ps1
```

**What happens:**
1. ✅ Stops any existing services (ensures clean rebuild)
2. ✅ Checks Docker is running
3. ✅ Waits for SQL Server to be healthy
4. ✅ Starts Mosquitto
5. ✅ Builds all services fresh
6. ✅ Starts Publisher, Receiver, Dashboard
7. ✅ Opens http://localhost:5000

---

## 🧪 Testing with Dashboard Buttons

### Section 1: Send Test Messages (MQTT → Database)

**Location:** Top section, left column "Send Test Messages (MQTT)"

#### Button 1: Normal Temp (72°F)
**Click:** Blue "Normal Temp (72°F)" button

**What it does:**
1. Dashboard sends MQTT message to topic: `test/temperature/TEST1`
2. Payload: `{"MonitorId":"TEST1", "SensorType":"temperature", "Value":72.5, "Unit":"F", ...}`
3. Receiver (if configured for `test/` topics) picks it up
4. Stores in RawSensorData

**Where to see results:**
- **Dashboard:** Live Message Flow (bottom) → Blue "RECEIVED" badge appears
- **Database:**
  ```sql
  SELECT TOP 5 * FROM dbo.RawSensorData
  WHERE DeviceId = 'TEST1' AND SensorType = 'temperature'
  ORDER BY ReceivedAt DESC;
  ```

#### Button 2: High Temp (85°F - Alert)
**Click:** Yellow "High Temp (85°F - Alert)" button

**What it does:**
- Same as Button 1 but with value = 85.0°F
- Tests high-temperature scenarios

#### Button 3: Pressure (101.3 kPa)
**Click:** Teal "Pressure (101.3 kPa)" button

**What it does:**
- Sends pressure sensor data
- Topic: `test/pressure/TEST1`
- Payload: `{"MonitorId":"TEST1", "SensorType":"pressure", "Value":101.3, "Unit":"kPa", ...}`

---

### Section 2: Trigger Publisher Events (Database → MQTT)

**Location:** Top section, middle column "Trigger Publisher Events"

#### Button 1: Publish from TableA
**Click:** Green "Publish from TableA" button

**What it does:**
1. Dashboard inserts random data into `dbo.TableA` (MonitorId 1 or 2)
2. Publisher polls TableA every 2 seconds
3. Publisher finds new record and publishes to MQTT (`data/tableA/1` or `data/tableA/2`)
4. Receiver (if configured) receives and stores in RawSensorData

**Where to see results:**
- **Dashboard status:** "✓ Inserted test data into TableA" → "Publisher will pick this up in ~2 seconds..."
- **Dashboard Live Flow (after 2 seconds):**
  - Red "PUBLISHED" badge → `data/tableA/1` or `data/tableA/2`
  - Blue "RECEIVED" badge → same topic received
- **Database:**
  ```sql
  -- Check inserted data
  SELECT TOP 5 * FROM dbo.TableA ORDER BY CreatedAt DESC;

  -- Check published
  SELECT TOP 5 * FROM MQTT.SentRecords
  WHERE SourceName = 'TableA'
  ORDER BY SentAt DESC;

  -- Check received
  SELECT TOP 5 * FROM MQTT.ReceivedMessages
  WHERE Topic LIKE 'data/tableA%'
  ORDER BY ReceivedAt DESC;

  -- Check final destination
  SELECT TOP 5 * FROM dbo.RawSensorData
  WHERE SensorType = 'temperature'
  ORDER BY ReceivedAt DESC;
  ```

#### Buttons 2 & 3: Publish from TableB / TableC
**Same as TableA** but for pressure (TableB) and flow (TableC)

---

### Section 3: Bulk Operations

**Location:** Top section, right column "Bulk Operations"

#### Button 1: Send 5 Random Messages
**Click:** Gray "Send 5 Random Messages" button

**What it does:**
- Sends 5 random MQTT messages
- Mix of temperature and pressure
- Random values: 70-90°F or 100-105 kPa
- Topics: `test/temperature/TEST1`, `test/pressure/TEST2`, etc.
- 100ms delay between messages

**Where to see results:**
- **Dashboard status:** "✓ Sent 5/5 messages successfully"
- **Dashboard Live Flow:** Multiple blue "RECEIVED" badges appear
- **Database:**
  ```sql
  SELECT COUNT(*) FROM dbo.RawSensorData
  WHERE DeviceId IN ('TEST1', 'TEST2');
  ```

#### Button 2: Send 10 Random Messages
**Same as Button 1** but sends 10 messages

---

## 📊 Where to See the Results

### 1. Dashboard - Real-Time (http://localhost:5000)

**System Overview (top cards):**
- Publisher: ONLINE, 3 tables monitored
- Receiver: ONLINE, 3 subscriptions active

**Statistics:**
- Messages sent today / total
- Messages received today / total

**Live Message Flow (bottom section):**
- **Red "PUBLISHED" badges** → Database → MQTT
  - Example: `[17:03:45] PUBLISHED data/tableA/1 | TableA → TableA`
- **Blue "RECEIVED" badges** → MQTT → Database
  - Example: `[17:03:46] RECEIVED data/tableA/1 | Success → 1 tables`

---

### 2. Database - SQL Queries

#### Check the Full Round Trip

```sql
-- Step 1: Data inserted into source table
SELECT TOP 5 RecordId, MonitorId, Temperature, Location, Timestamp
FROM dbo.TableA
ORDER BY CreatedAt DESC;

-- Step 2: Published to MQTT
SELECT TOP 5 Id, SourceName, Topic, SentAt
FROM MQTT.SentRecords
WHERE SourceName = 'TableA'
ORDER BY SentAt DESC;

-- Step 3: Received from MQTT
SELECT TOP 5 Id, Topic, Status, TargetTablesProcessed, ReceivedAt
FROM MQTT.ReceivedMessages
WHERE Topic LIKE 'data/tableA%'
ORDER BY ReceivedAt DESC;

-- Step 4: Final destination
SELECT TOP 5 DeviceId, SensorType, Value, Unit, ReceivedAt
FROM dbo.RawSensorData
WHERE SensorType = 'temperature'
ORDER BY ReceivedAt DESC;
```

#### Check Application Logs

```sql
-- All logs
SELECT TOP 20
    CONVERT(VARCHAR, Timestamp, 120) as Time,
    ServiceName,
    Level,
    Message
FROM Logging.ApplicationLogs
ORDER BY Timestamp DESC;

-- Only errors
SELECT TOP 20 *
FROM Logging.ErrorSummary
ORDER BY Timestamp DESC;
```

---

## 🔬 Testing Scenarios

### Scenario 1: Test Receiver Only (MQTT → DB)

**Steps:**
1. Click **"Normal Temp (72°F)"** button
2. Wait 1-2 seconds
3. Check **Dashboard Live Flow** → Should see blue "RECEIVED" badge
4. Run SQL:
   ```sql
   SELECT TOP 5 * FROM dbo.RawSensorData
   WHERE DeviceId = 'TEST1'
   ORDER BY ReceivedAt DESC;
   ```

**Expected:** New row with temperature = 72.5°F

---

### Scenario 2: Test Publisher Only (DB → MQTT)

**Steps:**
1. Click **"Publish from TableA"** button
2. Dashboard shows: "✓ Inserted test data into TableA"
3. Wait 2-3 seconds (publisher polls every 2 seconds)
4. Check **Dashboard Live Flow** → Should see red "PUBLISHED" badge

**Expected:** Message published to `data/tableA/1` or `data/tableA/2`

---

### Scenario 3: Test Full Round Trip (DB → MQTT → DB)

**Steps:**
1. Click **"Publish from TableA"** button
2. Dashboard status: "✓ Inserted test data into TableA"
3. Wait 2-3 seconds
4. Check **Dashboard Live Flow**:
   - First: Red "PUBLISHED" badge appears
   - Then: Blue "RECEIVED" badge appears (same topic)
5. Run SQL to verify full flow:
   ```sql
   -- Check all steps succeeded
   DECLARE @LatestSent DATETIME2 = (SELECT MAX(SentAt) FROM MQTT.SentRecords WHERE SourceName = 'TableA');
   DECLARE @LatestReceived DATETIME2 = (SELECT MAX(ReceivedAt) FROM MQTT.ReceivedMessages WHERE Topic LIKE 'data/tableA%');

   SELECT
       'Published' as Step,
       CONVERT(VARCHAR, @LatestSent, 120) as Timestamp
   UNION ALL
   SELECT
       'Received' as Step,
       CONVERT(VARCHAR, @LatestReceived, 120) as Timestamp
   UNION ALL
   SELECT
       'In RawSensorData' as Step,
       CONVERT(VARCHAR, MAX(ReceivedAt), 120) as Timestamp
   FROM dbo.RawSensorData
   WHERE ReceivedAt >= @LatestSent;
   ```

**Expected:** All 3 steps have timestamps within 5 seconds of each other

---

### Scenario 4: Stress Test with Bulk Messages

**Steps:**
1. Click **"Send 10 Random Messages"** button
2. Wait for completion: "✓ Sent 10/10 messages successfully"
3. Check Dashboard Live Flow → Should see 10 blue "RECEIVED" badges
4. Run SQL:
   ```sql
   SELECT
       SensorType,
       COUNT(*) as MessageCount,
       AVG(Value) as AvgValue,
       MIN(ReceivedAt) as FirstReceived,
       MAX(ReceivedAt) as LastReceived
   FROM dbo.RawSensorData
   WHERE DeviceId IN ('TEST1', 'TEST2')
       AND ReceivedAt >= DATEADD(MINUTE, -1, GETUTCDATE())
   GROUP BY SensorType;
   ```

**Expected:**
- ~5 temperature readings, ~5 pressure readings
- All received within last minute

---

## 🎯 Success Criteria

✅ **Receiver Working:**
- Click "Normal Temp" → Blue "RECEIVED" appears in Live Flow
- SQL: New row in `RawSensorData`

✅ **Publisher Working:**
- Click "Publish from TableA" → Red "PUBLISHED" appears after 2 seconds
- SQL: New row in `SentRecords`

✅ **Bidirectional Flow Working:**
- Click "Publish from TableA" → Red "PUBLISHED" + Blue "RECEIVED" appear
- SQL: New rows in `TableA`, `SentRecords`, `ReceivedMessages`, `RawSensorData`

✅ **Logging Working:**
- SQL: `Logging.ApplicationLogs` has entries from all 3 services
- Dashboard actions appear in logs

✅ **Real-Time Updates:**
- Dashboard updates every 5 seconds automatically
- No need to refresh browser

---

## 🐛 Troubleshooting

### "Test button clicked but nothing happens"

**Check:**
1. Open browser console (F12) → any JavaScript errors?
2. Check if dashboard is connected to SignalR:
   - Dashboard should say "Connected to SignalR hub"
3. Verify services are running:
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -match "ReceiverService|PublisherService|MonitorDashboard"}
   ```

### "RECEIVED badge never appears"

**Receiver might not be subscribed to test topics.**

**Fix:** Update receiver config to subscribe to `test/#` topics:
```sql
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, MessageFormat, FieldMappingJson, QoS, Enabled)
VALUES (
    'Test_All',
    'test/#',  -- Subscribe to all test topics
    'JSON',
    '{"DeviceId": "$.MonitorId", "SensorType": "$.SensorType", "Value": "$.Temperature", "Unit": "$.Unit"}',
    1,
    1
);

-- Add table mapping
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, TargetSchema, ColumnMappingJson, Enabled, InsertMode, Priority)
SELECT
    Id,
    'RawSensorData',
    'dbo',
    '{"DeviceId":"DeviceId","SensorType":"SensorType","Value":"Value","Unit":"Unit"}',
    1,
    'INSERT',
    100
FROM MQTT.ReceiverConfig
WHERE ConfigName = 'Test_All';

-- Restart receiver to pick up new subscription
```

Then restart system:
```powershell
.\Start-System-Safe.ps1
```

### "PUBLISHED badge appears but RECEIVED doesn't"

**Topics might not match.**

**Check publisher sends to topics receiver is subscribed to:**
```sql
-- Publisher topics
SELECT SourceName, TopicPattern FROM MQTT.SourceConfig;

-- Receiver subscriptions
SELECT ConfigName, TopicPattern FROM MQTT.ReceiverConfig;
```

Make sure they overlap! For example:
- Publisher: `data/tableA/{MonitorId}` → publishes to `data/tableA/1`
- Receiver: `data/tableA/+` → subscribes to `data/tableA/*`

✅ These match!

---

## 📝 Summary

**To test the receiver:**
- Click any "Send Test Messages" button (left column)
- Look for blue "RECEIVED" badges

**To test the publisher:**
- Click any "Trigger Publisher Events" button (middle column)
- Wait 2-3 seconds
- Look for red "PUBLISHED" badges

**To test full bidirectional flow:**
- Click "Publish from TableA/B/C"
- See BOTH red "PUBLISHED" and blue "RECEIVED" badges

**All tests visible in:**
- ✅ Dashboard Live Message Flow (real-time)
- ✅ Database queries (permanent record)
- ✅ Application logs (troubleshooting)

**No PowerShell scripts needed!** Everything is in the dashboard. 🎉
