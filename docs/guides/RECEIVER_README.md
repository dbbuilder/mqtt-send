# MQTT Receiver System

Database-driven MQTT message receiver with **dynamic topic subscriptions** and **one-to-many table routing**.

## 🎯 Key Features

- ✅ **Database-Driven Configuration** - No code changes for new topics
- ✅ **Dynamic Topic Subscriptions** - MQTT wildcards (`+`, `#`) supported
- ✅ **One-to-Many Routing** - Single MQTT message → Multiple database tables
- ✅ **Conditional Filtering** - Route based on message content (e.g., `Value > 75`)
- ✅ **Multiple Insert Modes** - Direct INSERT, Stored Procedures, or Views
- ✅ **Auto-Reload** - Detects config changes and reloads subscriptions automatically
- ✅ **JSON Parsing** - Flexible field mapping with JSONPath support
- ✅ **Error Isolation** - One table failure doesn't block others (`ContinueOnError`)

---

## 📋 Architecture

```
┌─────────────────────┐
│  External MQTT      │
│  Broker             │
│  (Non-Azure)        │
└──────────┬──────────┘
           │
           │ Subscribe: sensor/+/temperature
           │ Subscribe: sensor/+/pressure
           │
    ┌──────▼────────┐
    │  MQTT         │
    │  Receiver     │
    │  Service      │
    └───────┬───────┘
            │
            │ Load Config from DB
            │ Parse JSON
            │ Apply Filters
            │
    ┌───────▼────────────────────────────────┐
    │  Route to Multiple Tables              │
    ├────────────────────────────────────────┤
    │  1. dbo.RawSensorData    (all)         │
    │  2. dbo.SensorAlerts     (if Value>75) │
    │  3. dbo.SensorAggregates (hourly)      │
    └────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Initialize Database Schema
```powershell
.\init-receiver-demo.ps1
```

This creates:
- `MQTT.ReceiverConfig` - Topic configurations
- `MQTT.TopicTableMapping` - One-to-many table mappings
- `MQTT.ReceivedMessages` - Message log
- Demo tables: `RawSensorData`, `SensorAlerts`, `SensorAggregates`

### 2. Run Receiver
```powershell
.\run-receiver.ps1
```

### 3. Test with MQTT Messages
```powershell
# High temperature (triggers alert)
.\test-send-mqtt-message.ps1 -Topic 'sensor/device1/temperature' -Value 78.5

# Normal temperature
.\test-send-mqtt-message.ps1 -Topic 'sensor/device1/temperature' -Value 70.0

# Pressure sensor
.\test-send-mqtt-message.ps1 -Topic 'sensor/device2/pressure' -Value 101.3
```

---

## 📊 Configuration Model

### ReceiverConfig Table
```sql
INSERT INTO MQTT.ReceiverConfig (ConfigName, TopicPattern, MessageFormat, FieldMappingJson, QoS, Enabled)
VALUES (
    'TemperatureSensors',
    'sensor/+/temperature',  -- Wildcard: matches sensor/device1/temperature, sensor/device2/temperature, etc.
    'JSON',
    '{"DeviceId": "$.device_id", "Value": "$.value", "Timestamp": "$.timestamp"}',
    1,
    1
);
```

### TopicTableMapping Table (One-to-Many)
```sql
-- Mapping 1: Store ALL readings
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, InsertMode, Priority)
VALUES (1, 'RawSensorData', 'Direct', 100);

-- Mapping 2: Store ALERTS (conditional)
INSERT INTO MQTT.TopicTableMapping (
    ReceiverConfigId, TargetTable, InsertMode, FilterCondition,
    ColumnMappingJson, Priority
)
VALUES (
    1,
    'SensorAlerts',
    'Direct',
    'Value > 75.0',  -- Only if high temperature
    '{"DeviceId": "$.device_id", "AlertType": "HighTemperature", "Value": "$.value", "Threshold": 75.0}',
    90
);

