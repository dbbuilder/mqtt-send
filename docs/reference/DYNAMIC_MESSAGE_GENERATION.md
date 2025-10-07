# Dynamic Message Generation System

## Overview

The dynamic message generation system uses JSON configuration files to define monitors and their sensors, allowing you to add new message types without modifying PowerShell code.

## Quick Start

### Use Dynamic Generator

```powershell
# Use existing configuration
powershell -ExecutionPolicy Bypass -File auto-send-messages-dynamic.ps1

# Custom interval and batch size
powershell -ExecutionPolicy Bypass -File auto-send-messages-dynamic.ps1 -IntervalSeconds 10 -MessagesPerBatch 5
```

### Add New Monitor Interactively

```powershell
powershell -ExecutionPolicy Bypass -File add-monitor.ps1
```

### Edit Configuration Directly

Edit `config/monitors.json` to add/modify monitors.

---

## Configuration Structure

### File Location
- **Primary Config:** `config/monitors.json`
- **Template:** `config/monitor-template.json`

### JSON Schema

```json
{
  "monitors": {
    "MONITOR_ID": {
      "name": "Display Name",
      "location": "Physical Location",
      "sensors": [
        {
          "type": "sensor_type",
          "unit": "unit_of_measure",
          "generator": "oscillate|random|linear|static",
          "min": 0.0,
          "max": 100.0,
          "amplitude": 5.0,
          "frequency": 0.5
        }
      ],
      "fields": {
        "Status": "Active",
        "DataQuality": "Good",
        "CustomField": "CustomValue"
      }
    }
  }
}
```

---

## Value Generators

### 1. Oscillate (Sine Wave)
Creates smooth oscillating values - ideal for temperature, pressure, etc.

**Parameters:**
- `min` (required): Minimum value
- `max` (required): Maximum value
- `amplitude` (optional): Wave amplitude (default: (max-min)/2)
- `frequency` (optional): Wave frequency (default: 0.5)

**Example:**
```json
{
  "type": "temperature",
  "unit": "F",
  "generator": "oscillate",
  "min": 68.0,
  "max": 78.0,
  "amplitude": 5.0,
  "frequency": 0.5
}
```

**Output:** Values smoothly oscillate between 68-78°F in a sine wave pattern.

---

### 2. Random
Generates random values within a range.

**Parameters:**
- `min` (required): Minimum value
- `max` (required): Maximum value

**Example:**
```json
{
  "type": "humidity",
  "unit": "%",
  "generator": "random",
  "min": 35,
  "max": 55
}
```

**Output:** Random values between 35-55%.

---

### 3. Linear
Values increment/decrement linearly, then cycle.

**Parameters:**
- `min` (required): Starting value
- `max` (required): Ending value
- `step` (required): Increment per batch

**Example:**
```json
{
  "type": "counter",
  "unit": "count",
  "generator": "linear",
  "min": 0,
  "max": 100,
  "step": 5
}
```

**Output:** 0, 5, 10, 15, ..., 100, 0, 5, ... (cycles)

---

### 4. Static
Fixed value - never changes.

**Parameters:**
- `value` (required): The fixed value

**Example:**
```json
{
  "type": "constant",
  "unit": "V",
  "generator": "static",
  "value": 3.3
}
```

**Output:** Always 3.3V

---

## Example Configurations

### Monitor 1: HVAC System

```json
{
  "monitors": {
    "hvac-01": {
      "name": "HVAC Unit 01",
      "location": "Building A - Rooftop",
      "sensors": [
        {
          "type": "temperature",
          "unit": "F",
          "generator": "oscillate",
          "min": 68.0,
          "max": 72.0,
          "amplitude": 2.0,
          "frequency": 0.3
        },
        {
          "type": "fan_speed",
          "unit": "RPM",
          "generator": "linear",
          "min": 1000,
          "max": 3000,
          "step": 100
        },
        {
          "type": "power_status",
          "unit": "bool",
          "generator": "static",
          "value": 1
        }
      ],
      "fields": {
        "Status": "Active",
        "DataQuality": "Good",
        "MaintenanceRequired": "No"
      }
    }
  }
}
```

### Monitor 2: Industrial Pump

```json
{
  "monitors": {
    "pump-02": {
      "name": "Industrial Pump 02",
      "location": "Factory Floor - Zone B",
      "sensors": [
        {
          "type": "pressure",
          "unit": "PSI",
          "generator": "oscillate",
          "min": 45.0,
          "max": 55.0,
          "amplitude": 5.0,
          "frequency": 0.8
        },
        {
          "type": "flow_rate",
          "unit": "GPM",
          "generator": "random",
          "min": 240,
          "max": 260
        },
        {
          "type": "vibration",
          "unit": "Hz",
          "generator": "random",
          "min": 0.1,
          "max": 2.5
        }
      ],
      "fields": {
        "Status": "Active",
        "DataQuality": "Good",
        "OperatingMode": "Auto",
        "LastMaintenance": "2025-09-15"
      }
    }
  }
}
```

---

## Adding Monitors

### Method 1: Interactive Script (Easiest)

```powershell
powershell -ExecutionPolicy Bypass -File add-monitor.ps1
```

Follow the prompts to:
1. Enter Monitor ID
2. Enter Monitor Name and Location
3. Add sensors with generator types
4. Add custom fields (optional)

