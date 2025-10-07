#!/bin/bash
# Simple MQTT test script for WSL/Linux

TOPIC="${1:-sensor/device1/temperature}"
VALUE="${2:-70.0}"

# Determine sensor type from topic
SENSOR_TYPE=$(echo "$TOPIC" | awk -F/ '{print $NF}')

# Set unit based on sensor type
if [ "$SENSOR_TYPE" = "temperature" ]; then
    UNIT="F"
else
    UNIT="kPa"
fi

# Create JSON payload
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
PAYLOAD=$(cat <<EOF
{"device_id":"device1","sensor_type":"$SENSOR_TYPE","value":$VALUE,"unit":"$UNIT","timestamp":"$TIMESTAMP"}
EOF
)

echo "====================================="
echo "MQTT Message Test"
echo "====================================="
echo "Topic: $TOPIC"
echo "Payload: $PAYLOAD"
echo ""

# Send via docker exec
docker exec mosquitto mosquitto_pub -t "$TOPIC" -m "$PAYLOAD" -q 1

if [ $? -eq 0 ]; then
    echo "✓ Message published successfully"
else
    echo "✗ Failed to publish message"
fi
