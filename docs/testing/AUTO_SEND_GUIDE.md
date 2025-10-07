# Auto-Send Messages Guide

Continuously generate test messages for live testing of the MQTT message bridge system.

## Quick Start - Full Demo

### Step 1: Start All Services

**Terminal 1 - Subscriber for Monitor 1:**
```bash
cd src\SubscriberService
dotnet run --environment Subscriber1
```

**Terminal 2 - Subscriber for Monitor 2:**
```bash
cd src\SubscriberService
dotnet run --environment Subscriber2
```

**Terminal 3 - Publisher:**
```bash
cd src\PublisherService
dotnet run
```

### Step 2: Start Auto-Generator

**Terminal 4 - Message Generator:**
```powershell
powershell -ExecutionPolicy Bypass -File demo-continuous.ps1
```

**Or start the generator directly:**
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1
```

### Step 3: Watch the Flow!

You'll see:
- **Terminal 4**: Shows messages being inserted every 5 seconds
- **Terminal 3**: Publisher picks them up and publishes to MQTT
- **Terminal 1**: Subscriber 1 receives only Monitor 1 messages
- **Terminal 2**: Subscriber 2 receives only Monitor 2 messages

**Press Ctrl+C in Terminal 4 to stop the generator**

---

## Auto-Send Script Options

### Basic Usage
```powershell
# Default: 2 messages every 5 seconds for Monitors 1 and 2
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1
```

### Custom Interval
```powershell
# Generate messages every 10 seconds
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -IntervalSeconds 10

# Generate messages every 2 seconds (fast!)
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -IntervalSeconds 2
```

### Custom Message Count
```powershell
# Generate 5 messages per monitor per batch
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MessagesPerBatch 5

# Generate 1 message per monitor per batch
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MessagesPerBatch 1
```

### Custom Monitor IDs
```powershell
# Only generate for Monitor 1
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MonitorIds @("1")

# Generate for Monitors 1, 2, and 3
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MonitorIds @("1", "2", "3")

# Generate for custom monitor IDs
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MonitorIds @("SENSOR_A", "SENSOR_B")
```

### Random Data Mode
```powershell
# Generate completely random values (default uses sine wave patterns)
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -RandomData
```

### Combine Options
```powershell
# Fast test: 1 message every 2 seconds, random data
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -IntervalSeconds 2 -MessagesPerBatch 1 -RandomData

# Load test: 10 messages every 5 seconds for 5 monitors
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MessagesPerBatch 10 -MonitorIds @("1", "2", "3", "4", "5")
```

---

## Generated Data

The auto-generator creates realistic sensor data:

### Monitor 1 - Environmental Sensors
- **Temperature**: 68-78°F (oscillating sine wave pattern)
- **Humidity**: 35-55% (oscillating sine wave pattern)

### Monitor 2 - Industrial Sensors
- **Pressure**: 100-103 kPa (oscillating sine wave pattern)
- **Flow Rate**: 240-260 L/min (oscillating sine wave pattern)

### Message Format
```json
{
  "monitor": "1",
  "sensor": "temperature",
  "value": 72.5,
  "unit": "°F",
  "timestamp": "2025-10-05T21:30:00Z",
  "batch": 42,
  "sequence": 1
}
```

---

## Use Cases

### 1. Live Demo
Show real-time message routing with continuous data flow
```powershell
powershell -ExecutionPolicy Bypass -File demo-continuous.ps1
```

### 2. Performance Testing
Generate high volume to test throughput
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -IntervalSeconds 1 -MessagesPerBatch 20
```

### 3. Filtered Subscriber Testing
Generate for specific monitors to test filtering
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -MonitorIds @("1") -IntervalSeconds 3
```

### 4. Pattern Analysis
Use sine wave patterns (default) to see smooth data trends
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -IntervalSeconds 5
```

### 5. Random Data Testing
Use random values to simulate real-world variation
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1 -RandomData -IntervalSeconds 5
```

---

## Expected Output

**Auto-Generator Terminal:**
```
=== Auto Message Generator ===
Interval: 5 seconds
Messages per batch: 2 per monitor
Monitor IDs: 1, 2
Press Ctrl+C to stop

[Batch 1] Generating messages at 21:30:05...
  Monitor 1 : temperature = 72.5 °F
  Monitor 2 : pressure = 101.3 kPa
  ✓ Inserted 2 messages (Total: 2)

[Batch 2] Generating messages at 21:30:10...
  Monitor 1 : humidity = 45 %
  Monitor 2 : flow = 250.5 L/min
  ✓ Inserted 2 messages (Total: 4)
```

**Publisher Terminal:**
```
[21:30:06 INF] Processing 2 pending messages
[21:30:06 INF] Published message to topic monitor/1/messages
[21:30:06 INF] Published message to topic monitor/2/messages
[21:30:06 INF] Batch complete - Success: 2, Failures: 0

[21:30:11 INF] Processing 2 pending messages
[21:30:11 INF] Published message to topic monitor/1/messages
[21:30:11 INF] Published message to topic monitor/2/messages
[21:30:11 INF] Batch complete - Success: 2, Failures: 0
```

**Subscriber Terminals:**
Each shows only their filtered messages arriving in real-time!

---

## Stop the Generator

Press **Ctrl+C** in the auto-generator terminal.

Summary will be displayed:
```
=== Auto-Generator Stopped ===

Summary:
  Total batches: 42
  Total messages: 84
```

---

## Tips

1. **Start services first** - The auto-generator works best when all services are already running
2. **Adjust interval** - Use `-IntervalSeconds` to match your testing needs
3. **Watch patterns** - Default sine wave patterns create smooth, realistic data trends
4. **Use random mode** - For stress testing with unpredictable values
5. **Scale up** - Test with more monitors or higher message counts to see system limits

---

**Perfect for live demos and continuous testing!** 🚀
