# MQTT Bridge System - Complete Testing Guide

## Overview

This is the **NEW** testing guide for the database-driven multi-table MQTT Bridge system with tracked tables (TableA, TableB, TableC, TableD).

**Key Features Tested:**
- ✅ Database-driven configuration (MQTT.SourceConfig)
- ✅ Multi-table publishing (unlimited source tables)
- ✅ Duplicate prevention (MQTT.SentRecords tracking)
- ✅ Dynamic field mapping (JSON-based)
- ✅ Topic substitution with placeholders
- ✅ MonitorId-based filtering for subscribers
- ✅ Parallel table processing

---

## Test Scripts Quick Reference

| Script | Purpose |
|--------|---------|
| `test-complete-system.ps1` | **START HERE** - Master test orchestration with setup instructions |
| `verify-system-status.ps1` | Check system health anytime |
| `start-subscriber-1.ps1` | Quick start subscriber for MonitorId=1 |
| `start-subscriber-2.ps1` | Quick start subscriber for MonitorId=2 |
| `start-data-generator.ps1` | Continuous data generation (5 records/10s) |
| `run-multi-table-publisher.ps1` | Start the multi-table publisher |
| `generate-tracked-table-data.ps1` | Flexible data generator (one-time or continuous) |
| `insert-test-records.ps1` | Quick test record insertion |
| `test-add-new-table.ps1` | Demo dynamic table addition (TableD) |
| `verify-tabled-published.ps1` | Verify TableD integration |

---

## Quick Start - Complete System Test

### Step 1: Run Master Test Script
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\test-complete-system.ps1
```

This script will:
- Verify database setup
- Build all projects
- Show startup commands for all components
- Optionally generate initial test data

### Step 2: Open 4 Terminal Windows

**Window 1 - Subscriber for Monitor 1:**
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\start-subscriber-1.ps1
```

**Window 2 - Subscriber for Monitor 2:**
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\start-subscriber-2.ps1
```

**Window 3 - MultiTablePublisher:**
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\run-multi-table-publisher.ps1
```

**Window 4 - Data Generator:**
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\start-data-generator.ps1
```

### Step 3: Verify Operation

**Check system status:**
```powershell
.\verify-system-status.ps1
```

**Watch the output:**
- **Subscriber 1** shows only MonitorId=1 messages
- **Subscriber 2** shows only MonitorId=2 messages
- **Publisher** processes all 3 tables (A, B, C)
- **Generator** creates new records every 10 seconds

---

## Expected Outputs

### Publisher Output
```
=== Starting Multi-Table MQTT Publisher ===

Configuration loaded from database - 3 sources found
Configuration loaded - Enabled sources: 3, Parallel processing: True
  - TableA: TableA (100 batch, 2s interval)
  - TableB: TableB (100 batch, 2s interval)
  - TableC: TableC (100 batch, 2s interval)

[TableA] Found 50 unsent records (MonitorIds: 1,2,3,4,5,6,7,8,9,10)
[TableA] Building query for batch of 50 records
[TableA] Published 50 records to MQTT (topics: data/tableA/1, data/tableA/2, ...)
[TableA] Marked 50 records as sent in database

[TableB] Found 50 unsent records (MonitorIds: 1,2,3,4,5,6,7,8,9,10)
[TableB] Published 50 records to MQTT
[TableB] Marked 50 records as sent in database

[TableC] Found 50 unsent records (MonitorIds: 1,2,3,4,5,6,7,8,9,10)
[TableC] Published 50 records to MQTT
[TableC] Marked 50 records as sent in database
```

### Subscriber 1 Output (MonitorId = 1)
```
Starting Subscriber for MonitorId = 1...

[INFO] Subscriber Worker started at: 10/05/2025 8:45:30 PM +00:00
[INFO] Monitor Filter: 1
[INFO] MQTT ClientId: SubscriberService-Monitor1-12345
[INFO] Initializing MQTT client: SubscriberService-Monitor1-12345
[INFO] Connected to MQTT broker at localhost:1883
[INFO] Subscribed to topics: data/tableA/1, data/tableB/1, data/tableC/1

