# High-Scale Multi-Table MQTT Bridge Architecture

## Scale Requirements

- **10,000 monitors**
- **5+ source tables** (can grow to e,f,g next week)
- **Multiple updates per minute per table**
- **Estimated throughput:** 50,000+ messages/minute
- **Zero duplicates** - track what's been sent
- **Near real-time** - sub-second latency preferred

---

## Architecture Overview

```
┌─────────────────┐
│  Source Tables  │
│  (A, B, C, D)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│   Tracking Table                 │
│   MqttSentRecords               │
│   (SourceTable, RecordId, SentAt)│
└────────┬────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│   Publisher Service (Parallel)   │
│   - One publisher per table      │
│   - Or partitioned by MonitorId  │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│   MQTT Broker (Mosquitto 2.0)    │
│   - Topic: data/{table}/{monitor}│
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│   Subscriber Services            │
│   - Filter by MonitorId or Table │
└──────────────────────────────────┘
```

---

## Key Design Decisions

### 1. **Tracking Strategy: Separate Tracking Table**

**DO NOT** update source tables (avoids write contention on high-volume tables).

**Use dedicated tracking table:**

```sql
CREATE TABLE MqttSentRecords (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceTable NVARCHAR(100) NOT NULL,
    RecordId NVARCHAR(100) NOT NULL,
    SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CorrelationId UNIQUEIDENTIFIER,
    Topic NVARCHAR(500),

    INDEX IX_Source_Record UNIQUE (SourceTable, RecordId),
    INDEX IX_SentAt (SentAt) -- For cleanup/archival
);
```

**Benefits:**
- ✅ No locks on source tables
- ✅ Fast lookups (indexed)
- ✅ Easy cleanup/archival
- ✅ Works with read-only source tables

---

### 2. **Query Pattern: LEFT JOIN Anti-Pattern**

Find unsent records efficiently:

```sql
-- For Table A
SELECT TOP 5000 a.*
FROM TableA a
LEFT JOIN MqttSentRecords m
    ON m.SourceTable = 'TableA'
    AND m.RecordId = a.PrimaryKeyColumn
WHERE m.Id IS NULL  -- Not yet sent
ORDER BY a.CreatedAt ASC;
```

**Performance:**
- Batch size: 1000-5000 per query
- Index on `(SourceTable, RecordId)` is critical
- Consider partitioning MqttSentRecords by SourceTable

---

### 3. **Parallel Publisher Architecture**

#### Option A: One Publisher Per Table (Simple)
```
Publisher-TableA (5000 batch)
Publisher-TableB (5000 batch)
Publisher-TableC (5000 batch)
Publisher-TableD (5000 batch)
Publisher-TableE (5000 batch)
```

**Pros:** Simple, isolated failures
**Cons:** Limited parallelism

#### Option B: Partitioned Publishers (Recommended for 10k monitors)
```
Publisher-TableA-P1 (MonitorId 0000-1999)
Publisher-TableA-P2 (MonitorId 2000-3999)
Publisher-TableA-P3 (MonitorId 4000-5999)
...
```

**Pros:** Massive parallelism, horizontal scaling
**Cons:** More complex

#### Option C: Worker Pool
```
┌─────────────┐
│ Work Queue  │ → Worker 1
│ (Table+ID)  │ → Worker 2
│             │ → Worker 3
└─────────────┘   ...Worker N
```

**Pros:** Dynamic scaling, load balancing
**Cons:** Requires queue infrastructure

---

### 4. **Configuration for Multi-Table Sources**

**config/source-tables-scale.json:**

```json
{
  "sources": [
    {
      "name": "TableA",
      "enabled": true,
      "tableName": "TableA",
      "schema": "dbo",
      "parallel_publishers": 5,
      "partition_column": "MonitorId",

      "tracking": {
        "method": "tracking_table",
        "trackingTable": "MqttSentRecords"
      },

      "query": {
        "primaryKey": "RecordId",
        "monitorIdColumn": "MonitorId",
        "batchSize": 5000,
        "pollingIntervalMs": 100
      },

      "mqtt": {
        "topicPattern": "data/tableA/{MonitorId}",
        "qos": 1,
        "retain": false
      },

      "fieldMapping": {
        "RecordId": "id",
        "MonitorId": "monitor",
        "Value": "value",
        "Timestamp": "timestamp"
      }
    }
  ],

  "performance": {
    "max_concurrent_publishers": 25,
    "connection_pool_size": 50,
    "mqtt_publish_timeout_ms": 5000,
    "enable_batching": true,
    "batch_publish_size": 100
  }
}
```

---

### 5. **SQL Server Optimizations**

#### Indexes
```sql
-- On each source table
CREATE INDEX IX_CreatedAt ON TableA(CreatedAt);
CREATE INDEX IX_MonitorId ON TableA(MonitorId);

-- On tracking table (critical!)
CREATE UNIQUE INDEX IX_Source_Record ON MqttSentRecords(SourceTable, RecordId);
CREATE INDEX IX_SentAt ON MqttSentRecords(SentAt) INCLUDE (SourceTable);
```

