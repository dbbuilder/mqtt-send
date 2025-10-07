# Dashboard Test Buttons Guide

## Overview

The Monitor Dashboard home page now includes **Quick Test Actions** buttons that allow you to generate MQTT events and trigger publisher operations directly from the web interface.

## Features

### 1. Send Test Messages (MQTT)

Send individual test messages to MQTT topics that will be received by the ReceiverService:

**Normal Temp (72°F)**
- Sends a temperature reading of 72°F
- Topic: `sensor/deviceX/temperature`
- Should be stored in `RawSensorData` table
- Will NOT trigger alerts (below threshold)

**High Temp (85°F - Alert)**
- Sends a temperature reading of 85°F
- Topic: `sensor/deviceX/temperature`
- Should be stored in `RawSensorData` AND `SensorAlerts` tables
- Triggers high temperature alert (Value > 75)

**Pressure (101.3 kPa)**
- Sends a pressure reading of 101.3 kPa
- Topic: `sensor/deviceX/pressure`
- Should be stored in `RawSensorData` table

### 2. Trigger Publisher Events

Insert test records into source tables that will be published by the PublisherService:

**Publish from TableA**
- Inserts a new temperature record into `dbo.TableA`
- Publisher will detect the new record and publish to MQTT
- Topic: `data/tableA/{MonitorId}`

**Publish from TableB**
- Inserts a new pressure record into `dbo.TableB`
- Publisher will detect the new record and publish to MQTT
- Topic: `data/tableB/{MonitorId}`

**Publish from TableC**
- Inserts a new flow rate record into `dbo.TableC`
- Publisher will detect the new record and publish to MQTT
- Topic: `data/tableC/{MonitorId}`

### 3. Bulk Operations

**Send 5/10 Random Messages**
- Sends multiple random sensor messages
- Mix of temperature, pressure, and humidity readings
- Random device IDs (device1-device10)
- Random values within realistic ranges
- 100ms delay between messages

**Clear All Test Data**
- **WARNING:** This deletes all test data from all tables
- Requires confirmation before executing
- Clears:
  - `dbo.RawSensorData`
  - `dbo.SensorAlerts`
  - `dbo.SensorAggregates`
  - `MQTT.ReceivedMessages`
  - `dbo.TableA`, `TableB`, `TableC`
  - `MQTT.SentRecords`

## How It Works

### Backend API

All test actions are handled by the `TestApiController` at `/api/test/`:

**Endpoints:**
- `POST /api/test/send-message` - Send individual MQTT message
- `POST /api/test/send-bulk` - Send bulk random messages
- `POST /api/test/trigger-publisher` - Insert record into source table
- `POST /api/test/clear-data` - Delete all test data

### MQTT Publishing

Test messages are sent using MQTTnet library:
- Connects to `localhost:1883` (Mosquitto broker)
- Uses QoS Level 1 (At Least Once)
- Generates realistic JSON payloads
- Auto-generates device IDs and timestamps

### Status Feedback

All actions show real-time status messages:
- ℹ️ **Blue** - Action in progress
- ✓ **Green** - Action completed successfully
- ✗ **Red** - Action failed with error
- ⚠️ **Yellow** - Warning (clear data operation)

Messages auto-dismiss after 4 seconds.

## Example Workflows

### Test Receiver One-to-Many Routing

1. Click **"High Temp (85°F - Alert)"**
2. Wait 2-3 seconds for processing
3. Check dashboard **"Recent Messages"** section
4. Verify message appears with **"2 tables"** badge
5. Query database to confirm:
   ```sql
   SELECT * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;
   SELECT * FROM dbo.SensorAlerts ORDER BY AlertTime DESC;
   ```

### Test Publisher Flow

1. Click **"Publish from TableA"**
2. Record inserted with random MonitorId and temperature
3. Publisher detects new record (within polling interval)
4. Message published to MQTT topic `data/tableA/{MonitorId}`
5. Check **"Recent Publications"** section on dashboard

### Generate Load Test Data

1. Click **"Send 10 Random Messages"**
2. 10 messages sent with variety of sensor types
3. Watch **"Live Message Flow"** section update in real-time
4. Check statistics counters increment

### Reset Environment

1. Click **"Clear All Test Data"**
2. Confirm deletion warning
3. All test tables and tracking records deleted
4. Dashboard counters reset to 0
5. Ready for fresh testing

## Troubleshooting

### "Failed to send message" Error

**Possible Causes:**
- Mosquitto MQTT broker not running
- Connection refused to localhost:1883

**Solution:**
```powershell
# Check if Mosquitto is running
docker ps | grep mosquitto

# Start Mosquitto if needed
cd docker
docker-compose up -d
```

### "Failed to trigger publisher" Error

**Possible Causes:**
- Source tables (TableA, TableB, TableC) don't exist
- SQL Server connection issue

**Solution:**
```powershell
# Initialize sample tables
scripts/demo/demo.ps1 -Action init-db
```

### Messages sent but not appearing in dashboard

**Possible Causes:**
- ReceiverService not running
- Configuration not loaded

**Check ReceiverService logs:**
```powershell
# Start receiver if not running
scripts/demo/demo.ps1 -Action start-receiver

# Check for subscription messages in ReceiverService window
# Should see: "Subscribed to topic: 'sensor/+/temperature'"
```

### Publisher not detecting inserted records

**Possible Causes:**
- PublisherService (MultiTablePublisher) not running
- Polling interval delay (default 2 seconds)

**Solution:**
```powershell
# Start publisher if not running
scripts/demo/demo.ps1 -Action start-publisher

# Wait for polling cycle to complete (2-5 seconds)
```

## Technical Details

### Message Payload Format

All test messages use this JSON structure:

```json
{
  "device_id": "device1",
  "sensor_type": "temperature",
  "value": 85.0,
  "unit": "F",
  "timestamp": "2025-01-06T12:34:56.789Z"
}
```

### Random Value Ranges

Bulk message generator uses realistic ranges:
- **Temperature:** 65-95°F
- **Pressure:** 95-105 kPa
- **Humidity:** 30-80%

### Database Impact

**Send 10 Random Messages:**
- ~10 records in `MQTT.ReceivedMessages`
- ~10 records in `dbo.RawSensorData`
- ~2-4 records in `dbo.SensorAlerts` (if high temps generated)
- ~10 records in `dbo.SensorAggregates` (aggregate updates)

**Trigger Publisher:**
- 1 record in source table (TableA/B/C)
- 1 record in `MQTT.SentRecords` (after publishing)

## Best Practices

1. **Start with single messages** to verify system is working
2. **Use bulk operations** for load testing only
3. **Clear data regularly** during development to avoid clutter
4. **Watch the "Live Message Flow"** section for real-time feedback
5. **Check both dashboard and database** to verify end-to-end flow

## Integration with Demo Scripts

The test buttons complement the PowerShell demo scripts:

**Dashboard Buttons:**
- ✅ Quick, one-click actions
- ✅ Visual feedback
- ✅ No command line needed
- ✅ Great for demos and presentations

**PowerShell Scripts:**
- ✅ Automated workflows
- ✅ Batch operations
- ✅ CI/CD integration
- ✅ Detailed logging

Use whichever method suits your workflow!
