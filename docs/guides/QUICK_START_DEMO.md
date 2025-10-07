# Quick Start: Multi-Window Demo

## Pre-Demo Checklist (5 minutes)

### ✅ Prerequisites
- [ ] SQL Server running on `localhost:1433`
- [ ] Docker Desktop running
- [ ] Mosquitto container running: `docker ps | grep mosquitto`
- [ ] .NET 9.0 SDK installed
- [ ] PowerShell 5.1+ available

### ✅ Database Setup (First Time Only)
```powershell
cd D:\dev2\clients\mbox\mqtt-send
.\demo.ps1 -Action init-db
```

---

## 3-Minute Demo Setup

### Step 1: Clear Previous Data (10 seconds)
```powershell
# Window 1: Orchestrator
.\demo.ps1 -Action clear-data
```

### Step 2: Start Receiver (10 seconds)
```powershell
# Window 1: This opens Window 2 automatically
.\demo.ps1 -Action start-receiver
```

**Wait for Window 2 to show:**
```
[INF] Connected to MQTT broker
[INF] Subscribed to topic: 'sensor/+/temperature'
[INF] Subscribed to topic: 'sensor/+/pressure'
```

### Step 3: Start Publisher (10 seconds)
```powershell
# Window 1: This opens Window 3 automatically
.\demo.ps1 -Action start-publisher
```

**Wait for Window 3 to show:**
```
[INF] Connected to MQTT broker at localhost:1883
[INF] Loaded 3 table monitor(s)
```

### Step 4: Send Test Messages (5 seconds)
```powershell
# Window 1:
.\demo.ps1 -Action send-test
```

**Watch Window 2 for real-time message processing!**

### Step 5: View Results (5 seconds)
```powershell
# Window 1:
.\demo.ps1 -Action view-data
```

---

## Recommended Window Positions

### 4-Window Layout (Wide Monitor):
```
+--------------------------------+--------------------------------+
|  WINDOW 2: Receiver            |  WINDOW 3: Publisher          |
|  (Top Left - 50% width)        |  (Top Right - 50% width)      |
|                                |                                |
|  MQTT → Database               |  Database → MQTT              |
|  Real-time message logs        |  Real-time change detection   |
+--------------------------------+--------------------------------+
|  WINDOW 1: Orchestrator        |  WINDOW 4: SQL Query          |
|  (Bottom Left - 50% width)     |  (Bottom Right - 50% width)   |
|                                |                                |
|  Control Center                |  Data Verification            |
|  Commands & Status             |  Live Queries                 |
+--------------------------------+--------------------------------+
```

### Keyboard Shortcuts for Window Arrangement (Windows 11):
- `Win + Left Arrow` - Snap left
- `Win + Right Arrow` - Snap right
- `Win + Up Arrow` - Maximize
- `Win + Down Arrow` - Restore/Minimize

---

## Demo Flow: 2-Minute Walkthrough

### Part 1: Receiver (MQTT → Database) - 1 minute

**Narration:**
> "This is the Receiver - it subscribes to MQTT topics and routes messages to multiple database tables."

**Action:**
```powershell
# Window 1:
.\demo.ps1 -Action send-test
```

**Point to Window 2:**
> "Watch here - each message arrives and gets routed to multiple tables. Notice the 85-degree message goes to 3 different tables: raw data, alerts, and aggregates."

**Point to results:**
```
Message processed successfully to 3 table(s)
  ✓ dbo.RawSensorData
  ✓ dbo.SensorAlerts (because Value > 75)
  ✓ dbo.SensorAggregates (via stored procedure)
```

### Part 2: Publisher (Database → MQTT) - 1 minute

**Narration:**
> "Now let's see the Publisher - it monitors database changes and publishes them to MQTT."

**Action (Window 4 - SQL Query):**
```sql
INSERT INTO dbo.Products (ProductId, Name, Price, UpdatedAt)
VALUES (999, 'Demo Widget', 49.99, GETUTCDATE());
```

**Point to Window 3:**
> "The Publisher detected the database change within 5 seconds and published it to MQTT automatically."

**Expected Output in Window 3:**
```
[INF] Detected 1 change(s) in dbo.Products
[INF] Publishing to topic: products/updates
[INF] Payload: {"ProductId":999,"Name":"Demo Widget","Price":49.99}
[INF] ✓ Published successfully
```

---

## Quick Commands Reference

### Control Center (Window 1)
| Command | Action |
|---------|--------|
| `.\demo.ps1` | Show menu and status |
| `.\demo.ps1 -Action start-receiver` | Start Receiver (opens Window 2) |
| `.\demo.ps1 -Action start-publisher` | Start Publisher (opens Window 3) |
| `.\demo.ps1 -Action send-test` | Send 4 test MQTT messages |
| `.\demo.ps1 -Action view-data` | Show database contents |
| `.\demo.ps1 -Action stop-all` | Stop all services |
| `.\demo.ps1 -Action clear-data` | Clear test data |
| `.\demo.ps1 -Action full-demo` | Run complete automated demo |