[INFO] ====================================
[INFO] RECEIVED MESSAGE
[INFO] Topic: data/tableA/1
[INFO] Parsed JSON: {
  "RecordId": 1,
  "MonitorId": "1",
  "SensorType": "temperature",
  "Value": 72.5,
  "Unit": "F",
  "Location": "Building A - Floor 2",
  "Timestamp": "2025-10-05T20:30:00Z",
  "SourceTable": "TableA",
  "ProcessedAt": "2025-10-05T20:35:15Z"
}
[INFO] ====================================
```

### Data Generator Output
```
Starting Continuous Data Generator...
Generates 5 records per table every 10 seconds
Press Ctrl+C to stop

[Iteration 1 - 14:30:00]
  Inserting 5 records into TableA...
    ✓ 5 records inserted into TableA
  Inserting 5 records into TableB...
    ✓ 5 records inserted into TableB
  Inserting 5 records into TableC...
    ✓ 5 records inserted into TableC

[Iteration 2 - 14:30:10]
  Inserting 5 records into TableA...
    ✓ 5 records inserted into TableA
...
```

---

## Test Scenarios

### Scenario 1: End-to-End Basic Flow

**Objective:** Verify complete data flow from database → MQTT → subscribers

**Steps:**
1. Start all 4 components (2 subscribers, publisher, generator)
2. Generate 20 test records:
   ```powershell
   .\generate-tracked-table-data.ps1 -Count 20 -Table "ALL"
   ```
3. Watch publisher process unsent records
4. Watch subscribers receive messages
5. Verify tracking table prevents duplicates

**Verification:**
```sql
-- Check sent records
SELECT SourceName, COUNT(*) AS SentCount
FROM MQTT.SentRecords
GROUP BY SourceName;

-- Should show:
-- TableA: 20
-- TableB: 20
-- TableC: 20
```

**Success Criteria:**
- ✓ Publisher publishes all 60 records (20 × 3 tables)
- ✓ Subscriber 1 receives ~6 messages (MonitorId=1 portion)
- ✓ Subscriber 2 receives ~6 messages (MonitorId=2 portion)
- ✓ Restarting publisher shows "0 unsent records" (no duplicates)

---

### Scenario 2: Dynamic Table Addition

**Objective:** Prove new tables can be added without code changes

**Steps:**
1. Run TableD addition test:
   ```powershell
   .\test-add-new-table.ps1
   ```
2. Restart publisher (Ctrl+C, then `.\run-multi-table-publisher.ps1`)
3. Watch publisher log show "Enabled sources: 4" and process TableD
4. Verify TableD published:
   ```powershell
   .\verify-tabled-published.ps1
   ```

**Success Criteria:**
- ✓ TableD created successfully
- ✓ MQTT.SourceConfig has TableD entry
- ✓ Publisher loads 4 configurations (A, B, C, D)
- ✓ Publisher processes all 30 TableD records
- ✓ Subscribers receive TableD messages on `data/tableD/{MonitorId}` topic

---

### Scenario 3: Continuous Real-Time Processing

**Objective:** Verify system handles continuous data flow

**Steps:**
1. Start all components
2. Start continuous generator:
   ```powershell
   .\start-data-generator.ps1
   ```
3. Let run for 2-3 minutes
4. Check metrics:
   ```sql
   SELECT
       SourceName,
       COUNT(*) AS RecordsSent,
       DATEDIFF(SECOND, MIN(SentAt), MAX(SentAt)) AS Duration,
       COUNT(*) * 1.0 / NULLIF(DATEDIFF(SECOND, MIN(SentAt), MAX(SentAt)), 0) AS RecordsPerSecond
   FROM MQTT.SentRecords
   WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
   GROUP BY SourceName;
   ```

**Success Criteria:**
- ✓ Publisher processes records within 2-5 seconds of insertion
- ✓ Subscribers receive messages in real-time
- ✓ No errors or disconnections
- ✓ Throughput > 50 records/second

---

### Scenario 4: High Volume Batch Test

**Objective:** Test system with large data volumes

**Steps:**
1. Generate large batch:
   ```powershell
   .\generate-tracked-table-data.ps1 -Count 5000 -Table "ALL"
   ```
2. Start publisher if not running
3. Monitor processing time
4. Verify all records published:
   ```sql
   SELECT
       'TableA' AS SourceName,
       (SELECT COUNT(*) FROM dbo.TableA) AS TotalRecords,
       (SELECT COUNT(*) FROM MQTT.SentRecords WHERE SourceName = 'TableA') AS SentRecords;
   ```

**Success Criteria:**
- ✓ All 15,000 records (5000 × 3 tables) published
- ✓ Publisher processes in batches of 100 (default)
- ✓ No errors in publisher logs
- ✓ Subscribers remain connected throughout
- ✓ Database throughput > 100 records/second

---

### Scenario 5: Monitor Filtering

**Objective:** Verify subscribers only receive their monitor's messages

**Steps:**
1. Start Subscriber 1 (MonitorId=1) and Subscriber 2 (MonitorId=2)
2. Generate records with specific MonitorIds:
   ```sql
   INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location)
   VALUES
       ('1', 'temperature', 70.0, 'F', 'Test Location'),
       ('2', 'temperature', 71.0, 'F', 'Test Location'),
       ('3', 'temperature', 72.0, 'F', 'Test Location');
   ```
3. Watch subscriber outputs

**Success Criteria:**
- ✓ Subscriber 1 receives ONLY MonitorId=1 message
- ✓ Subscriber 2 receives ONLY MonitorId=2 message
- ✓ Neither receives MonitorId=3 message
- ✓ Topic patterns match: `data/tableA/1` and `data/tableA/2`

---

## Verification Queries

### System Health Check
```sql
-- Active configurations
SELECT * FROM MQTT.vw_ConfigurationSummary;

