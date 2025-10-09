# Dashboard Interactive Testing Guide

## 🎨 New Improved Layout

The dashboard now has **3 clearly labeled test sections**:

### 1. 🔵 TEST RECEIVER (Left Column - Blue)
**Purpose:** Tests MQTT → Database flow

**Buttons:**
- **Send Temp 72°F** → `test/temperature/TEST1`
- **Send HIGH Temp 85°F** → `test/temperature/TEST1`
- **Send Pressure 101 kPa** → `test/pressure/TEST1`

**What to look for:**
- ✅ Blue "RECEIVED" badge in Live Flow (bottom of page)
- ✅ New row in `RawSensorData` table
- ✅ Receiver message count increases

**How to test:**
1. Click any blue button
2. Watch status message appear
3. Look for blue "RECEIVED" badge in Live Flow section
4. Check statistics on left side increase

---

### 2. 🟢 TEST PUBLISHER (Middle Column - Green)
**Purpose:** Tests Database → MQTT flow

**Buttons:**
- **Insert into TableA** → publishes to `data/tableA/1` or `/2`
- **Insert into TableB** → publishes to `data/tableB/1` or `/2`
- **Insert into TableC** → publishes to `data/tableC/1` or `/2`

**What to look for (after 2-3 seconds):**
- ✅ Red "PUBLISHED" badge in Live Flow
- ✅ New row in `SentRecords` table
- ✅ Publisher message count increases

**How to test:**
1. Click any green button
2. Status shows: "✓ Inserted test data into TableA"
3. **Wait 2-3 seconds** (publisher polls every 2 seconds)
4. Look for red "PUBLISHED" badge
5. If receiver is configured, also see blue "RECEIVED" badge

---

### 3. ⚪ FULL ROUND-TRIP (Right Column - Gray)
**Purpose:** Tests complete bidirectional flow (DB → MQTT → DB)

**Buttons:**
- **Send 5 MQTT Messages** → Tests receiver with 5 messages
- **Send 10 MQTT Messages** → Stress test receiver
- **View Latest Data** → Shows last 5 records from RawSensorData

**What to look for:**
- ✅ Multiple blue "RECEIVED" badges
- ✅ Both red "PUBLISHED" + blue "RECEIVED" for full flow
- ✅ Data flows: TableA → SentRecords → MQTT → ReceivedMessages → RawSensorData

**How to test full round-trip:**
1. Click **"Insert into TableA"** (green button)
2. Wait 3 seconds
3. Should see BOTH:
   - Red "PUBLISHED" badge (publisher sent to MQTT)
   - Blue "RECEIVED" badge (receiver got from MQTT and stored)

---

## 📖 How to Use Instructions (Bottom of Panel)

The dashboard now includes **step-by-step instructions** for each test type:

### Test Receiver (MQTT→DB):
1. Click any blue button
2. Watch for blue "RECEIVED" badge below
3. Check Receiver stats increase

### Test Publisher (DB→MQTT):
1. Click any green button
2. Wait 2-3 seconds
3. Watch for red "PUBLISHED" badge
4. Then blue "RECEIVED" if receiver configured

### Full Round-Trip:
1. Click green "Insert into TableA"
2. See BOTH red + blue badges
3. Verify complete data flow

---

## 🎯 What Each Button Actually Does

### RECEIVER Tests (Blue Buttons)

**"Send Temp 72°F":**
- Dashboard → MQTT broker: Publishes message to `test/temperature/TEST1`
- Payload: `{"MonitorId":"TEST1","SensorType":"temperature","Temperature":72.5,"Unit":"F",...}`
- Receiver → Database: Stores in `RawSensorData` table
- **Result:** Blue badge, Receiver count +1

**"Send HIGH Temp 85°F":**
- Same as above but value = 85.0°F
- **Purpose:** Test alert thresholds (if configured)

**"Send Pressure 101 kPa":**
- Same flow but for pressure sensor
- Topic: `test/pressure/TEST1`
- **Result:** Blue badge, Receiver count +1

---

### PUBLISHER Tests (Green Buttons)

**"Insert into TableA":**
- Dashboard → SQL: `INSERT INTO dbo.TableA (MonitorId, Temperature, ...) VALUES (1 or 2, random, ...)`
- Wait ~2 seconds
- Publisher → SQL: Polls TableA, finds new record
- Publisher → MQTT: Publishes to `data/tableA/1` or `data/tableA/2`
- Receiver → SQL: Receives and stores in `RawSensorData`
- **Result:** Red badge (published), then blue badge (received)

