# Database Schema Extraction - Complete

## Overview
Complete database schema has been extracted from Azure SQL database `MqttBridge` and organized into numbered SQL scripts for easy deployment.

## Extraction Details
- **Source Database**: mbox-eastasia.database.windows.net
- **Database Name**: MqttBridge
- **Extraction Date**: 2025-10-09
- **Total Objects**: 14 tables, 24 stored procedures, 29 indexes, 1 foreign key

## Created Scripts

### 01_CREATE_SCHEMAS.sql (779 bytes)
Creates the MQTT and Logging schemas.

**Contents:**
- MQTT schema
- Logging schema

### 02_CREATE_TABLES.sql (12 KB)
Creates all 14 tables with complete column definitions, data types, nullability, defaults, primary keys, unique constraints, and check constraints.

**Tables Created:**
- **dbo Schema (8 tables)**:
  - Messages - Main message queue
  - MqttSentRecords - Publisher tracking
  - RawSensorData - Raw sensor data
  - SensorAggregates - Aggregated sensor data
  - SensorAlerts - Alert records
  - TableA - Temperature sensor table
  - TableB - Pressure sensor table
  - TableC - Flow sensor table

- **Logging Schema (1 table)**:
  - ApplicationLogs - Application log entries

- **MQTT Schema (5 tables)**:
  - ReceivedMessages - Received MQTT message log
  - ReceiverConfig - Receiver configuration
  - SentRecords - Publisher tracking (MQTT schema)
  - SourceConfig - Publisher source configuration
  - TopicTableMapping - Topic-to-table routing mappings

### 03_CREATE_INDEXES.sql (9.9 KB)
Creates all 29 non-clustered indexes and 1 foreign key constraint.

**Indexes by Table:**
- dbo.Messages: 3 indexes
- dbo.MqttSentRecords: 2 indexes
- dbo.SensorAlerts: 1 index
- dbo.TableA: 2 indexes
- dbo.TableB: 2 indexes
- dbo.TableC: 2 indexes
- Logging.ApplicationLogs: 3 indexes
- MQTT.ReceivedMessages: 3 indexes
- MQTT.ReceiverConfig: 1 index
- MQTT.SentRecords: 2 indexes
- MQTT.SourceConfig: 1 index
- MQTT.TopicTableMapping: 2 indexes

**Foreign Keys:**
- FK_TopicTableMapping_ReceiverConfig (TopicTableMapping.ReceiverConfigId -> ReceiverConfig.Id)

### 04_CREATE_STORED_PROCEDURES.sql (20 KB)
Creates all 24 stored procedures across three schemas.

**dbo Schema (10 procedures)**:
- GetPendingMessages - Retrieves pending messages
- UpdateMessageStatus - Updates message status
- CleanupExpiredMessages - Removes old messages
- GetMessageStats - Returns processing statistics
- sp_MarkRecordsSent - Marks records as sent
- sp_CleanupMqttTracking - Cleanup tracking records
- sp_GetUnsentRecords_TableA - Gets unsent TableA records
- sp_GetUnsentRecords_TableB - Gets unsent TableB records
- sp_GetUnsentRecords_TableC - Gets unsent TableC records
- UpdateSensorAggregate - Updates sensor aggregates

**MQTT Schema (11 procedures)**:
- GetActiveReceiverConfigs - Gets active receiver configurations with mappings
- LogReceivedMessage - Logs received MQTT message
- UpdateReceivedMessageStatus - Updates message processing status
- AddReceiverConfig - Adds new receiver configuration
- AddTopicTableMapping - Adds topic-to-table mapping
- GetReceiverConfigCount - Gets count for auto-reload detection
- GetActiveConfigurations - Gets active publisher configurations
- GetUnsentRecords - Generic unsent records query
- MarkRecordsSent - Marks records as sent (publisher)
- CleanupSentRecords - Cleanup old sent records
- AddSourceConfiguration - Adds new publisher source

**Logging Schema (3 procedures)**:
- GetRecentLogs - Retrieves recent log entries
- GetErrorStatistics - Returns error statistics
- CleanupOldLogs - Removes old log entries

### 05_SEED_DATA.sql (15 KB)
Seeds initial configuration data for ReceiverService and MultiTablePublisher.

