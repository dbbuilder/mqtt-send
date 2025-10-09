# MQTT Bridge - Troubleshooting Guide

## 🔴 SQL Server Connection Timeout Error

**Error:**
```
System.ComponentModel.Win32Exception (258): The wait operation timed out.
```

**Cause:** SQL Server container is not fully healthy or ready to accept connections.

**Solution:**

### Use the Safe Startup Script
```powershell
.\Start-System-Safe.ps1
```

This script:
- ✅ Checks Docker is running
- ✅ Starts SQL Server container
- ✅ Waits for SQL Server to be HEALTHY (not just running)
- ✅ Tests database connection
- ✅ Verifies database schema exists
- ✅ Then starts all services

### Manual Verification

```powershell
# 1. Check if SQL Server container is running
docker ps | Select-String "sqlserver"

# 2. Check SQL Server health status
docker inspect --format='{{.State.Health.Status}}' sqlserver

# Expected: "healthy" (not "starting" or "unhealthy")

# 3. Test SQL connection manually
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "SELECT @@VERSION"

# 4. If unhealthy, check logs
docker logs sqlserver --tail 50
```

### If SQL Server Won't Start

```powershell
# Stop and remove container
docker stop sqlserver
docker rm sqlserver

# Recreate from docker-compose
cd docker
docker-compose up -d sqlserver

# Wait 30 seconds, then check health
docker inspect --format='{{.State.Health.Status}}' sqlserver
```

---

## 🔴 Mosquitto Connection Failed

**Error:**
```
MQTTnet.Exceptions.MqttCommunicationException: Connection refused
```

**Solution:**

```powershell
# Check if Mosquitto is running
docker ps | Select-String "mosquitto"

# If not running, start it
docker start mosquitto

# Or recreate
cd docker
docker-compose up -d mosquitto
```

---

## 🔴 Dashboard Shows All Services OFFLINE

**Cause:** Services can't connect to database or MQTT broker.

**Solution:**

```powershell
# 1. Use safe startup script
.\Start-System-Safe.ps1

# 2. Or check infrastructure manually
docker ps

# Should show both sqlserver (healthy) and mosquitto (running)
```

---

## 🔴 Receiver Shows 0 Messages

**Cause:** Receiver subscriptions may not match publisher topics.

**Solution:**

```sql
-- Verify receiver subscriptions
SELECT ConfigName, TopicPattern, Enabled
FROM MQTT.ReceiverConfig;

-- Should show:
-- TableA_Data | data/tableA/+ | 1
-- TableB_Data | data/tableB/+ | 1
-- TableC_Data | data/tableC/+ | 1

-- Verify publisher topics
SELECT SourceName, TopicPattern, Enabled
FROM MQTT.SourceConfig;

-- Should show:
-- TableA | data/tableA/{MonitorId} | 1
-- TableB | data/tableB/{MonitorId} | 1
-- TableC | data/tableC/{MonitorId} | 1
```

If configs are wrong, re-run:
```powershell
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/SETUP_BIDIRECTIONAL_FLOW.sql
```

Then restart receiver:
```powershell
.\Start-System-Safe.ps1
```

---

## 🔴 Build Failed - File is Locked

**Error:**
```
MSB3027: Could not copy apphost.exe - file is locked
```

**Solution:**

```powershell
# Stop all services first
Get-Process | Where-Object {$_.ProcessName -match "ReceiverService|PublisherService|MonitorDashboard|MultiTablePublisher"} | Stop-Process -Force

# Wait 3 seconds
Start-Sleep -Seconds 3

# Then rebuild
.\Start-System-Safe.ps1
```

---

## 🔴 Database Does Not Exist

**Error:**
```
Cannot open database "MqttBridge" requested by the login
```

**Solution:**

```powershell
# Create database
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "CREATE DATABASE MqttBridge"

# Initialize schemas
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/INIT_RECEIVER_SCHEMA.sql
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/LOAD_RECEIVER_DEMO.sql
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/SETUP_BIDIRECTIONAL_FLOW.sql

# Start system
.\Start-System-Safe.ps1
```

---

## 🔴 InvalidCastException in Dashboard

**Error:**
```
Unable to cast object of type 'System.Int64' to type 'System.Int32'
```

**Status:** ✅ FIXED in latest code

**If you still see this:**
```powershell
# Stop dashboard
Get-Process -Name "MonitorDashboard" -ErrorAction SilentlyContinue | Stop-Process -Force

# Rebuild
dotnet build src/MonitorDashboard/MonitorDashboard.csproj --configuration Release

# Restart
.\Start-System-Safe.ps1
```

