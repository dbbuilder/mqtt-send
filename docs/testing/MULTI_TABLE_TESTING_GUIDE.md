# Multi-Table MQTT Bridge - Testing Guide

## Overview

You now have a **dynamic, scalable multi-table MQTT bridge** that:
- ✅ Reads from **multiple source tables** (A, B, C... unlimited)
- ✅ **Tracks sent records** to prevent duplicates
- ✅ **Dynamically maps fields** from tables to MQTT payloads
- ✅ **Substitutes topic patterns** with actual values
- ✅ **Processes tables in parallel** for high throughput
- ✅ **Configurable via JSON** - add new tables without code changes

---

## Quick Start (5 Minutes)

### Step 1: Setup System

```powershell
powershell -ExecutionPolicy Bypass -File setup-multi-table-system.ps1
```

**What this does:**
- Creates `MqttSentRecords` tracking table
- Creates `TableA`, `TableB`, `TableC` with sample data (50 records each)
- Builds MultiTablePublisher
- Verifies setup

### Step 2: Start Multi-Table Publisher

```powershell
powershell -ExecutionPolicy Bypass -File run-multi-table-publisher.ps1
```

**Expected output:**
```
[12:34:56 INF] Multi-Table Publisher started
[12:34:56 INF] Configuration loaded - Enabled sources: 3, Parallel processing: True
[12:34:56 INF]   - TableA: TableA (100 batch, 2s interval)
[12:34:56 INF]   - TableB: TableB (100 batch, 2s interval)
[12:34:56 INF]   - TableC: TableC (100 batch, 2s interval)
[12:34:56 INF] Connected to MQTT broker
[12:34:57 INF] [TableA] Processing 50 unsent records
[12:34:57 INF] [TableB] Processing 50 unsent records
[12:34:57 INF] [TableC] Processing 50 unsent records
```

### Step 3: Start Subscribers

**Terminal 1 - Monitor All TableA Messages:**
```powershell
cd src\SubscriberService
dotnet run --no-build -- --MonitorFilter "+" --ClientIdSuffix "AllTableA"
```

**Or use MQTT command line:**
```powershell
docker exec mosquitto mosquitto_sub -h localhost -t "data/tableA/#" -v
```

### Step 4: Add More Records

```powershell
# Add 20 records to all tables
powershell -ExecutionPolicy Bypass -File insert-test-records.ps1 -Count 20

# Add records only to TableB
powershell -ExecutionPolicy Bypass -File insert-test-records.ps1 -Count 10 -Table B
```

**Watch the publisher automatically process and publish them!**

---

## Architecture

### Tables Created

| Table | Description | Fields | Sample Topic |
|-------|-------------|--------|--------------|
| **TableA** | Temperature sensors | RecordId, MonitorId, SensorType, Temperature, Unit, Location | `data/tableA/1` |
| **TableB** | Pressure sensors | RecordId, MonitorId, SensorType, Pressure, Unit, Location | `data/tableB/2` |
| **TableC** | Flow sensors | RecordId, MonitorId, SensorType, FlowRate, Unit, Location | `data/tableC/3` |
| **MqttSentRecords** | Tracking table | SourceTable, RecordId, SentAt, CorrelationId | N/A |

### Configuration Structure

**config/source-tables-local.json:**

```json
{
  "sources": [
    {
      "name": "TableA",
      "enabled": true,
      "tableName": "TableA",
      "schema": "dbo",

      "tracking": {
        "method": "tracking_table",
        "trackingTable": "MqttSentRecords"
      },

      "query": {
        "primaryKey": "RecordId",
        "monitorIdColumn": "MonitorId",
        "whereClause": "1=1",
        "orderBy": "CreatedAt ASC",
        "batchSize": 100,
        "pollingIntervalSeconds": 2
      },

      "mqtt": {
        "topicPattern": "data/tableA/{MonitorId}",
        "qos": 1,
        "retain": false
      },

      "fieldMapping": {
        "RecordId": "RecordId",
        "MonitorId": "MonitorId",
        "SensorType": "SensorType",
        "Temperature": "Value",
        "Unit": "Unit",
        "Location": "Location",
        "Timestamp": "Timestamp"
      }
    }
  ],

  "global_settings": {
    "enable_parallel_processing": true,
    "max_concurrent_sources": 3,
    "connection_string": "...",
    "mqtt_broker": "localhost",
    "mqtt_port": 1883
  }
}
```

---

## Adding New Tables (Table D, E, F...)

### Option 1: Interactive Script

```powershell
powershell -ExecutionPolicy Bypass -File add-source-table.ps1
```

### Option 2: Manual SQL + Config

**1. Create table in SQL:**
```sql
CREATE TABLE dbo.TableD (
    RecordId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonitorId NVARCHAR(50) NOT NULL,
    SensorType NVARCHAR(50) NOT NULL,
    CustomValue DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(10) NOT NULL,
    Location NVARCHAR(100) NOT NULL,
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE INDEX IX_TableD_CreatedAt ON dbo.TableD(CreatedAt) INCLUDE (RecordId, MonitorId);
```