**ReceiverConfig (7 configurations)**:
- TableA_Data (data/tableA/+)
- TableB_Data (data/tableB/+)
- TableC_Data (data/tableC/+)
- TemperatureSensors (sensor/+/temperature)
- PressureSensors (sensor/+/pressure)
- HumiditySensors (sensor/+/humidity)
- DashboardTests (test/#)

**TopicTableMapping (10 mappings)**:
- TableA_Data -> RawSensorData
- TableB_Data -> RawSensorData
- TableC_Data -> RawSensorData
- TemperatureSensors -> RawSensorData (Priority 100)
- TemperatureSensors -> SensorAlerts (Priority 90, filtered: Value > 75)
- PressureSensors -> RawSensorData
- HumiditySensors -> RawSensorData
- DashboardTests -> RawSensorData

**SourceConfig (3 sources)**:
- TableA (Temperature data) -> data/tableA/{MonitorId}
- TableB (Pressure data) -> data/tableB/{MonitorId}
- TableC (Flow data) -> data/tableC/{MonitorId}

## Deployment Instructions

To deploy to a new database:

```bash
# Option 1: Run each script in order
sqlcmd -S <server> -d MqttBridge -U <user> -P <password> -i 01_CREATE_SCHEMAS.sql
sqlcmd -S <server> -d MqttBridge -U <user> -P <password> -i 02_CREATE_TABLES.sql
sqlcmd -S <server> -d MqttBridge -U <user> -P <password> -i 03_CREATE_INDEXES.sql
sqlcmd -S <server> -d MqttBridge -U <user> -P <password> -i 04_CREATE_STORED_PROCEDURES.sql
sqlcmd -S <server> -d MqttBridge -U <user> -P <password> -i 05_SEED_DATA.sql

# Option 2: Run all at once (PowerShell)
Get-ChildItem "0*.sql" | Sort-Object Name | ForEach-Object {
    Write-Host "Executing $_..." -ForegroundColor Green
    sqlcmd -S <server> -d MqttBridge -U <user> -P <password> -i $_.FullName
}
```

## Key Features

### ReceiverService (MQTT -> Database)
- Database-driven configuration with auto-reload
- One-to-many routing (single message to multiple tables)
- Conditional filtering support (FilterExpression)
- Three insert modes: Direct, StoredProc, View
- Priority-based execution
- Error isolation (ContinueOnError)

### MultiTablePublisher (Database -> MQTT)
- Monitors multiple tables via SourceConfig
- Generic GetUnsentRecords procedure
- Deduplication tracking via SentRecords
- Configurable polling intervals
- Field mapping with JSONPath support

### Monitoring & Logging
- Structured logging to Logging.ApplicationLogs
- Message tracking in MQTT.ReceivedMessages
- Statistics procedures for monitoring
- Cleanup procedures for retention management

## Notes

- All timestamps use DATETIME2 with UTC (SYSUTCDATETIME() or GETUTCDATE())
- Auto-reload mechanism checks configuration every 30 seconds
- Scripts include IF EXISTS checks for safe re-execution
- Foreign key constraints ensure referential integrity
- Indexes optimized for query performance and monitoring

## Testing

After deployment, verify:

```sql
-- Check schema creation
SELECT * FROM sys.schemas WHERE name IN ('MQTT', 'Logging');

-- Check table creation
SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA IN ('dbo', 'MQTT', 'Logging')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Check stored procedures
SELECT SCHEMA_NAME(schema_id) AS schema_name, name
FROM sys.procedures
WHERE schema_id IN (SCHEMA_ID('dbo'), SCHEMA_ID('MQTT'), SCHEMA_ID('Logging'))
ORDER BY schema_name, name;

-- Check seed data
SELECT COUNT(*) AS ReceiverConfigCount FROM MQTT.ReceiverConfig;
SELECT COUNT(*) AS TopicTableMappingCount FROM MQTT.TopicTableMapping;
SELECT COUNT(*) AS SourceConfigCount FROM MQTT.SourceConfig;
```

## Troubleshooting

If deployment fails:
1. Ensure MqttBridge database exists
2. Check user permissions (CREATE TABLE, CREATE PROCEDURE)
3. Run scripts in order (schemas -> tables -> indexes -> procedures -> seed)
4. Review error messages for missing dependencies
5. Verify SQL Server version compatibility (2016+)

