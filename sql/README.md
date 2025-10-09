# SQL Scripts - MQTT Bridge Database

**Current as of**: 2025-10-09
**Source**: Azure SQL Database (mbox-eastasia.database.windows.net)
**Database**: MqttBridge

---

## 📁 Current Scripts (Production-Ready)

These scripts are **extracted directly from the Azure SQL production database** and represent the complete, current schema.

### Deployment Order

Execute scripts in numerical order for clean database deployment:

| Script | Purpose | Tables/Objects | Size |
|--------|---------|----------------|------|
| **01_CREATE_SCHEMAS.sql** | Create MQTT and Logging schemas | 2 schemas | 779 B |
| **02_CREATE_TABLES.sql** | Create all tables with columns | 14 tables | 12 KB |
| **03_CREATE_INDEXES.sql** | Create indexes and foreign keys | 29 indexes, 1 FK | 10 KB |
| **04_CREATE_STORED_PROCEDURES.sql** | Create all stored procedures | 24 procedures | 20 KB |
| **05_SEED_DATA.sql** | Load configuration data | 20 rows | 15 KB |

### Quick Deployment

```bash
# Local SQL Server
sqlcmd -S localhost,1433 -U sa -P "PASSWORD" -d MqttBridge -i 01_CREATE_SCHEMAS.sql
sqlcmd -S localhost,1433 -U sa -P "PASSWORD" -d MqttBridge -i 02_CREATE_TABLES.sql
sqlcmd -S localhost,1433 -U sa -P "PASSWORD" -d MqttBridge -i 03_CREATE_INDEXES.sql
sqlcmd -S localhost,1433 -U sa -P "PASSWORD" -d MqttBridge -i 04_CREATE_STORED_PROCEDURES.sql
sqlcmd -S localhost,1433 -U sa -P "PASSWORD" -d MqttBridge -i 05_SEED_DATA.sql

# Azure SQL Database
sqlcmd -S myserver.database.windows.net,1433 -U admin -P "PASSWORD" -d MqttBridge -C \
  -i 01_CREATE_SCHEMAS.sql \
  -i 02_CREATE_TABLES.sql \
  -i 03_CREATE_INDEXES.sql \
  -i 04_CREATE_STORED_PROCEDURES.sql \
  -i 05_SEED_DATA.sql
```

---

## 📊 Database Objects

### Schemas (2)
- `MQTT` - Receiver and Publisher configuration
- `Logging` - Application logging

### Tables (14)

#### dbo Schema (8 tables)
- `Messages` - Message queue
- `MqttSentRecords` - Published message tracking
- `RawSensorData` - Demo sensor data
- `SensorAggregates` - Demo aggregated sensor data
- `SensorAlerts` - Demo sensor alerts
- `TableA` - Demo publisher source table
- `TableB` - Demo publisher source table
- `TableC` - Demo publisher source table

#### Logging Schema (1 table)
- `ApplicationLogs` - Structured application logs (Serilog)

#### MQTT Schema (5 tables)
- `ReceiverConfig` - MQTT topic subscriptions and routing rules
- `ReceivedMessages` - Inbound MQTT message tracking
- `TopicTableMapping` - One-to-many topic-to-table routing
- `SourceConfig` - Publisher table monitoring configuration
- `SentRecords` - Outbound MQTT message tracking

### Stored Procedures (24)

#### dbo Schema (10 procedures)
- `GetPendingMessages` - Queue management
- `UpdateMessageStatus` - Message status updates
- `CleanupExpiredMessages` - Message retention
- `GetMessageStats` - Queue statistics
- `sp_MarkRecordsSent` - Publisher tracking
- `sp_CleanupMqttTracking` - Tracking cleanup
- `sp_GetUnsentRecords_TableA/B/C` - Publisher queries
- `UpdateSensorAggregate` - Demo aggregation

#### MQTT Schema (11 procedures)
- `GetActiveReceiverConfigs` - Load receiver config
- `LogReceivedMessage` - Message audit trail
- `UpdateReceivedMessageStatus` - Message tracking
- `AddReceiverConfig` - Dashboard API
- `AddTopicTableMapping` - Dashboard API
- `GetReceiverConfigCount` - Dashboard API
- `GetActiveConfigurations` - Publisher loader
- `GetUnsentRecords` - Publisher query
- `MarkRecordsSent` - Publisher tracking
- `CleanupSentRecords` - Tracking cleanup
- `AddSourceConfiguration` - Dashboard API

#### Logging Schema (3 procedures)
- `GetRecentLogs` - Dashboard log viewer
- `GetErrorStatistics` - Error monitoring
- `CleanupOldLogs` - Log retention

