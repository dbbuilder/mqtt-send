# MQTT Message Bridge - Start Here

## Complete Testing Instructions

### Prerequisites
1. Docker Desktop must be running
2. SQL Server and Mosquitto containers are running
3. Database is initialized

### Quick Check
```powershell
# Verify Docker is running
docker ps

# Should see: sqlserver and mosquitto containers
```

---

## Option 1: Manual Start (Recommended for Learning)

Open **4 separate PowerShell/Terminal windows** and run ONE command in each:

### Terminal 1 - Subscriber for Monitor 1
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Subscriber1"
dotnet run
```
**Watches for:** Messages from Monitor ID "1" only

### Terminal 2 - Subscriber for Monitor 2
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Subscriber2"
dotnet run
```
**Watches for:** Messages from Monitor ID "2" only

### Terminal 3 - Publisher
```bash
cd src\PublisherService
dotnet run
```
**Does:** Polls SQL every 5 seconds, publishes to MQTT

### Terminal 4 - Message Generator (Optional)
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1
```
**Does:** Auto-generates test messages every 5 seconds

---

## Option 2: Using Launcher Scripts

Open **4 separate PowerShell windows** and run:

### Terminal 1
```powershell
powershell -ExecutionPolicy Bypass -File run-subscriber1.ps1
```

### Terminal 2
```powershell
powershell -ExecutionPolicy Bypass -File run-subscriber2.ps1
```

### Terminal 3
```powershell
powershell -ExecutionPolicy Bypass -File run-publisher.ps1
```

### Terminal 4
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1
```

---

## What You'll See

### Terminal 1 (Subscriber 1)
```
[21:50:01 INF] Subscriber Worker started
[21:50:01 INF] Monitor Filter: 1
[21:50:01 INF] Subscribed to topic: monitor/1/messages

====================================
RECEIVED MESSAGE
MonitorId: 1
Topic: monitor/1/messages
Payload: {"monitor": 1, "sensor": "temperature", "value": 72.5, ...}
====================================
```

### Terminal 2 (Subscriber 2)
```
[21:50:02 INF] Subscriber Worker started
[21:50:02 INF] Monitor Filter: 2
[21:50:02 INF] Subscribed to topic: monitor/2/messages

====================================
RECEIVED MESSAGE
MonitorId: 2
Topic: monitor/2/messages
Payload: {"monitor": 2, "sensor": "pressure", "value": 101.3, ...}
====================================
```

### Terminal 3 (Publisher)
```
[21:50:06 INF] Processing 4 pending messages
[21:50:06 INF] Published message to topic monitor/1/messages
[21:50:06 INF] Published message to topic monitor/2/messages
[21:50:06 INF] Batch complete - Success: 4, Failures: 0
```

### Terminal 4 (Generator)
```
[Batch 1] Generating messages at 21:50:05...
  Monitor 1 : temperature = 72.5 F
  Monitor 2 : pressure = 101.3 kPa
  + Inserted 4 messages (Total: 4)
```

---

## Troubleshooting

### "Service won't start" or "Build errors"
```powershell
# Stop all services first
powershell -ExecutionPolicy Bypass -File stop-services.ps1

# Rebuild
cd src\PublisherService
dotnet build

cd ..\SubscriberService
dotnet build
```

### "No messages appearing"
```powershell
# Add test messages
powershell -ExecutionPolicy Bypass -File setup-filtered-test.ps1
```

### "Docker not running"
```powershell
# Check Docker status
docker ps

# If not running, start Docker Desktop
# Then start containers:
cd docker
docker-compose up -d
```

### "Database not initialized"
```powershell
powershell -ExecutionPolicy Bypass -File init-database.ps1
```

---

## Stop Everything

Press **Ctrl+C** in each terminal window, or:

```powershell
powershell -ExecutionPolicy Bypass -File stop-services.ps1
```

---

## Success Criteria

✅ **You're successful when:**
- Subscriber 1 receives ONLY Monitor 1 messages
- Subscriber 2 receives ONLY Monitor 2 messages
- Publisher shows "Batch complete - Success: X, Failures: 0"
- Messages flow continuously when auto-generator is running
- Each subscriber shows increasing message counts

---

## Next Steps

Once everything works:
1. Review `FILTERED_TEST_GUIDE.md` for detailed architecture
2. Check `AUTO_SEND_GUIDE.md` for generator options
3. See `QUICK_START.md` for deployment information

**You've proven the MQTT message routing system works!** 🎉
