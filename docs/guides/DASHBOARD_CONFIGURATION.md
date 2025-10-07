# Dashboard Configuration Guide

## Adding MQTT Topic Configuration via Dashboard

The MonitorDashboard now includes a **Configuration** page that allows you to add new MQTT topic subscriptions without writing SQL or restarting services.

### Access the Configuration Page

1. **Start the dashboard:**
   ```powershell
   scripts/demo/demo.ps1 -Action start-dashboard
   ```

2. **Open browser to:**
   ```
   http://localhost:5000/Configuration
   ```

3. **Click "Configuration" in the navigation menu**

---

## Quick Start Templates

To make configuration easier, the dashboard includes **pre-configured templates** for common scenarios. Simply:

1. **Select a template** from the "Quick Start Template" dropdown
2. **Review** the auto-filled values
3. **Customize** any fields to match your specific needs
4. **Submit** the form

### Available Templates

| Template | Use Case | Topic Pattern | Target Table |
|----------|----------|---------------|--------------|
| **Temperature Sensors** | Basic temperature monitoring | `sensor/+/temperature` | RawSensorData |
| **High Temperature Alerts** | Alert-only (filtered) | `sensor/+/temperature` | SensorAlerts |
| **Pressure Sensors** | Pressure monitoring | `sensor/+/pressure` | RawSensorData |
| **Humidity Sensors** | Humidity monitoring | `sensor/+/humidity` | RawSensorData |
| **Device Status** | Device health tracking | `device/+/status` | DeviceStatus |
| **Custom Data** | Catch-all for any topic | `custom/#` | CustomTable |

**💡 Tip:** Templates are tested configurations that work out-of-the-box. Just make sure your database table exists!

---

## Form Fields Explained

### Basic Configuration

**Configuration Name** (Required)
- Unique identifier for this configuration
- Example: `CustomSensor`, `TemperatureSensors`, `DeviceAlerts`

**Topic Pattern** (Required)
- MQTT topic with wildcards
- `+` = single-level wildcard
- `#` = multi-level wildcard
- Examples:
  - `sensor/+/temperature` → matches `sensor/device1/temperature`, `sensor/device2/temperature`
  - `data/#` → matches `data/any/topic/here`
  - `custom/+/data` → matches `custom/ABC/data`, `custom/XYZ/data`

**Message Format** (Required)
- `JSON` (default) - For JSON payloads
- `XML` - For XML messages
- `CSV` - For comma-separated values
- `Raw` - For plain text

**Field Mapping (JSON)** (Required)
- JSONPath mapping from MQTT message fields to database columns
- Format: `{"DatabaseColumn": "$.mqtt.field.path"}`
- Examples:
  ```json
  {"DeviceId": "$.device_id", "Value": "$.temperature", "Unit": "$.unit"}
  ```
  ```json
  {"Field1": "$.value", "Field2": "$.data.nested"}
  ```

**QoS Level** (Required)
- `0` - At most once (fire and forget)
- `1` - At least once (default, recommended)
- `2` - Exactly once (slowest but guaranteed)

**Enabled** (Checkbox)
- Check to activate this configuration immediately
- Uncheck to save as disabled

### Table Mapping Configuration

**Target Table** (Required)
- Database table name (e.g., `RawSensorData`, `CustomData`)
- Table must exist in database

**Insert Mode** (Required)
- **Direct SQL** - Direct INSERT into table
- **Stored Procedure** - Call a stored procedure
- **View** - Insert through an updateable view

**Priority** (Required)
- Execution order when multiple tables map to same topic
- Lower number = higher priority
- Examples:
  - `100` - High priority (raw data)
  - `90` - Medium priority (alerts)
  - `80` - Low priority (aggregates)

**Filter Expression** (Optional)
- SQL-like condition to filter messages
- Only messages matching the filter are inserted
- Examples:
  - `Value > 75` - Only high temperature alerts
  - `Status = 'ERROR'` - Only error messages
  - `Priority >= 5` - Only high priority messages

---

## Example Configurations

### Using Templates (Recommended for Beginners)

**The easiest way to get started:**

1. Open http://localhost:5000/Configuration
2. Select **"Temperature Sensors (Basic)"** from the template dropdown
3. The form auto-fills with working values:
   - Configuration Name: `TemperatureSensors`
   - Topic Pattern: `sensor/+/temperature`
   - Field Mapping: Complete JSON mapping
   - All other settings configured optimally
4. **Customize** the Configuration Name or Target Table if needed
5. Click **"Add Configuration"**

✅ **Done!** The Receiver will auto-reload and start subscribing within 30 seconds.

---

### Example 1: Simple Temperature Sensor (Manual)

```
Configuration Name: TemperatureSensors
Topic Pattern: sensor/+/temperature
Message Format: JSON
Field Mapping: {"DeviceId": "$.device_id", "Value": "$.value", "Unit": "$.unit"}
QoS: 1
Enabled: ✓

Target Table: RawSensorData
Insert Mode: Direct SQL
Priority: 100
Filter Expression: (leave empty)
```