### Indexes (29)
- Primary keys on all tables
- Performance indexes on frequently queried columns
- Foreign key on `TopicTableMapping.ReceiverConfigId`

---

## 🔄 Seed Data

The `05_SEED_DATA.sql` script includes:

### MQTT.ReceiverConfig (7 configurations)
1. **General Test Topic** - `test/#` (all test messages)
2. **TableA Data** - `data/tableA/+` (device-specific TableA)
3. **TableB Data** - `data/tableB/+` (device-specific TableB)
4. **TableC Data** - `data/tableC/+` (device-specific TableC)
5. **Temperature Sensors** - `sensor/+/temperature` (all temp sensors)
6. **Humidity Sensors** - `sensor/+/humidity` (all humidity sensors)
7. **Pressure Sensors** - `sensor/+/pressure` (all pressure sensors)

### MQTT.TopicTableMapping (10 mappings)
- General test → `Messages` table
- TableA data → `TableA` table
- TableB data → `TableB` table
- TableC data → `TableC` table
- Temperature sensors → `RawSensorData`, `SensorAlerts` (if > 75°F), `SensorAggregates`
- Humidity sensors → `RawSensorData`
- Pressure sensors → `RawSensorData`

### MQTT.SourceConfig (3 publisher sources)
- `TableA` - Publish changes to `mqtt/data/tableA`
- `TableB` - Publish changes to `mqtt/data/tableB`
- `TableC` - Publish changes to `mqtt/data/tableC`

---

## 🗂️ Archive Folder

The `archive/` folder contains **outdated scripts** that were used during development but are now superseded by the numbered scripts above.

**Do NOT use archived scripts** - they may be incomplete or inconsistent with the current schema.

### Archived Scripts:
- Old initialization scripts (INIT_*.sql)
- Old setup scripts (SETUP_*.sql)
- Development migration scripts (AZURE_*.sql, MIGRATE_*.sql)
- Demo-specific scripts (ADD_DEMO_*.sql, *_DEMO_*.sql)
- Table-specific scripts (01_CreateMessagesTable.sql, etc.)

**When to reference archive**:
- Historical reference only
- Understanding schema evolution
- Debugging legacy deployments

---

## 🔧 Maintenance

### Updating Scripts

When the Azure SQL database schema changes:

1. **Extract updated schema**:
   ```bash
   # Use the Agent tool or manual extraction
   sqlcmd -S mbox-eastasia.database.windows.net,1433 -U mbox-admin -P PASSWORD -d MqttBridge -C -Q "SELECT ..."
   ```

2. **Regenerate numbered scripts**:
   - Update `02_CREATE_TABLES.sql` with new tables/columns
   - Update `03_CREATE_INDEXES.sql` with new indexes
   - Update `04_CREATE_STORED_PROCEDURES.sql` with new procedures
   - Update `05_SEED_DATA.sql` with new config data

3. **Test deployment**:
   ```bash
   # Deploy to local test database
   sqlcmd -S localhost -d MqttBridgeTest -i 01_CREATE_SCHEMAS.sql ...

   # Verify row counts
   sqlcmd -S localhost -d MqttBridgeTest -Q "SELECT COUNT(*) FROM MQTT.ReceiverConfig"
   ```

4. **Commit changes**:
   ```bash
   git add sql/
   git commit -m "Update schema: [description of changes]"
   ```

### Schema Version

Current scripts match Azure SQL database as of **2025-10-09**.

To check if your database is up-to-date:
```sql
-- Check table count
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('dbo', 'MQTT', 'Logging')
-- Expected: 14

-- Check stored procedure count
SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES
-- Expected: 24

-- Check receiver config count
SELECT COUNT(*) FROM MQTT.ReceiverConfig WHERE Enabled = 1
-- Expected: 7
```

---

## 📝 Notes

- All timestamps are UTC (`datetime2` type)
- Change Tracking is enabled on publisher source tables
- Identity columns use seed=1, increment=1
- Foreign keys use CASCADE for referential integrity
- Indexes are non-clustered unless specified

---

## 🆘 Troubleshooting

### "Database already exists"
```sql
-- Drop and recreate if needed
DROP DATABASE IF EXISTS MqttBridge;
CREATE DATABASE MqttBridge;
GO
USE MqttBridge;
GO
```

### "Schema already exists"
Scripts include `IF NOT EXISTS` checks - safe to re-run.

### "Table already exists"
Scripts include `DROP TABLE IF EXISTS` - safe to re-run.

### "Incorrect syntax near SCHEMABINDING"
You're running on SQL Server 2008 or earlier - these scripts require SQL Server 2012+.

---

**Last Updated**: 2025-10-09
**Extracted From**: Azure SQL Database (MqttBridge)
**Deployment Status**: ✅ Production-Ready