**"Insert into TableB/C":**
- Same flow for TableB (pressure) and TableC (flow)

---

### BULK/UTILITY Tests (Gray Buttons)

**"Send 5/10 MQTT Messages":**
- Sends multiple random temperature/pressure messages
- Topics: `test/temperature/TEST1`, `test/pressure/TEST2`, etc.
- 100ms delay between messages
- **Result:** Multiple blue badges, stress tests receiver

**"View Latest Data":**
- Fetches last 5 records from `RawSensorData`
- Displays in status area
- **Purpose:** Verify data arrived in database

---

## 🔍 Where to See Results

### 1. Dashboard Live Flow (Bottom Section)
**Real-time badges:**
- 🔴 Red = PUBLISHED (Database → MQTT)
- 🔵 Blue = RECEIVED (MQTT → Database)

**Example:**
```
[17:23:45] PUBLISHED data/tableA/1 | TableA → Success
[17:23:46] RECEIVED data/tableA/1 | Success → 1 tables
```

### 2. Dashboard Statistics (Top Cards)
**Receiver card (left):**
- Active subscriptions count
- Messages received today
- Total messages

**Publisher card (right):**
- Tables monitored
- Messages published today
- Total messages

### 3. Status Messages (Below buttons)
**Shows immediate feedback:**
- ✓ Published to test/temperature/TEST1
- ✓ Inserted test data into TableA
- ✓ Sent 5/5 messages successfully

### 4. Database Queries
**Verify in SQL:**
```sql
-- Check received messages
SELECT TOP 5 * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;

-- Check published messages
SELECT TOP 5 * FROM MQTT.SentRecords ORDER BY SentAt DESC;

-- Check receiver activity
SELECT TOP 5 * FROM MQTT.ReceivedMessages ORDER BY ReceivedAt DESC;
```

---

## 🚀 Quick Test Scenarios

### Scenario 1: "Test if Receiver is Working"
1. Click **"Send Temp 72°F"** (blue button)
2. ✅ See blue "RECEIVED" badge
3. ✅ Receiver stats increase

### Scenario 2: "Test if Publisher is Working"
1. Click **"Insert into TableA"** (green button)
2. Wait 2-3 seconds
3. ✅ See red "PUBLISHED" badge

### Scenario 3: "Test Complete Round-Trip"
1. Click **"Insert into TableA"** (green button)
2. Wait 3 seconds
3. ✅ See BOTH red "PUBLISHED" and blue "RECEIVED" badges
4. ✅ Data flows through entire system

### Scenario 4: "Stress Test Receiver"
1. Click **"Send 10 MQTT Messages"** (gray button)
2. ✅ See 10 blue "RECEIVED" badges appear quickly
3. ✅ Receiver handles multiple messages

---

## 📊 Auto-Refresh

**The dashboard automatically updates every 5 seconds:**
- ✅ Statistics refresh
- ✅ Live flow events appear
- ✅ Service status updates
- **No page refresh needed!**

---

## 🎨 Visual Guide

```
┌─────────────────────────────────────────────────────────┐
│          Interactive Testing Panel                      │
├─────────────────┬─────────────────┬─────────────────────┤
│  TEST RECEIVER  │  TEST PUBLISHER │  FULL ROUND-TRIP    │
│  (MQTT → DB)    │  (DB → MQTT)    │  (DB → MQTT → DB)   │
│  ─────────────  │  ─────────────  │  ─────────────────  │
│  🔵 Send Temp   │  🟢 Insert     │  ⚪ Send 5 Msgs     │
│  🔵 Send HIGH   │  🟢 Insert     │  ⚪ Send 10 Msgs    │
│  🔵 Send Press  │  🟢 Insert     │  ⚪ View Data       │
│                 │                 │                      │
│  ✓ Blue badge   │  ✓ Red badge    │  ✓ Both badges     │
│  ✓ RawData +1   │  ✓ Wait 2 sec   │  ✓ Full flow       │
└─────────────────┴─────────────────┴─────────────────────┘
                            ↓
              How to Use Instructions
                            ↓
        [Live Message Flow with badges]
```

---

## ✅ Success Indicators

You know the system is working when:
- ✅ Click blue button → Blue badge appears within 1 second
- ✅ Click green button → Red badge appears after 2-3 seconds
- ✅ Green button → Both red + blue badges appear
- ✅ Statistics increase after each test
- ✅ Status messages show success
- ✅ SQL queries show new data

---

**Now run:** `.\Start-System-Safe.ps1`

Dashboard will open at http://localhost:5000 with all these improvements! 🎉