---

## 🟢 Verify Everything is Working

### Check Docker Containers
```powershell
docker ps

# Should show:
# - sqlserver (Up, healthy)
# - mosquitto (Up)
```

### Check .NET Services
```powershell
Get-Process | Where-Object {$_.ProcessName -match "ReceiverService|PublisherService|MonitorDashboard|MultiTablePublisher"}

# Should show 3 processes running
```

### Check Database Activity
```sql
-- Check published messages
SELECT COUNT(*) FROM MQTT.SentRecords;

-- Check received messages
SELECT COUNT(*) FROM MQTT.ReceivedMessages;

-- Check destination data
SELECT COUNT(*) FROM dbo.RawSensorData;

-- Check application logs
SELECT COUNT(*) FROM Logging.ApplicationLogs;

-- All should be > 0
```

### Check Dashboard
Open http://localhost:5000

- ✅ Publisher: ONLINE, 3 tables monitored
- ✅ Receiver: ONLINE, 3 subscriptions active
- ✅ Live Flow: Both PUBLISHED (red) and RECEIVED (blue) events

---

## 🛠️ Complete System Reset

If everything is broken, do a complete reset:

```powershell
# 1. Stop all services
Get-Process | Where-Object {$_.ProcessName -match "ReceiverService|PublisherService|MonitorDashboard|MultiTablePublisher"} | Stop-Process -Force

# 2. Stop Docker containers
docker stop sqlserver mosquitto

# 3. Remove containers (optional - removes all data!)
docker rm sqlserver mosquitto

# 4. Remove volumes (optional - complete wipe!)
cd docker
docker-compose down -v

# 5. Recreate everything
docker-compose up -d

# 6. Wait for SQL Server to be healthy (60 seconds)
Start-Sleep -Seconds 60

# 7. Recreate database
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -Q "CREATE DATABASE MqttBridge"

# 8. Initialize all schemas
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/INIT_RECEIVER_SCHEMA.sql
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/LOAD_RECEIVER_DEMO.sql
sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -i sql/SETUP_BIDIRECTIONAL_FLOW.sql

# 9. Start system safely
.\Start-System-Safe.ps1
```

---

## 📊 Useful Monitoring Commands

```powershell
# Check SQL Server health in real-time
while ($true) {
    docker inspect --format='{{.State.Health.Status}}' sqlserver
    Start-Sleep -Seconds 5
}

# Watch database activity
while ($true) {
    sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -d MqttBridge -Q "SELECT (SELECT COUNT(*) FROM MQTT.SentRecords) as Sent, (SELECT COUNT(*) FROM MQTT.ReceivedMessages) as Received" -h -1
    Start-Sleep -Seconds 2
}

# Monitor Docker logs
docker logs -f mosquitto  # MQTT broker logs
docker logs -f sqlserver  # SQL Server logs
```

---

## 🆘 Still Having Issues?

### Check Prerequisites
- [ ] Docker Desktop is installed and running
- [ ] .NET 9.0 SDK installed
- [ ] .NET 6.0 SDK installed
- [ ] sqlcmd utility available
- [ ] PowerShell 5.1 or later

### Collect Diagnostic Info
```powershell
# Docker info
docker --version
docker ps -a

# SQL Server health
docker inspect sqlserver | Select-String "Health"

# Service processes
Get-Process | Where-Object {$_.ProcessName -match "ReceiverService|PublisherService|MonitorDashboard|MultiTablePublisher"}

# Port status
netstat -ano | findstr ":1433"  # SQL Server
netstat -ano | findstr ":1883"  # MQTT
netstat -ano | findstr ":5000"  # Dashboard
```

### Get Help
1. Check the full documentation: **FULL_SYSTEM_GUIDE.md**
2. Review the architecture: **README.md**
3. Check deployment logs in each service terminal window

---

## ✅ Success Criteria

Your system is working correctly when:

✅ `docker ps` shows sqlserver (healthy) and mosquitto (running)
✅ `.\Start-System-Safe.ps1` completes without errors
✅ Dashboard shows both Publisher and Receiver as ONLINE
✅ `MQTT.SentRecords` has rows and count is increasing
✅ `MQTT.ReceivedMessages` has rows and count is increasing
✅ `dbo.RawSensorData` has rows and count is increasing
✅ `Logging.ApplicationLogs` has entries from all services
✅ Dashboard shows live PUBLISHED + RECEIVED events updating every 5 seconds