-- Recent activity (last 5 minutes)
SELECT
    SourceName,
    COUNT(*) AS RecentRecords,
    MIN(SentAt) AS FirstSent,
    MAX(SentAt) AS LastSent
FROM MQTT.SentRecords
WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY SourceName;

-- Unsent records per table
DECLARE @Results TABLE (SourceName NVARCHAR(100), UnsentCount INT);

INSERT INTO @Results
SELECT 'TableA', COUNT(*)
FROM dbo.TableA a
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableA' AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

INSERT INTO @Results
SELECT 'TableB', COUNT(*)
FROM dbo.TableB b
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableB' AND m.RecordId = CAST(b.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

INSERT INTO @Results
SELECT 'TableC', COUNT(*)
FROM dbo.TableC c
LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableC' AND m.RecordId = CAST(c.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;

SELECT * FROM @Results;
```

### Performance Metrics
```sql
-- Throughput analysis
SELECT
    SourceName,
    COUNT(*) AS TotalSent,
    MIN(SentAt) AS FirstSent,
    MAX(SentAt) AS LastSent,
    DATEDIFF(SECOND, MIN(SentAt), MAX(SentAt)) AS DurationSeconds,
    COUNT(*) * 1.0 / NULLIF(DATEDIFF(SECOND, MIN(SentAt), MAX(SentAt)), 0) AS RecordsPerSecond
FROM MQTT.SentRecords
GROUP BY SourceName;

-- Latency analysis (record creation to MQTT publish)
SELECT
    m.SourceName,
    AVG(DATEDIFF(SECOND, a.CreatedAt, m.SentAt)) AS AvgLatencySeconds,
    MAX(DATEDIFF(SECOND, a.CreatedAt, m.SentAt)) AS MaxLatencySeconds
FROM MQTT.SentRecords m
INNER JOIN dbo.TableA a ON CAST(a.RecordId AS NVARCHAR(100)) = m.RecordId
WHERE m.SourceName = 'TableA'
    AND m.SentAt >= DATEADD(MINUTE, -10, GETUTCDATE())
GROUP BY m.SourceName;
```

### Monitor Distribution
```sql
-- Messages per MonitorId
SELECT
    SUBSTRING(Topic, CHARINDEX('/', Topic, CHARINDEX('/', Topic) + 1) + 1, 10) AS MonitorId,
    COUNT(*) AS MessageCount
