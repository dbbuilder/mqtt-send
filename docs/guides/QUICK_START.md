# MQTT Bridge - Quick Start Checklist

## 🚀 Fastest Way to Start

```powershell
cd D:\dev2\clients\mbox\mqtt-send

# Start everything (one command)
.\Start-FullSystem.ps1 -Action start
```

Dashboard opens automatically at: **http://localhost:5000**

---

## ✅ Verify It's Working

### Check Dashboard
- Publisher: ONLINE (green) with 3 tables
- Receiver: ONLINE (green) with 3 subscriptions  
- Live Flow: Red PUBLISHED + Blue RECEIVED events

### Check Database
```sql
SELECT COUNT(*) FROM MQTT.SentRecords;      -- Should increase
SELECT COUNT(*) FROM MQTT.ReceivedMessages; -- Should increase
SELECT COUNT(*) FROM dbo.RawSensorData;     -- Should increase
```

---

## 🧪 Test End-to-End Flow

```sql
-- Insert test data
INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location, Timestamp)
VALUES (1, 'temperature', 99.9, 'F', 'Test', GETUTCDATE());

-- Wait 5 seconds, then verify it arrived
SELECT TOP 5 * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;
```

✅ If you see the data → **IT WORKS!**

---

## 🛑 Stop Everything

```powershell
.\Start-FullSystem.ps1 -Action stop
```

---

## 📊 Monitoring

```powershell
.\Start-FullSystem.ps1 -Action status  # System status
.\Start-FullSystem.ps1 -Action test    # Data flow test
.\Start-FullSystem.ps1 -Action logs    # View logs
```

---

## 🐛 Common Issues

**"Receiver has 0 messages"** → Restart: `.\Start-FullSystem.ps1 -Action restart`

**"Build failed"** → Stop first: `.\Start-FullSystem.ps1 -Action stop`

**"Dashboard shows OFFLINE"** → Check status: `.\Start-FullSystem.ps1 -Action status`

---

## 📚 Full Details

See **FULL_SYSTEM_GUIDE.md** for complete documentation.

---

## 🎯 What Should Happen

1. Insert into TableA (MonitorId 1 or 2)
2. Publisher publishes to MQTT (`data/tableA/1`)
3. Receiver receives and stores in RawSensorData
4. Dashboard shows both PUBLISHED + RECEIVED
5. Logging tracks everything

**Complete round trip in under 5 seconds!** 🎉