#### Partitioning (for very large tables)
```sql
-- Partition MqttSentRecords by SourceTable
CREATE PARTITION FUNCTION PF_SourceTable (NVARCHAR(100))
AS RANGE RIGHT FOR VALUES ('TableA', 'TableB', 'TableC', 'TableD', 'TableE');
```

#### Read Committed Snapshot Isolation
```sql
-- Reduce locking
ALTER DATABASE MqttBridge SET READ_COMMITTED_SNAPSHOT ON;
```

---

### 6. **Alternative: SQL Server Change Tracking**

For **true real-time** (no polling delay):

```sql
-- Enable on database
ALTER DATABASE MqttBridge SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);

-- Enable on each table
ALTER TABLE TableA ENABLE CHANGE_TRACKING;
ALTER TABLE TableB ENABLE CHANGE_TRACKING;
```

**Publisher Service** then uses:
```sql
SELECT t.*, ct.SYS_CHANGE_VERSION
FROM TableA t
RIGHT JOIN CHANGETABLE(CHANGES TableA, @last_sync_version) ct
    ON t.RecordId = ct.RecordId
WHERE ct.SYS_CHANGE_OPERATION IN ('I', 'U');
```

**Pros:**
- ✅ Real-time (no polling)
- ✅ Only queries changed rows
- ✅ Built-in SQL Server feature

**Cons:**
- ❌ More complex
- ❌ Requires SQL Server Standard/Enterprise

---

## Deployment Architectures

### Small Scale (< 1000 monitors)
```
1 Publisher instance
5 parallel threads (one per table)
Polling every 1 second
Batch size: 1000
```

### Medium Scale (1000-10,000 monitors)
```
5 Publisher instances (one per table)
Each with 5 parallel workers
Polling every 100ms
Batch size: 5000
Connection pool: 50
```

### Large Scale (10,000+ monitors)
```
25 Publisher instances (5 tables x 5 partitions)
Each processing 1/5 of monitors
Polling every 100ms or use Change Tracking
Batch size: 5000
Consider message queue (RabbitMQ) as buffer
```

---

## Monitoring & Metrics

### Critical Metrics
- **Messages/second** per table
- **Lag** (time from insert to MQTT publish)
- **Tracking table size** (archival needed?)
- **Failed publishes** (retry queue depth)
- **Connection pool utilization**

### Logging
```csharp
_logger.LogInformation(
    "Published batch - Table: {Table}, Records: {Count}, Lag: {LagMs}ms, Duration: {DurationMs}ms",
    tableName, recordCount, avgLag, duration);
```

### Alerting
- Lag > 5 seconds
- Failed publish rate > 1%
- Tracking table > 10M rows (cleanup needed)

---

## Adding New Tables Dynamically

### Week 1: Tables A, B, C, D
```json
{
  "sources": [
    {"name": "TableA", "enabled": true, ...},
    {"name": "TableB", "enabled": true, ...},
    {"name": "TableC", "enabled": true, ...},
    {"name": "TableD", "enabled": true, ...}
  ]
}
```

### Week 2: Add Tables E, F, G
```powershell
# Run interactive script
.\add-source-table.ps1

# Or edit config directly and add:
```

```json
{
  "sources": [
    ...existing...,
    {"name": "TableE", "enabled": true, ...},
    {"name": "TableF", "enabled": true, ...},
    {"name": "TableG", "enabled": true, ...}
  ]
}
```

```powershell
# Restart publisher (or hot-reload if supported)
Restart-Service PublisherService
```

**No code changes needed!**

---

## Cleanup & Archival

### Archive Old Tracking Records
```sql
-- Archive records older than 7 days
DELETE TOP (100000) FROM MqttSentRecords
WHERE SentAt < DATEADD(DAY, -7, GETUTCDATE());
```

### Scheduled Job
```sql
CREATE PROCEDURE sp_CleanupMqttTracking
AS
BEGIN
    WHILE 1=1
    BEGIN
        DELETE TOP (10000) FROM MqttSentRecords
        WHERE SentAt < DATEADD(DAY, -7, GETUTCDATE());

        IF @@ROWCOUNT < 10000 BREAK;
        WAITFOR DELAY '00:00:01';
    END
END

-- Schedule via SQL Agent (daily at 2 AM)
```

---

## Performance Benchmarks (Target)

| Scale | Tables | Monitors | Msg/Min | Lag Target | Publishers |
|-------|--------|----------|---------|------------|------------|
| Small | 3 | 100 | 1,500 | < 1s | 1 |
| Medium | 5 | 1,000 | 25,000 | < 2s | 5 |
| Large | 5 | 10,000 | 250,000 | < 5s | 25 |
| XL | 10 | 50,000 | 1,000,000 | < 10s | 100 |

---

## Next Steps

1. ✅ Create `MqttSentRecords` tracking table
2. ✅ Configure source tables in `source-tables.json`
3. ✅ Deploy parallel publishers (start with 1 per table)
4. ✅ Monitor lag and throughput
5. ✅ Scale horizontally as needed (add partitioned publishers)
6. ✅ Consider Change Tracking for sub-second latency
7. ✅ Implement archival job for tracking table

**The system is now designed to handle 10,000+ monitors across unlimited tables with minimal latency!** 🚀
