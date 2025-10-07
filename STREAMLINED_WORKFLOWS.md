# Streamlined Workflows

## 🎯 Three Core Processes

This document streamlines the three main workflows: **Demo**, **Testing**, and **Deployment**.

---

## 1. 🎬 Demo Workflow (with Dashboard)

### Quick Demo (5 minutes)

```powershell
# One-time setup
cd /mnt/d/dev2/clients/mbox/mqtt-send
scripts/demo/demo.ps1 -Action init-db

# Run complete demo with dashboard
scripts/demo/demo.ps1 -Action full-demo-with-dashboard
```

### Manual Demo Workflow

```powershell
# Step 1: Clear old data
scripts/demo/demo.ps1 -Action clear-data

# Step 2: Start all services (opens 3 windows)
scripts/demo/demo.ps1 -Action start-receiver      # Window 1: Receiver
scripts/demo/demo.ps1 -Action start-publisher     # Window 2: Publisher
scripts/demo/demo.ps1 -Action start-dashboard     # Window 3: Dashboard

# Step 3: Send test messages
scripts/demo/demo.ps1 -Action send-test

# Step 4: View results
# - Browser: http://localhost:5000 (Dashboard)
# - CLI: scripts/demo/demo.ps1 -Action view-data

# Step 5: Stop all
scripts/demo/demo.ps1 -Action stop-all
```

### Dashboard Features

The MonitorDashboard provides real-time monitoring:
- **Message Volume**: Real-time chart of messages/second
- **Table Statistics**: Row counts and recent inserts
- **Health Status**: Service connectivity and errors
- **Recent Messages**: Live feed of processed messages

**Access**: http://localhost:5000

### Demo Script Features

| Command | Action |
|---------|--------|
| `demo.ps1` | Show status menu |
| `demo.ps1 -Action init-db` | Initialize database (first time only) |
| `demo.ps1 -Action clear-data` | Clear test data |
| `demo.ps1 -Action start-receiver` | Start ReceiverService |
| `demo.ps1 -Action start-publisher` | Start Publisher |
| `demo.ps1 -Action start-dashboard` | Start Dashboard |
| `demo.ps1 -Action send-test` | Send test MQTT messages |
| `demo.ps1 -Action view-data` | Show database results |
| `demo.ps1 -Action full-demo` | Automated full demo |
| `demo.ps1 -Action stop-all` | Stop all services |

---

## 2. 🧪 Testing Workflow

### Quick Test (2 minutes)

```powershell
# Complete system test
scripts/testing/test-complete-system.ps1

# Expected output:
# ✓ Database connection
# ✓ MQTT broker connection
# ✓ ReceiverService functionality
# ✓ Publisher functionality
# ✓ One-to-many routing (1 message → 3 tables)
# ✓ Conditional filtering (Value > 75)
# ✓ Stored procedure execution
```

### Comprehensive Testing

```bash
# 1. Unit Testing (Individual Components)
scripts/testing/test-connection.ps1          # Database & MQTT connectivity
scripts/testing/test-send-mqtt-message.ps1   # MQTT message sending
scripts/testing/test-enhanced-records.ps1    # Data insertion

# 2. Integration Testing
scripts/testing/run-complete-test.ps1        # Full integration test
scripts/testing/run-filtered-test.ps1        # Filtered message routing

# 3. Load Testing
scripts/demo/auto-send-messages.ps1          # Continuous message generation
scripts/demo/generate-tracked-table-data.ps1 # Large dataset generation

# 4. Verification
scripts/utility/verify-system-status.ps1     # System health check
scripts/utility/verify-tabled-published.ps1  # Publish verification
```

### Test Categories

**Functional Tests**
- Message routing (one-to-many)
- Conditional filtering (`Value > 75`)
- Stored procedure execution
- Field mapping (JSONPath)
- Topic wildcards (`+`, `#`)

**Resilience Tests**
- Database connection failure
- MQTT broker reconnection
- Invalid message handling
- Partial table failure isolation

**Performance Tests**
- 1000+ messages/minute throughput
- Multi-table insertion latency
- Auto-reload configuration change detection

### Test Data Generation

```powershell
# Generate continuous test data
scripts/demo/auto-send-messages-dynamic.ps1

# Generate database changes (for publisher testing)
scripts/demo/generate-tracked-table-data.ps1

# Add specific test messages
scripts/utility/add-test-message.ps1
```

---

## 3. 🚢 Deployment Workflow

### Azure Deployment (15 minutes)

```powershell
# Automated Azure deployment
scripts/deployment/Deploy-ToAzure.ps1 -ResourceGroup "rg-mqtt-bridge" -Location "eastus"

# What this does:
# 1. Creates Azure SQL Database
# 2. Deploys Mosquitto to Azure Container Instances
# 3. Creates App Services for ReceiverService and Publisher
# 4. Configures Key Vault for secrets
# 5. Sets up Application Insights monitoring
# 6. Runs database initialization scripts
```

