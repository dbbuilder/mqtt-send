# MQTT Message Bridge System - Requirements

## Overview
A distributed messaging system that reads messages from Azure SQL Server and publishes them to a Mosquitto MQTT broker, enabling monitor-specific message routing and consumption.

## Functional Requirements

### FR1: MQTT Broker Infrastructure
- **FR1.1**: Deploy Mosquitto MQTT broker using Docker
- **FR1.2**: Configure persistent storage for MQTT messages
- **FR1.3**: Enable authentication and ACL for security
- **FR1.4**: Configure logging for message tracking
- **FR1.5**: Expose MQTT on port 1883 (standard) and 9001 (WebSocket)

### FR2: SQL Server Message Storage
- **FR2.1**: Create table to store messages with monitorid, message content, timestamp, and processing status
- **FR2.2**: Implement stored procedure to retrieve unprocessed messages ordered by timestamp
- **FR2.3**: Implement stored procedure to mark messages as processed
- **FR2.4**: Support message priority ordering within each monitorid
- **FR2.5**: Maintain message audit trail

### FR3: Publisher Service (SQL to MQTT)
- **FR3.1**: Poll Azure SQL Server at configurable intervals
- **FR3.2**: Retrieve unprocessed messages via stored procedure
- **FR3.3**: Publish messages to MQTT topics formatted as `monitor/{monitorid}/messages`
- **FR3.4**: Update message status in SQL after successful MQTT publish
- **FR3.5**: Handle connection failures with retry logic (Polly)
- **FR3.6**: Log all publishing activities (Serilog)
- **FR3.7**: Run as background worker service

### FR4: Subscriber Service (MQTT to Consumer)
- **FR4.1**: Subscribe to MQTT topics filtered by monitorid
- **FR4.2**: Process messages in order of receipt
- **FR4.3**: Support multiple subscribers per monitorid
- **FR4.4**: Acknowledge message processing
- **FR4.5**: Handle malformed messages gracefully

### FR5: Message Ordering and Delivery
- **FR5.1**: Ensure FIFO (First In, First Out) ordering per monitorid
- **FR5.2**: Support QoS level 1 (at least once delivery)
- **FR5.3**: Prevent duplicate processing through idempotency keys
- **FR5.4**: Handle message expiration after configurable timeout

## Non-Functional Requirements

### NFR1: Security
- **NFR1.1**: Store SQL connection strings in Azure Key Vault
- **NFR1.2**: Use MQTT authentication with username/password
- **NFR1.3**: Encrypt MQTT traffic (TLS/SSL option)
- **NFR1.4**: Implement ACL to restrict topic access by monitorid

### NFR2: Performance
- **NFR2.1**: Support minimum 1000 messages per minute throughput
- **NFR2.2**: Process messages with maximum 5 second latency
- **NFR2.3**: Handle up to 100 concurrent monitorids

### NFR3: Reliability
- **NFR3.1**: Implement retry logic with exponential backoff (Polly)
- **NFR3.2**: Persist MQTT messages to disk
- **NFR3.3**: Log all errors and warnings to Application Insights
- **NFR3.4**: Health check endpoints for monitoring

### NFR4: Scalability
- **NFR4.1**: Design for horizontal scaling of publisher service
- **NFR4.2**: Support clustering for MQTT broker (future)
- **NFR4.3**: Partition messages by monitorid for parallel processing

### NFR5: Maintainability
- **NFR5.1**: Comprehensive inline code comments
- **NFR5.2**: Structured logging with correlation IDs
- **NFR5.3**: Configuration externalized to appsettings.json
- **NFR5.4**: Docker Compose for local development

## Technical Constraints

### TC1: Technology Stack
- Docker for containerization
- Mosquitto MQTT Broker version 2.x
- .NET Core 6.0 or higher
- Azure SQL Server
- Entity Framework Core (stored procedures only)
- Serilog for logging
- Polly for resilience
- MQTTnet client library

### TC2: Deployment Environment
- Azure Linux App Services for .NET services
- Azure SQL Database
- Azure Key Vault for secrets
- Azure Application Insights for monitoring
- Docker host for Mosquitto

### TC3: Development Standards
- T-SQL without semicolons
- No LINQ queries (stored procedures only)
- Full error handling on all external calls
- No dynamic SQL generation
- Complete code listings (no partial updates)

## Data Model

### Message Table Schema
- **MessageId**: Unique identifier (BIGINT IDENTITY)
- **MonitorId**: Monitor identifier (NVARCHAR(50))
- **MessageContent**: JSON or text payload (NVARCHAR(MAX))
- **Priority**: Message priority (INT, default 0)
- **CreatedDate**: Timestamp (DATETIME2)
- **ProcessedDate**: When published to MQTT (DATETIME2, nullable)
- **Status**: Processing status (NVARCHAR(20): Pending, Published, Failed)
- **RetryCount**: Number of retry attempts (INT, default 0)
- **CorrelationId**: For tracking (UNIQUEIDENTIFIER)

## Integration Points

### IP1: Azure SQL Server → Publisher Service
- Connection via Entity Framework Core
- Stored procedure execution only
- Connection pooling and resilience

### IP2: Publisher Service → MQTT Broker
- MQTTnet client library
- Persistent connection with automatic reconnection
- QoS 1 for guaranteed delivery

### IP3: MQTT Broker → Subscriber Service
- Topic subscription with wildcard support
- Message acknowledgment
- Connection monitoring

## Acceptance Criteria

1. Messages inserted into SQL table are published to MQTT within 10 seconds
2. Messages are delivered to subscribers in order per monitorid
3. System recovers automatically from SQL or MQTT connection failures
4. All operations are logged with appropriate severity levels
5. Configuration changes do not require code recompilation
6. Docker Compose brings up full local development environment
7. Services deploy successfully to Azure Linux App Services
8. Zero message loss under normal operating conditions
