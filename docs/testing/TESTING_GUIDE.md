# Complete Testing Guide - MQTT Message Bridge System

This guide walks you through testing the complete MQTT message bridge system from start to finish.

## Prerequisites

1. **Docker Desktop** - Must be running
2. **.NET 6.0 SDK** - For building the services
3. **SQL Server Management Studio or Azure Data Studio** (optional) - For viewing database

## Step-by-Step Testing Instructions

### Step 1: Start Docker Services

Start Docker Desktop, then run:

```bash
cd docker
docker-compose up -d
```

**Expected Output:**
```
Creating network "docker_mqtt-network" with driver "bridge"
Creating volume "docker_sqldata" with default driver
Creating sqlserver ... done
Creating mosquitto ... done
```

**Verify Services:**
```bash
docker ps
```

You should see both `sqlserver` and `mosquitto` containers running.

**Wait for SQL Server to be ready (about 30 seconds):**
```bash
docker logs sqlserver
```

Look for: `SQL Server is now ready for client connections`

### Step 2: Initialize Database

Run the SQL scripts in order to set up the database:

```bash
# Option 1: Using docker exec
docker exec -it sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -i /path/to/sql/00_CreateDatabase.sql

# Option 2: Use SQL Server Management Studio or Azure Data Studio
# Connect to: localhost,1433
# Username: sa
# Password: YourStrong@Passw0rd
# Then execute each script in order:
```

Execute these scripts in order:
1. `sql/00_CreateDatabase.sql` - Creates MqttBridge database
2. `sql/01_CreateMessagesTable.sql` - Creates Messages table with indexes
3. `sql/02_CreateStoredProcedures.sql` - Creates stored procedures
4. `sql/03_SeedData.sql` - Inserts test messages

**Expected Output from Seed Data:**
```
Seed Data Summary:
------------------
MonitorId          MessageCount  MinPriority  MaxPriority
ALARM_PANEL_5      2             0            0
DEVICE_A           2             0            0
GATEWAY_123        2             0            0
PUMP_STATION_07    2             0            1
SENSOR_001         3             0            0

Total Messages: 11
```

### Step 3: Build Publisher Service

```bash
cd src/PublisherService
dotnet restore
dotnet build
```

**Expected Output:**
```
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

### Step 4: Build Subscriber Service

```bash
cd src/SubscriberService
dotnet restore
dotnet build
```

**Expected Output:**
```
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

### Step 5: Start Subscriber Service (Terminal 1)

Open a terminal window and run:

```bash
cd src/SubscriberService
dotnet run --environment Development
```

**Expected Output:**
```
[20:45:30 INF] Starting Subscriber Service
[20:45:30 INF] Subscriber Worker started at: 10/05/2025 8:45:30 PM +00:00
[20:45:30 INF] Monitor Filter: +
[20:45:31 INF] Connected to MQTT broker at localhost:1883
[20:45:31 INF] Subscribed to topic: monitor/+/messages
```

Leave this terminal running.

### Step 6: Start Publisher Service (Terminal 2)

Open a **second** terminal window and run:

```bash
cd src/PublisherService
dotnet run --environment Development
```

**Expected Output:**
```
[20:46:00 INF] Starting Publisher Service
[20:46:00 INF] Publisher Worker started at: 10/05/2025 8:46:00 PM +00:00
[20:46:00 INF] Configuration - PollingInterval: 5s, BatchSize: 100, MaxRetryAttempts: 3
[20:46:01 INF] Connected to MQTT broker at localhost:1883
[20:46:01 INF] Processing 11 pending messages
[20:46:01 INF] Published message to topic monitor/SENSOR_001/messages with CorrelationId <guid>
[20:46:01 INF] Published message to topic monitor/SENSOR_001/messages with CorrelationId <guid>
...
[20:46:02 INF] Batch complete - Success: 11, Failures: 0
```

Leave this terminal running.

### Step 7: Watch Messages Flow (Terminal 1 - Subscriber)

In your Subscriber terminal, you should now see messages being received:

**Expected Output:**
```
[20:46:01 INF] ====================================
[20:46:01 INF] RECEIVED MESSAGE
[20:46:01 INF] MonitorId: SENSOR_001
[20:46:01 INF] Topic: monitor/SENSOR_001/messages
[20:46:01 INF] CorrelationId: <guid>
[20:46:01 INF] Payload: {"temperature": 72.5, "humidity": 45, "timestamp": "2025-10-05T20:00:00Z"}
[20:46:01 INF] ====================================
[20:46:01 INF] Message for Monitor SENSOR_001 processed successfully (CorrelationId: <guid>)
[20:46:01 INF]   Temperature: 72.5
[20:46:01 INF]   Humidity: 45
[20:46:01 INF] Processing complete for CorrelationId: <guid>
```