### Manual Deployment Steps

#### Phase 1: Infrastructure (5 min)

```bash
# Azure SQL Database
az sql server create --name mqtt-bridge-sql --resource-group rg-mqtt-bridge --location eastus --admin-user sqladmin --admin-password "YourStrong@Passw0rd"
az sql db create --resource-group rg-mqtt-bridge --server mqtt-bridge-sql --name MqttBridge --service-objective S0

# Mosquitto MQTT Broker (Azure Container Instances)
az container create --resource-group rg-mqtt-bridge --name mosquitto --image eclipse-mosquitto --ports 1883 --ip-address public

# Key Vault
az keyvault create --name kv-mqtt-bridge --resource-group rg-mqtt-bridge --location eastus
```

#### Phase 2: Database Setup (2 min)

```bash
# Run initialization scripts
sqlcmd -S mqtt-bridge-sql.database.windows.net -U sqladmin -P "YourStrong@Passw0rd" -d MqttBridge -i sql/INIT_RECEIVER_SCHEMA.sql
sqlcmd -S mqtt-bridge-sql.database.windows.net -U sqladmin -P "YourStrong@Passw0rd" -d MqttBridge -i sql/LOAD_RECEIVER_DEMO.sql
```

#### Phase 3: Application Deployment (5 min)

```bash
# Build services
dotnet publish src/ReceiverService/ReceiverService.csproj -c Release -o ./publish/receiver
dotnet publish src/MultiTablePublisher/MultiTablePublisher.csproj -c Release -o ./publish/publisher

# Create App Services
az appservice plan create --name asp-mqtt-bridge --resource-group rg-mqtt-bridge --sku B1 --is-linux
az webapp create --resource-group rg-mqtt-bridge --plan asp-mqtt-bridge --name receiver-service --runtime "DOTNETCORE:9.0"
az webapp create --resource-group rg-mqtt-bridge --plan asp-mqtt-bridge --name publisher-service --runtime "DOTNETCORE:9.0"

# Deploy applications
az webapp deployment source config-zip --resource-group rg-mqtt-bridge --name receiver-service --src publish/receiver.zip
az webapp deployment source config-zip --resource-group rg-mqtt-bridge --name publisher-service --src publish/publisher.zip
```

#### Phase 4: Configuration (3 min)

```bash
# Store secrets in Key Vault
az keyvault secret set --vault-name kv-mqtt-bridge --name "SqlConnectionString" --value "Server=mqtt-bridge-sql.database.windows.net;Database=MqttBridge;User Id=sqladmin;Password=YourStrong@Passw0rd"

# Configure App Service settings
az webapp config appsettings set --resource-group rg-mqtt-bridge --name receiver-service --settings ConnectionStrings__MqttBridge="@Microsoft.KeyVault(SecretUri=https://kv-mqtt-bridge.vault.azure.net/secrets/SqlConnectionString/)"
az webapp config appsettings set --resource-group rg-mqtt-bridge --name receiver-service --settings MqttSettings__BrokerAddress="<mosquitto-ip>"
```

### Deployment Verification

```powershell
# Check service health
scripts/utility/verify-system-status.ps1 -Environment Azure

# Test end-to-end flow
scripts/testing/test-send-mqtt-message.ps1 -BrokerAddress "<azure-mosquitto-ip>"
```

### Deployment Checklist

- [ ] Azure resources created (SQL, Container Instances, App Services, Key Vault)
- [ ] Database schema initialized
- [ ] Demo configuration loaded
- [ ] Services deployed and running
- [ ] Secrets configured in Key Vault
- [ ] Application settings configured
- [ ] MQTT broker accessible
- [ ] End-to-end test successful
- [ ] Monitoring enabled (Application Insights)
- [ ] Auto-scaling configured (optional)

---

## 📊 Comparison Matrix

| Process | Time | Automation Level | Prerequisites |
|---------|------|------------------|---------------|
| **Demo** | 5 min | Fully automated | SQL Server, Docker, .NET 9 |
| **Testing** | 2-10 min | Fully automated | Running services |
| **Deployment** | 15 min | Semi-automated | Azure subscription |

---

## 🎯 Quick Reference Commands

### Demo
```powershell
scripts/demo/demo.ps1 -Action full-demo-with-dashboard
```

### Testing
```powershell
scripts/testing/test-complete-system.ps1
```

### Deployment
```powershell
scripts/deployment/Deploy-ToAzure.ps1 -ResourceGroup "rg-mqtt-bridge" -Location "eastus"
```

---

## 📖 Related Documentation

- **Demo Details**: `docs/guides/MULTI_WINDOW_DEMO.md`
- **Testing Guide**: `docs/testing/TESTING_GUIDE.md`
- **Deployment Guide**: `docs/deployment/AZURE_DEPLOYMENT.md`
- **Architecture**: `docs/architecture/PROJECT_SUMMARY.md`
