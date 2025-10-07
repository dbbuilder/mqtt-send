# TODO - Implementation Checklist

## Stage 1: Infrastructure Setup

### Docker and Mosquitto
- [x] Create docker-compose.yml for Mosquitto MQTT broker
- [x] Create mosquitto.conf with security and persistence settings
- [ ] Create MQTT password file using mosquitto_passwd
  ```bash
  docker run --rm -v $(pwd)/docker/mosquitto/passwords.txt:/tmp/passwords.txt eclipse-mosquitto mosquitto_passwd -b /tmp/passwords.txt mqttuser mqttpassword
  ```
- [ ] Start Docker containers
  ```bash
  cd docker
  docker-compose up -d
  ```
- [ ] Verify Mosquitto is running
  ```bash
  docker logs mosquitto
  docker exec mosquitto mosquitto_sub -t "test" -v
  ```

### Azure SQL Server
- [ ] Provision Azure SQL Database instance
- [ ] Configure firewall rules to allow connections
- [ ] Create database user for the application
- [ ] Grant appropriate permissions (EXECUTE on stored procedures)

## Stage 2: Database Implementation

### Schema Creation
- [x] Create Messages table script (01_CreateMessagesTable.sql)
- [ ] Execute table creation script on Azure SQL Server
- [ ] Verify table structure and indexes
  ```sql
  SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Messages'
  SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Messages')
  ```

### Stored Procedures
- [x] Create GetPendingMessages stored procedure
- [x] Create UpdateMessageStatus stored procedure
- [x] Create CleanupExpiredMessages stored procedure
- [x] Create GetMessageStats stored procedure
- [ ] Execute stored procedure script (02_CreateStoredProcedures.sql)
- [ ] Test stored procedures manually
  ```sql
  EXEC dbo.GetPendingMessages @BatchSize = 10
  EXEC dbo.GetMessageStats
  ```

### Test Data
- [ ] Insert test messages into Messages table
  ```sql
  INSERT INTO Messages (MonitorId, MessageContent, Priority, Status)
  VALUES ('MONITOR001', '{"temperature": 72.5, "humidity": 45}', 0, 'Pending')
  ```
- [ ] Verify test data retrieval
- [ ] Test different priority levels and monitor IDs

## Stage 3: Publisher Service Development

### Project Setup
- [x] Create PublisherService .NET worker project
- [x] Install required NuGet packages
- [ ] Verify all packages installed successfully
  ```bash
  cd src/PublisherService
  dotnet restore
  dotnet build
  ```

### Core Components
- [x] Create Message model class
- [x] Create MessageDbContext for stored procedure execution
- [x] Create MqttPublisherService with Polly resilience
- [x] Create Worker background service
- [x] Create Program.cs with dependency injection
- [x] Create appsettings.json configuration

### Configuration
- [ ] Update connection string in appsettings.json
  - [ ] Set Azure SQL connection string
  - [ ] Configure MQTT broker address and port
  - [ ] Set MQTT credentials
- [ ] Configure polling interval and batch size
- [ ] Set up logging configuration
- [ ] Configure Application Insights (optional)

### Testing Publisher Service
- [ ] Build PublisherService
  ```bash
  dotnet build
  ```
- [ ] Run locally in development mode
  ```bash
  dotnet run --environment Development
  ```
- [ ] Monitor logs for connection success
- [ ] Insert test message in SQL and verify publication
- [ ] Check MQTT broker receives messages
  ```bash
  docker exec mosquitto mosquitto_sub -h localhost -t "monitor/#" -v
  ```
- [ ] Verify message status updates in SQL table

## Stage 4: Subscriber Service Development

### Project Setup
- [x] Create SubscriberService .NET worker project
- [x] Install required NuGet packages
- [ ] Verify all packages installed successfully
  ```bash
  cd src/SubscriberService
  dotnet restore
  dotnet build
  ```

### Core Components
- [x] Create Worker with MQTT subscription logic
- [x] Create Program.cs with dependency injection
- [x] Create appsettings.json configuration

### Configuration
- [ ] Update MQTT broker settings in appsettings.json
  - [ ] Set broker address and port
  - [ ] Configure MQTT credentials
  - [ ] Set monitor filter (or leave empty for all)
- [ ] Configure logging

### Implement Business Logic
- [ ] Implement message processing logic in ProcessMessageAsync
- [ ] Add error handling for malformed messages
- [ ] Add idempotency handling if needed
- [ ] Add database persistence if required
- [ ] Add external API calls if needed

### Testing Subscriber Service
- [ ] Build SubscriberService
  ```bash
  dotnet build
  ```
- [ ] Run locally in development mode
  ```bash
  dotnet run --environment Development
  ```
- [ ] Verify subscription to topics
- [ ] Insert test messages and verify receipt
- [ ] Test with multiple monitor IDs
- [ ] Test error handling with invalid payloads

## Stage 5: Integration Testing

### End-to-End Testing
- [ ] Start all components (Mosquitto, Publisher, Subscriber)
- [ ] Insert messages for different monitor IDs
- [ ] Verify FIFO ordering per monitor
- [ ] Verify message processing updates SQL status
- [ ] Test with high message volume (100+ messages)
- [ ] Test priority ordering within monitor
- [ ] Test message expiration handling
- [ ] Test retry logic for failures

### Failure Scenarios
- [ ] Test SQL Server connection failure
  - [ ] Stop SQL Server temporarily
  - [ ] Verify Publisher service retries and reconnects
- [ ] Test MQTT broker failure
  - [ ] Stop Mosquitto container
  - [ ] Verify Publisher reconnects when broker restarts
  - [ ] Verify Subscriber reconnects and receives missed messages
