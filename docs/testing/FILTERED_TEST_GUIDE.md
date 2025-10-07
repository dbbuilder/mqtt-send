# Filtered Subscriber Test Guide

This guide demonstrates how MQTT topic filtering delivers messages to specific subscribers based on MonitorId.

## Architecture

```
SQL Server (MqttBridge.dbo.Messages)
    ├── MonitorId='1' (5 messages) ──┐
    └── MonitorId='2' (5 messages) ──┤
                                     ↓
            Publisher Service (polls SQL)
                     ↓
            Publishes to MQTT topics:
                ├── monitor/1/messages
                └── monitor/2/messages
                     ↓
        ┌────────────┴────────────┐
        ↓                         ↓
Subscriber 1                 Subscriber 2
Filter: "1"                  Filter: "2"
Subscribes to:               Subscribes to:
monitor/1/messages          monitor/2/messages
        ↓                         ↓
Receives 5 messages         Receives 5 messages
(temperature/humidity)      (pressure/flow)
```

## Quick Start

### Step 1: Setup Test Data

```powershell
powershell -ExecutionPolicy Bypass -File setup-filtered-test.ps1
```

**What this does:**
- Clears existing messages
- Inserts 5 messages for MonitorId "1" (temperature/humidity sensors)
- Inserts 5 messages for MonitorId "2" (pressure/flow sensors)
- Shows message distribution

### Step 2: Open THREE Terminals

**Terminal 1 - Subscriber for Monitor 1:**
```bash
cd src\SubscriberService
dotnet run --environment Subscriber1
```

Expected output:
```
[HH:MM:SS INF] Subscriber Worker started
[HH:MM:SS INF] Monitor Filter: 1
[HH:MM:SS INF] Connected to MQTT broker at localhost:1883
[HH:MM:SS INF] Subscribed to topic: monitor/1/messages
```

**Terminal 2 - Subscriber for Monitor 2:**
```bash
cd src\SubscriberService
dotnet run --environment Subscriber2
```

Expected output:
```
[HH:MM:SS INF] Subscriber Worker started
[HH:MM:SS INF] Monitor Filter: 2
[HH:MM:SS INF] Connected to MQTT broker at localhost:1883
[HH:MM:SS INF] Subscribed to topic: monitor/2/messages
```

**Terminal 3 - Publisher:**
```bash
cd src\PublisherService
dotnet run
```

Expected output:
```
[HH:MM:SS INF] Processing 10 pending messages
[HH:MM:SS INF] Published message to topic monitor/1/messages
[HH:MM:SS INF] Published message to topic monitor/1/messages
...
[HH:MM:SS INF] Published message to topic monitor/2/messages
...
[HH:MM:SS INF] Batch complete - Success: 10, Failures: 0
```

### Step 3: Observe Filtered Message Delivery

**Subscriber 1 will receive ONLY 5 messages:**
```
====================================
RECEIVED MESSAGE
MonitorId: 1
Topic: monitor/1/messages
Payload: {"monitor": 1, "sensor": "temperature", "value": 72.5, "sequence": 1}
====================================

====================================
RECEIVED MESSAGE
MonitorId: 1
Topic: monitor/1/messages
Payload: {"monitor": 1, "sensor": "temperature", "value": 73.2, "sequence": 2}
====================================

... (3 more messages, all MonitorId: 1)
```

**Subscriber 2 will receive ONLY 5 messages:**
```
====================================
RECEIVED MESSAGE
MonitorId: 2
Topic: monitor/2/messages
Payload: {"monitor": 2, "sensor": "pressure", "value": 101.3, "sequence": 1}
====================================

====================================
RECEIVED MESSAGE
MonitorId: 2
Topic: monitor/2/messages
Payload: {"monitor": 2, "sensor": "pressure", "value": 101.5, "sequence": 2}
====================================

... (3 more messages, all MonitorId: 2)
```

## What This Proves

✅ **MQTT Topic Filtering Works**
- Publisher publishes all 10 messages to their respective topics
- Subscriber 1 subscribes to `monitor/1/messages` and receives ONLY those 5 messages
- Subscriber 2 subscribes to `monitor/2/messages` and receives ONLY those 5 messages
- No cross-contamination - each subscriber gets exactly what they subscribed to

✅ **Message Routing by MonitorId**
- Messages are correctly routed based on their MonitorId
- The MQTT broker handles the filtering automatically
- No application-level filtering needed

✅ **Multiple Subscribers Work Simultaneously**
- Both subscribers can run at the same time
- Each has a unique ClientId to prevent conflicts
- Messages are delivered independently to each

## Configuration Files

### Subscriber 1 (Monitor 1 Only)
File: `src/SubscriberService/appsettings.Subscriber1.json`
- **MonitorFilter**: "1"
- **ClientId**: "SubscriberService-Monitor1"
- **Subscribes to**: `monitor/1/messages`

### Subscriber 2 (Monitor 2 Only)
File: `src/SubscriberService/appsettings.Subscriber2.json`
- **MonitorFilter**: "2"
- **ClientId**: "SubscriberService-Monitor2"
- **Subscribes to**: `monitor/2/messages`

## Test Again

To reset and test again:

```powershell
# Clear and recreate test data
powershell -ExecutionPolicy Bypass -File setup-filtered-test.ps1

# Then restart all three terminals
```

## Add More Monitors

To test with additional monitors:

```powershell
# Add messages for Monitor 3
powershell -ExecutionPolicy Bypass -File add-test-message.ps1 -MonitorId "3" -Message '{"monitor": 3, "test": "data"}'

# Create appsettings.Subscriber3.json with MonitorFilter: "3"
# Start another subscriber with: dotnet run --environment Subscriber3
```

## Success Criteria

✅ Subscriber 1 receives exactly 5 messages (all MonitorId: 1)
✅ Subscriber 2 receives exactly 5 messages (all MonitorId: 2)
✅ No subscriber receives messages meant for the other
✅ Publisher successfully publishes all 10 messages
✅ All messages marked as 'Published' in database

## Real-World Use Case

This pattern enables:
- **Multi-tenant systems**: Each customer/tenant only receives their data
- **Geographic filtering**: Different subscribers for different regions
- **Device-specific processing**: Specialized handlers for different device types
- **Load distribution**: Distribute processing across multiple subscribers by partition
- **Security**: Subscribers can't access data they're not subscribed to

---

**System Validated:** Messages are correctly filtered and delivered to specific subscribers by MonitorId! 🎉