**What this does:**
- Subscribes to all temperature topics: `sensor/device1/temperature`, `sensor/device2/temperature`, etc.
- Extracts `device_id`, `value`, and `unit` from JSON messages
- Inserts all messages into `RawSensorData` table

### Example 2: High Temperature Alerts

```
Configuration Name: HighTempAlerts
Topic Pattern: sensor/+/temperature
Message Format: JSON
Field Mapping: {"DeviceId": "$.device_id", "Temperature": "$.value"}
QoS: 1
Enabled: ✓

Target Table: SensorAlerts
Insert Mode: Direct SQL
Priority: 90
Filter Expression: Value > 75
```

**What this does:**
- Same topic as Example 1 (both will process messages)
- Only inserts when temperature exceeds 75
- Stores in separate `SensorAlerts` table

### Example 3: Custom Data Stream

```
Configuration Name: CustomDeviceData
Topic Pattern: custom/+/data
Message Format: JSON
Field Mapping: {"Field1": "$.value", "Field2": "$.status", "Field3": "$.timestamp"}
QoS: 1
Enabled: ✓

Target Table: CustomTable
Insert Mode: Stored Procedure
Priority: 100
Filter Expression: (leave empty)
```

**What this does:**
- Subscribes to custom data topics
- Calls a stored procedure to process data
- Allows complex business logic in the stored procedure

---

## After Submitting

### What Happens

1. **Configuration Saved** ✓
   - New entry added to `MQTT.ReceiverConfig` table
   - Table mapping added to `MQTT.TopicTableMapping` table

2. **Auto-Reload** (within 30 seconds)
   - ReceiverService automatically detects new configuration
   - Subscribes to new topic pattern
   - Starts routing messages

3. **Success Message**
   ```
   ✓ Configuration 'CustomSensor' added successfully!
     Receiver will auto-reload within 30 seconds.
   ```

### Testing Your Configuration

**Send a test message:**
```powershell
# Example: Send to custom/test/data
docker exec mosquitto mosquitto_pub -t 'custom/test/data' -m '{"value": 123, "status": "OK", "timestamp": "2025-01-06T10:30:00Z"}'
```

**Check the database:**
```powershell
scripts/demo/demo.ps1 -Action view-data
```

**Monitor the dashboard:**
- Go to http://localhost:5000
- Watch "Recent Messages" section for your message

---

## Troubleshooting

### Configuration not working?

**1. Check ReceiverService is running**
```powershell
Get-Process -Name "ReceiverService"
```

**2. Check logs in ReceiverService window**
- Look for: `Configuration changed - reloading...`
- Look for: `Subscribed to topic: 'your/topic/pattern'`

**3. Verify table exists**
```sql
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'YourTableName'
```

**4. Check field mapping matches message**
```powershell
# Send test message and check ReceiverService window for parsing errors
docker exec mosquitto mosquitto_pub -t 'test/topic' -m '{"test": "value"}'
```

### Common Errors

**"Failed to add configuration: Duplicate key"**
- Configuration name already exists
- Choose a different name

**"Column 'XYZ' not found"**
- Field mapping references non-existent database column
- Update field mapping or add column to table

**"Filter expression invalid"**
- SQL syntax error in filter
- Test filter in SQL Server first

---

## Best Practices

1. **Start Simple**
   - Create basic configuration without filters first
   - Test with sample messages
   - Add filters and complexity gradually

2. **Use Meaningful Names**
   - `TemperatureSensors` ✓
   - `Config1` ✗

3. **Test JSONPath Mapping**
   - Use online JSONPath tester: https://jsonpath.com/
   - Verify paths match your message structure

4. **Priority Strategy**
   - Raw data: 100 (highest)
   - Filtered data: 90
   - Aggregations: 80

5. **Monitor Performance**
   - Check dashboard for success rates
   - Watch for errors in ReceiverService logs

---

## Advanced: Multiple Table Routing

You can route the **same message to multiple tables** by:

1. Create one configuration with same topic pattern
2. Add multiple table mappings with different priorities

**Example:** One temperature message → 3 tables
- Priority 100 → `RawSensorData` (all messages)
- Priority 90 → `SensorAlerts` (only if `Value > 75`)
- Priority 80 → `SensorAggregates` (stored procedure updates statistics)

This is configured automatically when you submit the form!

---

## Quick Reference

**Dashboard URL:** http://localhost:5000/Configuration

**Key Points:**
- ✅ No restart required - auto-reloads within 30 seconds
- ✅ One-to-many routing supported
- ✅ Conditional filtering with SQL expressions
- ✅ Real-time validation and feedback
- ✅ View existing configurations on same page

**Need Help?**
- Check `docs/guides/RECEIVER_README.md` for technical details
- View examples in `sql/LOAD_RECEIVER_DEMO.sql`