- [ ] Test invalid messages
  - [ ] Insert malformed JSON
  - [ ] Verify error handling and logging
- [ ] Test maximum retry exceeded
  - [ ] Insert message and simulate repeated failures
  - [ ] Verify message marked as Failed after max retries

### Performance Testing
- [ ] Insert 1000+ messages
- [ ] Monitor processing throughput
- [ ] Check memory usage of services
- [ ] Verify no message loss
- [ ] Test with multiple subscribers

## Stage 6: Azure Deployment Preparation

### Azure Key Vault Setup
- [ ] Create Azure Key Vault instance
- [ ] Add connection string as secret
  ```bash
  az keyvault secret set --vault-name your-vault --name SqlConnectionString --value "Server=..."
  ```
- [ ] Add MQTT password as secret
- [ ] Configure Managed Identity for App Services
- [ ] Update appsettings.json with Key Vault references

### Application Insights Setup
- [ ] Create Application Insights resource
- [ ] Copy instrumentation key
- [ ] Update appsettings.json with instrumentation key
- [ ] Verify telemetry is being sent
- [ ] Create custom dashboards for monitoring

### Build and Publish
- [ ] Build PublisherService in Release mode
  ```bash
  dotnet publish -c Release -o ./publish
  ```
- [ ] Build SubscriberService in Release mode
  ```bash
  dotnet publish -c Release -o ./publish
  ```
- [ ] Review published files
- [ ] Test published builds locally

## Stage 7: Azure Deployment

### Mosquitto Deployment
- [ ] Decide on deployment option:
  - [ ] Azure Container Instances
  - [ ] Azure Kubernetes Service
  - [ ] Azure VM with Docker
- [ ] Deploy Mosquitto to chosen platform
- [ ] Configure networking and firewall rules
- [ ] Test connectivity from App Services
- [ ] Enable TLS/SSL for production (optional but recommended)

### Publisher Service Deployment
- [ ] Create Azure Linux App Service
- [ ] Configure application settings
  - [ ] Connection strings from Key Vault
  - [ ] MQTT broker address
  - [ ] Application Insights key
- [ ] Deploy PublisherService
  ```bash
  az webapp deployment source config-zip --resource-group your-rg --name publisher-app --src publish.zip
  ```
- [ ] Monitor deployment logs
- [ ] Verify service starts successfully
- [ ] Check Application Insights for telemetry

### Subscriber Service Deployment
- [ ] Create Azure Linux App Service
- [ ] Configure application settings
  - [ ] MQTT broker address
  - [ ] Monitor filter if needed
  - [ ] Application Insights key
- [ ] Deploy SubscriberService
  ```bash
  az webapp deployment source config-zip --resource-group your-rg --name subscriber-app --src publish.zip
  ```
- [ ] Monitor deployment logs
- [ ] Verify service starts successfully
- [ ] Check Application Insights for telemetry

### Post-Deployment Verification
- [ ] Insert test messages in SQL
- [ ] Verify PublisherService publishes to MQTT
- [ ] Verify SubscriberService receives messages
- [ ] Check all logs in Application Insights
- [ ] Verify no errors in Azure Portal
- [ ] Test failover and recovery
- [ ] Document production URLs and endpoints

## Stage 8: Monitoring and Operations

### Logging and Monitoring
- [ ] Configure log retention policies
- [ ] Set up Application Insights alerts
  - [ ] Alert on high error rate
  - [ ] Alert on service downtime
  - [ ] Alert on high message processing latency
- [ ] Create monitoring dashboard
- [ ] Set up availability tests

### Operational Procedures
- [ ] Document deployment procedure
- [ ] Document rollback procedure
- [ ] Create runbook for common issues
- [ ] Set up backup for MQTT persistence data
- [ ] Configure database backup and retention
- [ ] Implement message archival strategy

### Security Hardening
- [ ] Review and restrict SQL user permissions
- [ ] Enable MQTT TLS/SSL
- [ ] Configure MQTT ACL rules
- [ ] Review network security groups
- [ ] Enable Azure AD authentication
- [ ] Implement secret rotation policy
- [ ] Review and update firewall rules

## Stage 9: Documentation and Handoff

### Technical Documentation
- [x] Complete REQUIREMENTS.md
- [x] Complete README.md
- [x] Complete TODO.md (this file)
- [ ] Complete FUTURE.md
- [ ] Document API endpoints (if any)
- [ ] Document MQTT topic structure
- [ ] Document database schema

### Operational Documentation
- [ ] Create deployment guide
- [ ] Create troubleshooting guide
- [ ] Document configuration parameters
- [ ] Create monitoring guide
- [ ] Document backup/restore procedures
- [ ] Create incident response plan

### Knowledge Transfer
- [ ] Conduct code walkthrough session
- [ ] Train operations team on monitoring
- [ ] Train support team on troubleshooting
- [ ] Provide access to all resources
- [ ] Set up communication channels

## Priority Summary

### High Priority (Complete First)
1. Infrastructure Setup (Mosquitto + Azure SQL)
2. Database Implementation (Tables + Stored Procedures)
3. Publisher Service Core (Basic functionality)
4. Integration Testing (End-to-end flow)

### Medium Priority (Complete Second)
5. Subscriber Service Implementation
6. Azure Deployment Preparation
7. Production Deployment
8. Monitoring and Operations

### Low Priority (Complete Last)
9. Documentation and Handoff
10. Performance Optimization
11. Advanced Features (see FUTURE.md)

## Notes

- Mark items as complete by changing `[ ]` to `[x]`
- Add dates next to completed items for tracking
- Reference REQUIREMENTS.md for detailed specifications
- Reference FUTURE.md for enhancement ideas
- Update this file as new tasks are identified