### SQL Queries (Window 4)
```sql
-- Quick counts
SELECT
    (SELECT COUNT(*) FROM dbo.RawSensorData) AS Raw,
    (SELECT COUNT(*) FROM dbo.SensorAlerts) AS Alerts,
    (SELECT COUNT(*) FROM dbo.SensorAggregates) AS Aggregates;

-- View latest messages
SELECT TOP 5 * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;

-- View alerts
SELECT * FROM dbo.SensorAlerts ORDER BY AlertTime DESC;

-- View aggregates
SELECT * FROM dbo.SensorAggregates ORDER BY LastReading DESC;

-- Insert test data (for Publisher demo)
INSERT INTO dbo.Products (ProductId, Name, Price, UpdatedAt)
VALUES (NEXT VALUE FOR seq_ProductId, 'Test Product', 29.99, GETUTCDATE());
```

---

## Troubleshooting

### Receiver Window 2 not showing messages?
```powershell
# Check MQTT broker
docker ps | grep mosquitto

# Restart receiver
.\demo.ps1 -Action stop-all
.\demo.ps1 -Action start-receiver
```

### Publisher Window 3 not detecting changes?
```sql
-- Ensure change tracking is enabled
SELECT * FROM sys.change_tracking_databases;

-- If not enabled, run:
ALTER DATABASE MqttBridge SET CHANGE_TRACKING = ON;
```

### Services won't start?
```powershell
# Stop everything and rebuild
.\demo.ps1 -Action stop-all
dotnet build --configuration Release
.\demo.ps1 -Action start-receiver
.\demo.ps1 -Action start-publisher
```

### Database connection failed?
```powershell
# Test connection
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "SELECT @@VERSION"
```

---

## Expected Results After Demo

### Window 1 (Orchestrator):
```
[OK] Database: Connected (4 records in RawSensorData)
[OK] Receiver: Running
[OK] Publisher: Running
[OK] MQTT Broker: Running
```

### Window 2 (Receiver):
```
Message processed successfully to 3 table(s)
(Last message shows 3 successful table inserts)
```

### Window 3 (Publisher):
```
✓ Published successfully
(Shows recent database change publications)
```

### Database Counts:
- **dbo.RawSensorData**: 4 rows
- **dbo.SensorAlerts**: 2 rows (Value > 75)
- **dbo.SensorAggregates**: 1 row (Avg: 81.67, Min: 70, Max: 90)

---

## Demo Variations

### Quick Demo (1 minute)
```powershell
.\demo.ps1 -Action full-demo
```
Runs everything automatically - good for quick verification.

### Interactive Demo (5 minutes)
1. Start services manually
2. Send custom messages
3. Insert custom database records
4. Show configuration in SQL Server
5. Demonstrate auto-reload

### Advanced Demo (10 minutes)
1. Everything in Interactive Demo, plus:
2. Add new MQTT topic configuration
3. Watch auto-reload happen
4. Show one-to-many routing
5. Demonstrate error handling
6. Show message audit logs

---

## Cleanup After Demo

### Quick Cleanup:
```powershell
.\demo.ps1 -Action stop-all
.\demo.ps1 -Action clear-data
```

### Full Reset:
```sql
-- Reset to initial state
TRUNCATE TABLE dbo.RawSensorData;
DELETE FROM dbo.SensorAlerts;
DELETE FROM dbo.SensorAggregates;
DELETE FROM MQTT.ReceivedMessages;
DELETE FROM MQTT.PublishedMessages;
```

---

## Tips for Success

1. **Screen Share**: Share Window 2 (Receiver) as primary view
2. **Explain First**: Show the window layout before starting
3. **Go Slow**: Wait for each window to show output before moving on
4. **Highlight One-to-Many**: This is the killer feature
5. **Show Database**: Verify data in SQL to prove it worked
6. **Q&A Ready**: Be prepared to show configuration tables

---

## Common Questions & Answers

**Q: Can I add new MQTT topics without restarting?**
A: Yes! The Receiver auto-reloads configuration every 30 seconds.

**Q: What happens if one table insert fails?**
A: Error isolation means other tables still succeed (ContinueOnError=true).

**Q: Can messages go to more than 3 tables?**
A: Yes, unlimited table mappings per topic configuration.

**Q: Does it support MQTT wildcards?**
A: Yes, both `+` (single level) and `#` (multi-level) wildcards work.

**Q: Can I use this with cloud MQTT brokers?**
A: Yes, just update the BrokerAddress in appsettings.json.

**Q: Is this production-ready?**
A: Yes - zero warnings, structured logging, error handling, and auto-reconnect.

---

## Next Steps After Successful Demo

1. **Customize** - Add your own tables and topics
2. **Deploy** - Azure Container Apps or Kubernetes
3. **Monitor** - Add Application Insights
4. **Scale** - Run multiple instances
5. **Secure** - Add TLS/SSL for MQTT, use Key Vault for secrets

---

For detailed documentation, see:
- **MULTI_WINDOW_DEMO.md** - Complete walkthrough
- **ORCHESTRATOR_README.md** - Orchestrator guide
- **RECEIVER_README.md** - Receiver documentation
- **PROJECT_SUMMARY.md** - Full project overview