### Method 2: Copy from Template

1. Copy `config/monitor-template.json`
2. Replace `MONITOR_ID` with your ID
3. Fill in monitor details
4. Add/remove sensors as needed
5. Merge into `config/monitors.json`

### Method 3: Edit JSON Directly

1. Open `config/monitors.json`
2. Add new monitor under `"monitors"` object
3. Save file
4. Run dynamic generator

---

## Custom Fields

Add any custom fields to your messages via the `fields` object:

```json
{
  "fields": {
    "Status": "Active",
    "DataQuality": "Good",
    "Operator": "John Doe",
    "ShiftNumber": 2,
    "ProductionLine": "Line-A",
    "AlertLevel": "Normal",
    "CustomMetric": 123.45
  }
}
```

These fields are automatically added to every message for that monitor.

---

## Record Structure

Generated messages follow this structure:

```json
{
  "RecordId": "guid",
  "MonitorId": "monitor-id",
  "SensorType": "sensor-type",
  "Value": 123.45,
  "Unit": "unit",
  "Timestamp": "2025-10-05T22:30:00Z",
  "Location": "location-from-config",
  "AlertThreshold": "max-value-from-sensor",
  "BatchNumber": 42,
  "SequenceNumber": 1,
  "Status": "Active",
  "DataQuality": "Good",
  ...customFields
}
```

---

## Testing New Configurations

### Test Configuration Validity

```powershell
# Test loading config
$config = Get-Content config\monitors.json -Raw | ConvertFrom-Json
$config.monitors
```

### Run with Specific Monitor

Edit `config/monitors.json` temporarily to include only the monitor you want to test.

### Dry Run (No Database Insert)

Modify `auto-send-messages-dynamic.ps1` and comment out the SQL execution section for testing.

---

## Migration from Hardcoded Script

### Old Way (Hardcoded):
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1
```

### New Way (Dynamic):
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages-dynamic.ps1
```

**Benefits:**
- ✅ Add monitors without code changes
- ✅ Change sensor types without code changes
- ✅ Adjust value ranges in config file
- ✅ Multiple generator types
- ✅ Custom fields per monitor
- ✅ Easy to version control configurations

---

## Best Practices

### 1. Sensor Generator Selection

- **Oscillate:** Use for values that naturally fluctuate (temp, pressure, flow)
- **Random:** Use for unpredictable values (noise, vibration, errors)
- **Linear:** Use for counters, sequences, or test patterns
- **Static:** Use for fixed values (constants, versions, modes)

### 2. Value Ranges

- Set realistic `min`/`max` based on real sensors
- Use `AlertThreshold` = `max` for normal operation
- Adjust `amplitude` and `frequency` for natural patterns

### 3. Monitor IDs

- Use descriptive IDs: `hvac-01`, `pump-02`, `sensor-temp-123`
- Keep IDs consistent with your physical devices
- Avoid special characters (stick to alphanumeric and hyphens)

### 4. Custom Fields

- Add fields that help with filtering/sorting
- Include operational metadata (shift, operator, mode)
- Use consistent field names across monitors

---

## Troubleshooting

### Config Not Found
```
Error: Config file not found at config\monitors.json
```
**Fix:** Ensure `config/monitors.json` exists. Copy from template if needed.

### JSON Parse Error
```
ConvertFrom-Json : Invalid JSON
```
**Fix:** Validate JSON syntax at https://jsonlint.com

### No Sensors Defined
```
Get-Random: Cannot bind argument to parameter 'InputObject' because it is null.
```
**Fix:** Ensure each monitor has at least one sensor in the `sensors` array.

### Generator Not Working
**Fix:** Check generator name is one of: `oscillate`, `random`, `linear`, `static`

---

## Examples

### Add HVAC Monitor

```powershell
# Run interactive script
.\add-monitor.ps1

# Enter:
# Monitor ID: hvac-01
# Name: HVAC Unit 01
# Location: Building A - Roof
# Sensor Type: temperature
# Unit: F
# Generator: 1 (oscillate)
# Min: 68
# Max: 78
# Amplitude: 5
# Frequency: 0.5
```

### Add Pressure Sensor Monitor

```powershell
# Edit config/monitors.json directly
{
  "monitors": {
    "pressure-sensor-01": {
      "name": "Pressure Sensor 01",
      "location": "Tank Room - West",
      "sensors": [
        {
          "type": "pressure",
          "unit": "PSI",
          "generator": "oscillate",
          "min": 100.0,
          "max": 120.0,
          "amplitude": 10.0,
          "frequency": 0.6
        }
      ],
      "fields": {
        "Status": "Active",
        "DataQuality": "Good",
        "TankId": "TANK-001"
      }
    }
  }
}
```

### Run with New Config

```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages-dynamic.ps1
```

---

## Next Steps

1. ✅ Create your monitor configurations in `config/monitors.json`
2. ✅ Use `add-monitor.ps1` for easy interactive setup
3. ✅ Test with `auto-send-messages-dynamic.ps1`
4. ✅ Add corresponding subscribers with matching Monitor IDs
5. ✅ Monitor message flow in Publisher and Subscriber logs

The system now supports unlimited monitors and message types - all configured in JSON! 🎉