-- Mapping 3: Update AGGREGATES (via stored proc)
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, InsertMode, StoredProcName, Priority)
VALUES (1, 'SensorAggregates', 'StoredProc', 'dbo.UpdateSensorAggregate', 80);
```

---

## 🔄 Live Configuration Updates

The receiver monitors configuration changes every 30 seconds. When changes are detected:

1. **Unsubscribe** from all current topics
2. **Reload** configuration from database
3. **Resubscribe** to new/updated topics

**Example: Add new topic**
```sql
EXEC MQTT.AddReceiverConfig
    @ConfigName = 'HumiditySensors',
    @TopicPattern = 'sensor/+/humidity',
    @MessageFormat = 'JSON',
    @FieldMappingJson = '{"DeviceId": "$.device_id", "Value": "$.value"}',
    @Enabled = 1;

-- Within 30 seconds, receiver will automatically subscribe to sensor/+/humidity
```

---

## 🛠️ Message Processing Flow

### 1. Topic Matching
```
Incoming: sensor/device1/temperature
Patterns:
  ✓ sensor/+/temperature     (matches)
  ✗ sensor/+/pressure        (no match)
  ✓ sensor/#                 (matches if enabled)
```

### 2. Field Mapping
```json
{
  "device_id": "device1",
  "sensor_type": "temperature",
  "value": 78.5,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

Maps to:
```
DeviceId   ← $.device_id     → "device1"
Value      ← $.value         → 78.5
Timestamp  ← $.timestamp     → 2024-01-15T10:30:00Z
```

### 3. Filter Evaluation
```
Filter: "Value > 75.0"
Message Value: 78.5
Result: ✓ PASS → Insert into SensorAlerts
```

### 4. Table Insertion
```
Priority 100: INSERT INTO RawSensorData (DeviceId, Value, ...) VALUES (...)
Priority 90:  INSERT INTO SensorAlerts (DeviceId, AlertType, Value, Threshold, ...) VALUES (...)
Priority 80:  EXEC dbo.UpdateSensorAggregate @DeviceId='device1', @Value=78.5, ...
```

---

## 📈 Use Cases

### 1. IoT Sensor Data Collection
```sql
-- Config: Collect all sensor types
Topic Pattern: sensor/#
Mappings:
  → dbo.RawSensorData (all data)
  → dbo.SensorAlerts (threshold violations)
  → dbo.SensorAggregates (real-time stats)
```

### 2. Multi-Source Integration
```sql
-- Config: Different systems publish to same broker
Topic Patterns:
  - factory/machine/+/status  → dbo.MachineStatus
  - warehouse/inventory/+     → dbo.InventoryLevels
  - logistics/shipment/+      → dbo.Shipments
```

### 3. Event-Driven Workflows
```sql
-- Config: Route critical events to multiple systems
Topic: alerts/critical/#
Mappings:
  → dbo.EventLog (audit)
  → dbo.ActiveAlerts (operational)
  → EXEC sp_SendNotification (trigger action)
```

---

## 🔐 Security & External MQTT Brokers

### Connecting to Non-Azure MQTT Server

**Update `appsettings.json`:**
```json
{
  "MqttSettings": {
    "BrokerAddress": "mqtt.yourcompany.com",
    "BrokerPort": 8883,
    "ClientId": "MqttReceiver-Prod",
    "Username": "receiver_user",
    "Password": "your_password",
    "UseTls": true
  }
}
```

### Firewall Configuration
- Allow **outbound** connections to MQTT broker port (1883/8883)
- No inbound ports needed (receiver is a client)

### TLS/SSL Support
For secure MQTT (port 8883), add certificate validation in `Worker.cs`:
```csharp
.WithClientOptions(new MqttClientOptionsBuilder()
    .WithTcpServer(mqttSettings.BrokerAddress, mqttSettings.BrokerPort)
    .WithTls(o => {
        o.UseTls = true;
        o.CertificateValidationHandler = _ => true; // Or custom validation
    })
    .Build())
```

---

## 📊 Monitoring & Troubleshooting

### View Received Messages
```sql
SELECT TOP 100
    Topic,
    Payload,
    Status,
    TargetTablesProcessed,
    ReceivedAt
FROM MQTT.ReceivedMessages
ORDER BY ReceivedAt DESC;
```

### View Active Configuration
```sql
EXEC MQTT.GetActiveReceiverConfigs;
```

### Check Table Mappings
```sql
SELECT
    rc.ConfigName,
    rc.TopicPattern,
    tm.TargetTable,
    tm.InsertMode,
    tm.FilterCondition,
    tm.Priority
FROM MQTT.ReceiverConfig rc
INNER JOIN MQTT.TopicTableMapping tm ON tm.ReceiverConfigId = rc.Id
WHERE rc.Enabled = 1 AND tm.Enabled = 1
ORDER BY rc.ConfigName, tm.Priority DESC;
```

### Common Issues

**1. Messages not routing to tables**
- Check filter conditions: `SELECT * FROM MQTT.TopicTableMapping WHERE FilterCondition IS NOT NULL`
- Verify column mapping JSON is valid
- Check target table exists and schema matches

**2. Receiver not subscribing**
- Verify MQTT broker connection: Check receiver logs for "Connected to MQTT broker"
- Check topic patterns are valid MQTT patterns
- Ensure `ReceiverConfig.Enabled = 1`

**3. Stored procedure errors**
- Verify parameter names match `ColumnMappingJson` keys
- Check stored procedure exists: `SELECT * FROM sys.procedures WHERE name = 'UpdateSensorAggregate'`

---

## 🚢 Production Deployment

### Azure Container Apps
```bash
az containerapp create \
  --name mqtt-receiver \
  --resource-group mqtt-bridge-prod \
  --image mqttbridgeacr.azurecr.io/receiver:latest \
  --env-vars \
    "ConnectionStrings__MqttBridge=Server=..." \
    "MqttSettings__BrokerAddress=mqtt.external.com" \
    "MqttSettings__BrokerPort=8883" \
    "MqttSettings__UseTls=true"
```

### Docker Compose (with external MQTT)
```yaml
version: '3.8'
services:
  receiver:
    image: mqtt-receiver:latest
    environment:
      - ConnectionStrings__MqttBridge=Server=sqlserver;...
      - MqttSettings__BrokerAddress=mqtt.external.com
      - MqttSettings__BrokerPort=1883
    depends_on:
      - sqlserver
```

---

## 📚 API Reference

### Stored Procedures

**Add Receiver Config:**
```sql
EXEC MQTT.AddReceiverConfig
    @ConfigName = 'MyConfig',
    @TopicPattern = 'my/topic/+',
    @MessageFormat = 'JSON',
    @FieldMappingJson = '{"Field1": "$.field1"}',
    @QoS = 1,
    @Enabled = 1;
```

**Add Table Mapping:**
```sql
EXEC MQTT.AddTopicTableMapping
    @ReceiverConfigId = 1,
    @TargetTable = 'MyTable',
    @InsertMode = 'Direct',
    @FilterCondition = 'Value > 100',
    @Priority = 100,
    @Enabled = 1;
```

---

## 🔗 Related Documentation

- **Publisher System:** See `DEMO.md` for SQL → MQTT publishing
- **Azure Deployment:** See `AZURE_DEPLOYMENT.md` for full cloud setup
- **Database Schema:** See `sql/INIT_RECEIVER_SCHEMA.sql` for complete schema

---

## 🎓 Advanced Examples

### Example 1: Multi-Protocol Integration
```sql
-- Different message formats from different sources
EXEC MQTT.AddReceiverConfig @ConfigName='LegacyXML', @TopicPattern='legacy/+/data', @MessageFormat='XML';
EXEC MQTT.AddReceiverConfig @ConfigName='ModernJSON', @TopicPattern='api/v2/+/events', @MessageFormat='JSON';
```

### Example 2: Conditional Routing
```sql
-- Route critical events to multiple tables
INSERT INTO MQTT.TopicTableMapping (ReceiverConfigId, TargetTable, FilterCondition, Priority)
VALUES
    (1, 'AllEvents', NULL, 100),                    -- All events
    (1, 'CriticalEvents', 'Severity = Critical', 90), -- Only critical
    (1, 'HighPriorityQueue', 'Priority > 5', 80);   -- High priority
```

### Example 3: Data Transformation
```sql
-- Use stored proc to transform and enrich data
CREATE PROCEDURE dbo.ProcessIncomingEvent
    @DeviceId NVARCHAR(50),
    @RawValue DECIMAL(18,4),
    @Timestamp DATETIME2
AS
BEGIN
    -- Enrich with device metadata
    INSERT INTO dbo.EnrichedEvents (DeviceId, Value, Location, Timestamp)
    SELECT
        @DeviceId,
        @RawValue,
        d.Location,
        @Timestamp
    FROM dbo.Devices d
    WHERE d.DeviceId = @DeviceId;
END
```
