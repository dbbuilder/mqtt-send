# MQTT Bridge System - Demo Guide

## 🎯 System Overview

Database-driven MQTT bridge with:
- **Multi-table publisher** (auto-detects new tables every 30s)
- **Monitor-based routing** (each subscriber receives only their monitor's data)
- **Zero-downtime configuration** changes

---

## 📋 Prerequisites

Ensure all services are running:
```powershell
# Check Docker containers
docker ps

# Should see:
# - sqlserver (running)
# - mosquitto (running)
```

---

## 🚀 Demo Steps

### Step 1: Start the Publisher

```powershell
# Terminal 1
.\run-multi-table-publisher.ps1
```

**Expected Output:**
```
Configuration loaded - Enabled sources: 3
  - TableA: TableA (100 batch, 2s interval)
  - TableB: TableB (100 batch, 2s interval)
  - TableC: TableC (100 batch, 2s interval)
Connected to MQTT broker at localhost:1883
```

---

### Step 2: Start Subscriber 1 (Monitor 1)

**First, stop any running subscribers (Ctrl+C), then rebuild:**
```powershell
dotnet build src/SubscriberService/SubscriberService.csproj --configuration Release
```

```powershell
# Terminal 2
.\start-subscriber-1.ps1
```

**Expected Output:**
```
Monitor Filter: 1
Subscribed to topic: data/+/1
```

---

### Step 3: Start Subscriber 2 (Monitor 2)

```powershell
# Terminal 3
.\start-subscriber-2.ps1
```

**Expected Output:**
```
Monitor Filter: 2
Subscribed to topic: data/+/2
```

---

### Step 4: Add Demo Records

```powershell
# Terminal 4
.\add-demo-records.ps1
```

This adds:
- 2 TableA records (1 for Monitor 1, 1 for Monitor 2)
- 2 TableB records (1 for Monitor 1, 1 for Monitor 2)
- 2 TableC records (1 for Monitor 1, 1 for Monitor 2)

---

### Step 5: Watch the Routing! 🎉

**Within 2 seconds:**

**Subscriber 1 (Monitor 1)** will show:
```
====================================
RECEIVED MESSAGE
Table: tableA | MonitorId: 1
Topic: data/tableA/1
Payload: {"RecordId":XX,"MonitorId":"1","SensorType":"temperature","Value":22.5,...}
====================================

>>> PARSING COMPLETE RECORD <<<
  Record ID: XX
  Monitor ID: 1
  Sensor Type: temperature
  Value: 22.5
  Unit: C
  Location: Monitor1-Demo-TableA
  Source Table: TableA
------------------------------------
```

(And similar messages for TableB and TableC)

**Subscriber 2 (Monitor 2)** will show:
```
====================================
RECEIVED MESSAGE
Table: tableA | MonitorId: 2
Topic: data/tableA/2
Payload: {"RecordId":XX,"MonitorId":"2","SensorType":"temperature","Value":24.8,...}
====================================

>>> PARSING COMPLETE RECORD <<<
  Record ID: XX
  Monitor ID: 2
  Sensor Type: temperature
  Value: 24.8
  Unit: C
  Location: Monitor2-Demo-TableA
  Source Table: TableA
------------------------------------
```

(And similar messages for TableB and TableC)

---

## 🔄 Auto-Restart Demo (Optional)

### Add TableD Dynamically

```powershell
# Terminal 4
.\test-add-new-table.ps1
```

**Publisher will auto-detect within 30 seconds:**
```
[WARN] Configuration change detected: 3 sources -> 4 sources
[INFO] Reloading configuration...
[INFO] Configuration loaded - Enabled sources: 4
  - TableA: TableA (100 batch, 2s interval)
  - TableB: TableB (100 batch, 2s interval)
  - TableC: TableC (100 batch, 2s interval)
  - TableD: TableD (100 batch, 2s interval)  ← NEW!

[INFO] [TableD] Processing 30 unsent records
[INFO] [TableD] Batch complete - Success: 30, Failures: 0
```

### Remove TableD

```powershell
# Terminal 4
.\test-add-new-table.ps1 -Reset
```

**Publisher will auto-detect:**
```
[WARN] Configuration change detected: 4 sources -> 3 sources
[INFO] Reloading configuration...
```

---

## ✅ What This Demonstrates

1. **Database-Driven Config** - All table mappings in SQL, no code changes
2. **Monitor Routing** - Each subscriber receives only their monitor's data
3. **Multi-Table Support** - Publishes from TableA, TableB, TableC simultaneously
4. **Auto-Restart** - Detects new tables and reloads without manual restart
5. **Topic-Based Filtering** - MQTT wildcards (`data/+/1`) route messages correctly
6. **Duplicate Prevention** - Records marked as sent in `MQTT.SentRecords`

---

## 📊 Architecture

```
┌─────────────────┐
│  SQL Database   │
│  ─────────────  │
│  TableA (temp)  │──┐
│  TableB (press) │──┼──> ┌──────────────┐      ┌─────────────┐
│  TableC (flow)  │──┘    │  Publisher   │─────>│   Mosquitto │
│                 │       │  (polling)   │      │  MQTT Broker│
│  MQTT.Config    │──────>│              │      └──────┬──────┘
│  MQTT.SentRec   │<──────└──────────────┘             │
└─────────────────┘                                    │
                                              ┌────────┴────────┐
                                              │                 │
                                        ┌─────▼─────┐   ┌──────▼──────┐
                                        │  Sub 1    │   │   Sub 2     │
                                        │ Monitor 1 │   │  Monitor 2  │
                                        │ (data/+/1)│   │ (data/+/2)  │
                                        └───────────┘   └─────────────┘
```

---

## 🛠️ Troubleshooting

**Subscribers show "file locked" error when rebuilding?**
- Stop all subscribers (Ctrl+C in each terminal)
- Run: `dotnet build src/SubscriberService/SubscriberService.csproj --configuration Release`
- Restart subscribers

**No messages appearing?**
- Check publisher is running
- Verify subscribers show "Subscribed to topic: data/+/X"
- Add fresh records with `.\add-demo-records.ps1`

**Publisher not auto-restarting?**
- Wait 30 seconds after config changes
- Check logs for "Configuration change detected"