You should see **11 messages total** from 5 different monitors.

### Step 8: Verify Database Status

Check that all messages were marked as Published:

```sql
USE MqttBridge
GO

SELECT
    MessageId,
    MonitorId,
    Status,
    ProcessedDate,
    RetryCount,
    ErrorMessage
FROM dbo.Messages
ORDER BY MessageId
GO

-- Should show all Status = 'Published' and ProcessedDate populated
```

**Expected Result:**
All 11 messages should have:
- `Status = 'Published'`
- `ProcessedDate` with a timestamp
- `RetryCount = 0`
- `ErrorMessage = NULL`

### Step 9: Test Real-Time Message Insertion

While both services are running, insert a new message:

```sql
USE MqttBridge
GO

INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES ('TEST_MONITOR', '{"test": "real-time", "value": 999}', 0, 'Pending')
GO
```

**Expected Behavior:**

Within 5 seconds (polling interval), you should see:

**Publisher Terminal:**
```
[20:48:15 INF] Processing 1 pending messages
[20:48:15 INF] Published message to topic monitor/TEST_MONITOR/messages with CorrelationId <guid>
[20:48:15 INF] Batch complete - Success: 1, Failures: 0
```

**Subscriber Terminal:**
```
[20:48:15 INF] ====================================
[20:48:15 INF] RECEIVED MESSAGE
[20:48:15 INF] MonitorId: TEST_MONITOR
[20:48:15 INF] Topic: monitor/TEST_MONITOR/messages
[20:48:15 INF] Payload: {"test": "real-time", "value": 999}
[20:48:15 INF] ====================================
```

### Step 10: Test Monitor-Specific Filtering

Stop the current Subscriber service (Ctrl+C), then modify the filter:

**Edit `src/SubscriberService/appsettings.Development.json`:**
```json
{
  "SubscriberSettings": {
    "MonitorFilter": "SENSOR_001"
  }
}
```

Restart the Subscriber:
```bash
dotnet run --environment Development
```

Now insert messages for different monitors:
```sql
INSERT INTO dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('SENSOR_001', '{"filtered": "should see this"}', 0, 'Pending'),
    ('SENSOR_002', '{"filtered": "should NOT see this"}', 0, 'Pending')
```

**Expected Behavior:**
The Subscriber should ONLY receive the `SENSOR_001` message.

## Verification Checklist

- [ ] Docker containers running (sqlserver, mosquitto)
- [ ] Database created with tables and stored procedures
- [ ] 11 seed messages inserted
- [ ] Publisher Service connects to MQTT and SQL
- [ ] Subscriber Service connects to MQTT
- [ ] All 11 messages published and received
- [ ] Database shows all messages as 'Published'
- [ ] Real-time insertion works (within 5 seconds)
- [ ] Monitor filtering works correctly

## Troubleshooting

### Publisher can't connect to SQL Server
- Check SQL Server is running: `docker logs sqlserver`
- Verify connection string in `appsettings.json`
- Test connection: `docker exec -it sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd`

### Services can't connect to MQTT
- Check Mosquitto is running: `docker logs mosquitto`
- Verify port 1883 is accessible: `netstat -an | grep 1883`

### Messages not being published
- Check Publisher logs for errors
- Verify messages exist with Status='Pending': `SELECT * FROM Messages WHERE Status='Pending'`
- Check RetryCount and ErrorMessage columns

### Subscriber not receiving messages
- Verify MQTT subscription topic matches published topics
- Check Subscriber logs for connection status
- Use MQTT Explorer or mosquitto_sub to test: `docker exec mosquitto mosquitto_sub -t "monitor/#" -v`

## Success Criteria

✅ **Complete Success** if:
1. All 11 seed messages flow from SQL → Publisher → MQTT → Subscriber
2. Database shows all messages as 'Published' with ProcessedDate
3. Subscriber logs show all 11 messages with correct MonitorId and payload
4. Real-time message insertion works within 5 seconds
5. No errors in Publisher or Subscriber logs
6. Monitor filtering works as expected

## Next Steps

After successful testing:
1. Implement your custom business logic in `SubscriberService/Worker.cs::ProcessMessageContentAsync()`
2. Add Application Insights for production monitoring
3. Configure Azure Key Vault for connection strings
4. Deploy to Azure App Services
5. Enable TLS/SSL for MQTT in production
6. Implement message archival and cleanup strategies