**2. Add to config/source-tables-local.json:**
```json
{
  "name": "TableD",
  "enabled": true,
  "tableName": "TableD",
  "schema": "dbo",
  "tracking": {
    "method": "tracking_table",
    "trackingTable": "MqttSentRecords"
  },
  "query": {
    "primaryKey": "RecordId",
    "monitorIdColumn": "MonitorId",
    "whereClause": "1=1",
    "orderBy": "CreatedAt ASC",
    "batchSize": 100,
    "pollingIntervalSeconds": 2
  },
  "mqtt": {
    "topicPattern": "data/tableD/{MonitorId}",
    "qos": 1,
    "retain": false
  },
  "fieldMapping": {
    "RecordId": "RecordId",
    "MonitorId": "MonitorId",
    "SensorType": "SensorType",
    "CustomValue": "Value",
    "Unit": "Unit",
    "Location": "Location",
    "Timestamp": "Timestamp"
  }
}
```

**3. Restart publisher** - it will automatically start processing TableD!

---

## Monitoring & Verification

### Check Unsent Records

```sql
-- TableA unsent
SELECT COUNT(*) AS UnsentRecords
FROM dbo.TableA a
LEFT JOIN dbo.MqttSentRecords m
    ON m.SourceTable = 'TableA'
    AND m.RecordId = CAST(a.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;
```

### Check Sent Records

```sql
-- All sent records
SELECT SourceTable, COUNT(*) AS SentCount
FROM dbo.MqttSentRecords
GROUP BY SourceTable
ORDER BY SourceTable;
```

### Check Throughput

```sql
-- Records sent in last 5 minutes
SELECT
    SourceTable,
    COUNT(*) AS RecordsLast5Min,
    MIN(SentAt) AS FirstSent,
    MAX(SentAt) AS LastSent
FROM dbo.MqttSentRecords
WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY SourceTable;
```

### View Metrics

```sql
SELECT * FROM dbo.vw_MqttBridgeMetrics;
```

---

## Testing Scenarios

### Scenario 1: Verify No Duplicates

```powershell
# Insert 10 records
.\insert-test-records.ps1 -Count 10 -Table A

# Wait for publisher to process (2-3 seconds)
Start-Sleep -Seconds 3

# Check sent count
docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -Q "SELECT COUNT(*) FROM MqttSentRecords WHERE SourceTable = 'TableA'"

# Restart publisher (should not re-send)
# Check count again - should be same!
```

### Scenario 2: High Volume Test

```powershell
# Insert 1000 records continuously
1..10 | ForEach-Object {
    .\insert-test-records.ps1 -Count 100
    Start-Sleep -Seconds 1
}
```

**Monitor lag:**
```sql
SELECT
    SourceTable,
    AVG(DATEDIFF(SECOND, SentAt, GETUTCDATE())) AS AvgLagSeconds,
    MAX(DATEDIFF(SECOND, SentAt, GETUTCDATE())) AS MaxLagSeconds
FROM dbo.MqttSentRecords
WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY SourceTable;
```

### Scenario 3: Parallel Processing

Watch logs to see tables being processed simultaneously:

```
[12:45:01 INF] [TableA] Processing 50 unsent records
[12:45:01 INF] [TableB] Processing 30 unsent records
[12:45:01 INF] [TableC] Processing 25 unsent records
[12:45:02 INF] [TableA] Batch complete - Success: 50, Failures: 0
[12:45:02 INF] [TableB] Batch complete - Success: 30, Failures: 0
[12:45:02 INF] [TableC] Batch complete - Success: 25, Failures: 0
```

---

## Cleanup & Maintenance

### Archive Old Tracking Records

```sql
-- Remove records older than 7 days
EXEC dbo.sp_CleanupMqttTracking @RetentionDays = 7, @BatchSize = 10000;
```

### Reset for Testing

```powershell
# WARNING: Deletes all tracking data
docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -Q "TRUNCATE TABLE MqttSentRecords"

# Now all records will be re-sent when publisher runs
```

---

## Performance Configuration

### Adjust Batch Size

Edit `config/source-tables-local.json`:

```json
{
  "query": {
    "batchSize": 5000  // Increase for higher throughput
  }
}
```

### Adjust Polling Interval

```json
{
  "query": {
    "pollingIntervalSeconds": 1  // Decrease for lower latency
  }
}
```

### Enable/Disable Tables

```json
{
  "name": "TableB",
  "enabled": false  // Temporarily disable TableB
}
```

---

## Troubleshooting

### No Records Being Published

**Check:**
1. Are there unsent records? `SELECT COUNT(*) FROM TableA a LEFT JOIN MqttSentRecords m ON ...`
2. Is the table enabled in config? `"enabled": true`
3. Is the where clause correct? `"whereClause": "1=1"`

### Duplicates Being Sent

**Check:**
- Unique index exists: `SELECT * FROM sys.indexes WHERE name = 'UQ_MqttSentRecords_Source_Record'`
- MarkRecordsSent is working: Check publisher logs for "Marked X records as sent"

### MQTT Messages Not Received

**Check:**
- MQTT client connected: Look for "Connected to MQTT broker" in logs
- Topic pattern correct: `"topicPattern": "data/tableA/{MonitorId}"`
- Subscriber topic matches: `mosquitto_sub -t "data/tableA/#"`

---

## Next Steps

1. ✅ **System is running** - Tables A, B, C publishing to MQTT
2. ✅ **Add more tables** - Use `add-source-table.ps1` or edit config
3. ✅ **Scale up** - Increase batch size, add more parallel publishers
4. ✅ **Production ready** - Enable SQL Server Change Tracking for real-time

**You now have a production-ready, scalable multi-table MQTT bridge!** 🚀
