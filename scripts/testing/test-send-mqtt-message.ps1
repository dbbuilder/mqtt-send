# Test MQTT Message Sending
# Publishes test messages to configured topics to demonstrate receiver routing

param(
    [string]$Topic = "sensor/device1/temperature",
    [decimal]$Value = 78.5
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "MQTT Message Test Sender" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Determine sensor type from topic
$sensorType = $Topic.Split('/')[-1]

# Create JSON payload
$payload = @{
    device_id = "device1"
    sensor_type = $sensorType
    value = $Value
    unit = if ($sensorType -eq "temperature") { "F" } else { "kPa" }
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json -Compress

Write-Host "Publishing message..." -ForegroundColor Yellow
Write-Host "  Topic: $Topic" -ForegroundColor Gray
Write-Host "  Payload: $payload" -ForegroundColor Gray
Write-Host ""

# Use mosquitto_pub to send the message
# Escape quotes for shell by replacing " with \"
$escapedPayload = $payload.Replace('"', '\"')
docker exec mosquitto sh -c "mosquitto_pub -t '$Topic' -m `"$escapedPayload`" -q 1"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - Message published successfully" -ForegroundColor Green
    Write-Host ""

    # Show what will happen
    Write-Host "Expected Receiver Behavior:" -ForegroundColor Cyan
    Write-Host ""

    if ($Topic -match "temperature" -and $Value -gt 75.0) {
        Write-Host "  Message will be routed to 3 tables:" -ForegroundColor Yellow
        Write-Host "    ✓ dbo.RawSensorData (all readings)" -ForegroundColor Green
        Write-Host "    ✓ dbo.SensorAlerts (Value > 75)" -ForegroundColor Green
        Write-Host "    ✓ dbo.SensorAggregates (hourly aggregate)" -ForegroundColor Green
    }
    elseif ($Topic -match "temperature") {
        Write-Host "  Message will be routed to 2 tables:" -ForegroundColor Yellow
        Write-Host "    ✓ dbo.RawSensorData (all readings)" -ForegroundColor Green
        Write-Host "    ✓ dbo.SensorAggregates (hourly aggregate)" -ForegroundColor Green
        Write-Host "    ✗ dbo.SensorAlerts (filter not met: Value not greater than 75)" -ForegroundColor DarkGray
    }
    elseif ($Topic -match "pressure") {
        Write-Host "  Message will be routed to 1 table:" -ForegroundColor Yellow
        Write-Host "    ✓ dbo.RawSensorData (all readings)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Check receiver logs and database tables to verify!" -ForegroundColor Cyan
    Write-Host ""
}
else {
    Write-Host "  ERROR - Failed to publish message" -ForegroundColor Red
    exit 1
}

# Examples
Write-Host ""
Write-Host "Try these variations:" -ForegroundColor Yellow
Write-Host "  .\test-send-mqtt-message.ps1 -Topic 'sensor/device1/temperature' -Value 78.5  # High temp alert" -ForegroundColor Gray
Write-Host "  .\test-send-mqtt-message.ps1 -Topic 'sensor/device1/temperature' -Value 70.0  # Normal temp" -ForegroundColor Gray
Write-Host "  .\test-send-mqtt-message.ps1 -Topic 'sensor/device2/pressure' -Value 101.3     # Pressure sensor" -ForegroundColor Gray
Write-Host ""