FROM MQTT.SentRecords
GROUP BY SUBSTRING(Topic, CHARINDEX('/', Topic, CHARINDEX('/', Topic) + 1) + 1, 10)
ORDER BY MessageCount DESC;
```

---

## Troubleshooting

### Publisher Not Processing Records

**Symptom:** Publisher shows "0 unsent records" but table has data

**Checks:**
1. Verify configuration enabled:
   ```sql
   SELECT Enabled, * FROM MQTT.SourceConfig WHERE SourceName = 'TableA';
   ```

2. Check if records already sent:
   ```sql
   SELECT COUNT(*) FROM MQTT.SentRecords WHERE SourceName = 'TableA';
   ```

3. Check for unsent records:
   ```sql
   SELECT COUNT(*) FROM dbo.TableA a
   LEFT JOIN MQTT.SentRecords m ON m.SourceName = 'TableA' AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
   WHERE m.Id IS NULL;
   ```

**Solution:**
- If `Enabled = 0`: Update to `1` and restart publisher
- If all records sent: Add new test records
- If configuration missing: Run `MQTT.AddSourceConfiguration` stored procedure

### Subscriber Not Receiving Messages

**Symptom:** Subscriber connected but no messages received

**Checks:**
1. Verify MonitorFilter in subscriber output
2. Check topic subscription list
3. Test MQTT broker directly:
   ```powershell
   docker exec mosquitto mosquitto_sub -h localhost -t "data/#" -v
   ```

**Solutions:**
- If filter shows `+`: Check command line parameters
- If topics wrong: Restart subscriber with correct parameters
- If broker issue: Restart mosquitto container

### Duplicate Messages

**Symptom:** Same records published multiple times

**Checks:**
1. Verify unique constraint exists:
   ```sql
   SELECT * FROM sys.indexes
   WHERE object_id = OBJECT_ID('MQTT.SentRecords')
   AND name = 'UQ_SentRecords_Source_Record';
   ```

2. Check for duplicate entries:
   ```sql
   SELECT SourceName, RecordId, COUNT(*) AS DuplicateCount
   FROM MQTT.SentRecords
   GROUP BY SourceName, RecordId
   HAVING COUNT(*) > 1;
   ```

**Solution:**
If constraint missing:
```sql
ALTER TABLE MQTT.SentRecords
ADD CONSTRAINT UQ_SentRecords_Source_Record UNIQUE (SourceName, RecordId);
```

---

## Clean Up / Reset

### Reset Tracking Table (Re-publish All Records)
```sql
-- WARNING: This will cause all records to be re-sent!
TRUNCATE TABLE MQTT.SentRecords;
```

### Delete Test Data
```sql
-- Remove test data from all tables
DELETE FROM dbo.TableA WHERE Location LIKE 'Building%';
DELETE FROM dbo.TableB WHERE Location LIKE 'Building%';
DELETE FROM dbo.TableC WHERE Location LIKE 'Building%';
DELETE FROM MQTT.SentRecords;
```

### Remove TableD
```sql
DELETE FROM MQTT.SourceConfig WHERE SourceName = 'TableD';
DELETE FROM MQTT.SentRecords WHERE SourceName = 'TableD';
DROP TABLE dbo.TableD;
```

---

## Success Criteria Summary

**✅ System is working correctly if:**

1. **Database Configuration**
   - MQTT schema exists with SourceConfig and SentRecords tables
   - All 5 stored procedures created and functioning
   - Sample data loaded in TableA, TableB, TableC

2. **Publisher Service**
   - Loads configurations from MQTT.SourceConfig
   - Connects to MQTT broker successfully
   - Finds unsent records for each enabled table
   - Publishes messages with correct topic patterns
   - Marks records as sent in MQTT.SentRecords
   - Prevents duplicates on subsequent runs

3. **Subscriber Services**
   - Connect with unique ClientIds
   - Subscribe to correct topic patterns
   - Receive only messages for their MonitorId
   - Parse JSON payloads correctly
   - Don't disconnect when multiple instances run

4. **Data Flow**
   - New records detected within polling interval (2s)
   - Messages published to correct MQTT topics
   - Subscribers receive messages in real-time
   - No duplicate deliveries
   - Field mapping applied correctly

5. **Dynamic Configuration**
   - New tables can be added via SQL
   - Publisher picks up new configurations on restart
   - No code changes needed for new tables
   - All features work for dynamically added tables

**Everything database-driven - unlimited tables, zero code changes!** 🚀
