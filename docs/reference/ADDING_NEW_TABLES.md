# Adding New Source Tables - Quick Guide

## Scenario: You have Tables A, B, C, D publishing to MQTT. Next week you need to add Tables E, F, G.

---

## One-Time Setup (Already Done)

1. ✅ Create `MqttSentRecords` tracking table
2. ✅ Configure `source-tables.json` with initial tables
3. ✅ Deploy Publisher Service

---

## Adding New Tables (E, F, G) - 5 Minutes

### Step 1: Prepare Database (Per Table)

```sql
-- Run for Table E
USE MqttBridge;

-- Add helpful columns (if not already present)
ALTER TABLE dbo.TableE ADD CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE();

-- Create indexes for fast queries
CREATE INDEX IX_TableE_CreatedAt ON dbo.TableE(CreatedAt)
    INCLUDE (RecordId, MonitorId);

CREATE INDEX IX_TableE_MonitorId ON dbo.TableE(MonitorId);
```

**Repeat for Tables F and G.**

---

### Step 2: Add to Configuration

#### Option A: Interactive Script (Easiest)

```powershell
powershell -ExecutionPolicy Bypass -File add-source-table.ps1
```

Follow prompts:
- Table name: `TableE`
- Schema: `dbo`
- Tracking method: `3` (tracking table)
- Primary key: `RecordId`
- Monitor ID column: `MonitorId`
- WHERE clause: `1=1` (or your filter)
- Topic pattern: `data/tableE/{MonitorId}`
- Field mappings: Map columns to MQTT fields

#### Option B: Edit JSON Directly

Edit `config/source-tables.json`:

```json
{
  "sources": [
    ...existing A, B, C, D...,
    {
      "name": "TableE",
      "enabled": true,
      "tableName": "TableE",
      "schema": "dbo",
      "description": "New table E data",

      "tracking": {
        "method": "tracking_table",
        "trackingTable": "MqttSentRecords"
      },

      "query": {
        "primaryKey": "RecordId",
        "monitorIdColumn": "MonitorId",
        "whereClause": "1=1",
        "orderBy": "CreatedAt ASC",
        "batchSize": 5000
      },

      "mqtt": {
        "topicPattern": "data/tableE/{MonitorId}",
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
  ]
}
```

**Repeat for Tables F and G.**

---

### Step 3: Restart Publisher

```powershell
# Stop existing publisher
powershell -ExecutionPolicy Bypass -File stop-services.ps1

# Or manually
Get-Process -Name "PublisherService" | Stop-Process -Force

# Start with new config
cd src\PublisherService
dotnet run --no-build
```

---

### Step 4: Verify

```powershell
# Check logs - should see new tables being processed
Get-Content src\PublisherService\logs\publisher-*.txt -Tail 50
```

Look for:
```
[INF] Processing TableE - Found 1234 unsent records
[INF] Published 1234 messages from TableE to MQTT
```

---

## For 10,000 Monitors: Parallel Publishers

If you have **10,000 monitors**, run multiple publishers per table:

### config/source-tables.json (with parallelism):

```json
{
  "name": "TableE",
  "parallel_publishers": 5,
  "partition_column": "MonitorId",
  "partition_ranges": [
    {"min": "0000", "max": "1999"},
    {"min": "2000", "max": "3999"},
    {"min": "4000", "max": "5999"},
    {"min": "6000", "max": "7999"},
    {"min": "8000", "max": "9999"}
  ],
  ...
}
```

### Run 5 Publishers for Table E:

```powershell
# Terminal 1
dotnet run -- --SourceTable TableE --Partition 0

# Terminal 2
dotnet run -- --SourceTable TableE --Partition 1

# ... and so on
```

---

## Monitoring New Tables

### Check Unsent Records

```sql
SELECT COUNT(*) AS UnsentRecords
FROM dbo.TableE e
LEFT JOIN dbo.MqttSentRecords m
    ON m.SourceTable = 'TableE'
    AND m.RecordId = CAST(e.RecordId AS NVARCHAR(100))
WHERE m.Id IS NULL;
```

### Check Throughput

```sql
SELECT
    SourceTable,
    COUNT(*) AS SentLast5Min
FROM dbo.MqttSentRecords
WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY SourceTable
ORDER BY SentLast5Min DESC;
```

### Check Lag

```sql
SELECT
    SourceTable,
    AVG(DATEDIFF(SECOND, SentAt, GETUTCDATE())) AS AvgLagSeconds
FROM dbo.MqttSentRecords
WHERE SentAt >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY SourceTable;
```

---

## Cleanup Old Tracking Records

```sql
-- Clean up records older than 7 days
EXEC dbo.CleanupMqttTracking @RetentionDays = 7, @BatchSize = 10000;
```

**Schedule this daily via SQL Agent.**

---

## Summary: Adding Tables E, F, G

| Step | Time | Command |
|------|------|---------|
| 1. Prep Database | 1 min | `sql/PrepareSourceTables.sql` |
| 2. Add to Config | 2 min | `add-source-table.ps1` or edit JSON |
| 3. Restart Publisher | 1 min | `stop-services.ps1` + `dotnet run` |
| 4. Verify | 1 min | Check logs and SQL queries |

**Total: ~5 minutes to add new tables!**

---

## Full Automation Script

Create `add-tables-efg.ps1`:

```powershell
# Add Tables E, F, G automatically

$tables = @('TableE', 'TableF', 'TableG')

foreach ($table in $tables) {
    Write-Host "Adding $table..." -ForegroundColor Cyan

    # Prepare database
    $sql = @"
ALTER TABLE dbo.$table ADD CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE();
CREATE INDEX IX_${table}_CreatedAt ON dbo.$table(CreatedAt) INCLUDE (RecordId, MonitorId);
"@

    $sql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

    # Add to config (manual or scripted JSON manipulation)
    Write-Host "  - Database prepared" -ForegroundColor Green
}

# Restart publisher
Write-Host "Restarting Publisher..." -ForegroundColor Yellow
powershell -ExecutionPolicy Bypass -File stop-services.ps1
Start-Sleep -Seconds 2
cd src\PublisherService
dotnet run --no-build &

Write-Host "Tables E, F, G added successfully!" -ForegroundColor Green
```

---

## Next Week: Adding More Tables

1. Create `add-tables-hij.ps1`
2. Update config with new tables
3. Restart publishers
4. Monitor and scale as needed

**The system is designed for unlimited table growth!** 🚀
