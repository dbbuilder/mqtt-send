# Azure Production Deployment Guide

**Platform:** .NET 9.0 | **MQTT:** Mosquitto 2.0 | **Database:** Azure SQL

## 🏗️ Architecture Options

### Option 1: Azure Container Apps (Recommended)
**Best for:** Microservices, auto-scaling, serverless containers

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Resource Group                  │
│                                                           │
│  ┌──────────────────┐      ┌────────────────────────┐   │
│  │  Azure SQL       │      │  Azure Container Apps   │   │
│  │  Database        │◄─────┤  Environment            │   │
│  │                  │      │                         │   │
│  │  - MqttBridge DB │      │  ┌──────────────────┐   │   │
│  │  - Auto-backup   │      │  │  Publisher App   │   │   │
│  └──────────────────┘      │  │  (auto-scale)    │   │   │
│                             │  └──────────────────┘   │   │
│  ┌──────────────────┐      │                         │   │
│  │  Azure Container │      │  ┌──────────────────┐   │   │
│  │  Registry (ACR)  │      │  │  Mosquitto MQTT  │   │   │
│  │                  │      │  │  (persistent)    │   │   │
│  │  - Publisher img │      │  └──────────────────┘   │   │
│  │  - Subscriber img│      │                         │   │
│  │  - Mosquitto img │      │  ┌──────────────────┐   │   │
│  └──────────────────┘      │  │  Subscriber 1    │   │   │
│                             │  │  (Monitor 1)     │   │   │
│  ┌──────────────────┐      │  └──────────────────┘   │   │
│  │  Azure Files     │      │                         │   │
│  │  (MQTT persist)  │      │  ┌──────────────────┐   │   │
│  └──────────────────┘      │  │  Subscriber 2    │   │   │
│                             │  │  (Monitor 2)     │   │   │
│  ┌──────────────────┐      │  └──────────────────┘   │   │
│  │  Key Vault       │      │                         │   │
│  │  - DB Password   │      └────────────────────────┘   │
│  │  - Secrets       │                                   │
│  └──────────────────┘                                   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Application Insights (Monitoring)                │   │
│  └──────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────┘
```

### Option 2: Azure Kubernetes Service (AKS)
**Best for:** Complex orchestration, large scale, K8s expertise

### Option 3: Azure App Service + IoT Hub
**Best for:** Managed services, Azure IoT native integration

---

## 📋 Prerequisites

1. **Azure Subscription** with Owner or Contributor access
2. **Azure CLI** installed (`az --version`)
3. **Docker** for building container images
4. **Git** for source control

---

## 🚀 Deployment Steps (Option 1: Container Apps)

### Step 1: Prepare Azure Environment

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create \
  --name mqtt-bridge-prod \
  --location eastus

# Create Azure Container Registry
az acr create \
  --resource-group mqtt-bridge-prod \
  --name mqttbridgeacr \
  --sku Basic \
  --admin-enabled true
```

### Step 2: Setup Azure SQL Database

```bash
# Create SQL Server
az sql server create \
  --resource-group mqtt-bridge-prod \
  --name mqtt-bridge-sql-server \
  --location eastus \
  --admin-user sqladmin \
  --admin-password 'YourStrongP@ssw0rd123!'

# Configure firewall (allow Azure services)
az sql server firewall-rule create \
  --resource-group mqtt-bridge-prod \
  --server mqtt-bridge-sql-server \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Create database
az sql db create \
  --resource-group mqtt-bridge-prod \
  --server mqtt-bridge-sql-server \
  --name MqttBridge \
  --service-objective S0 \
  --backup-storage-redundancy Local
```

### Step 3: Initialize Database Schema

```bash
# Get connection string
az sql db show-connection-string \
  --client sqlcmd \
  --name MqttBridge \
  --server mqtt-bridge-sql-server

# Run initialization scripts (from local)
sqlcmd -S mqtt-bridge-sql-server.database.windows.net \
  -U sqladmin -P 'YourStrongP@ssw0rd123!' \
  -d MqttBridge \
  -i sql/INIT_SCHEMA.sql
```

### Step 4: Create Azure Key Vault

```bash
# Create Key Vault
az keyvault create \
  --resource-group mqtt-bridge-prod \
  --name mqtt-bridge-kv \
  --location eastus

# Store secrets
az keyvault secret set \
  --vault-name mqtt-bridge-kv \
  --name SqlConnectionString \
  --value "Server=tcp:mqtt-bridge-sql-server.database.windows.net,1433;Database=MqttBridge;User ID=sqladmin;Password=YourStrongP@ssw0rd123!;Encrypt=True;TrustServerCertificate=False;"
```

### Step 5: Create Azure Files for MQTT Persistence

```bash
# Create storage account
az storage account create \
  --resource-group mqtt-bridge-prod \
  --name mqttbridgestorage \
  --location eastus \
  --sku Standard_LRS

# Create file share
az storage share create \
  --account-name mqttbridgestorage \
  --name mosquitto-data \
  --quota 10
```

### Step 6: Build and Push Container Images

```bash
# Login to ACR
az acr login --name mqttbridgeacr

# Build and push Publisher
docker build -t mqttbridgeacr.azurecr.io/publisher:latest \
  -f Dockerfile.Publisher .
docker push mqttbridgeacr.azurecr.io/publisher:latest

# Build and push Subscriber
docker build -t mqttbridgeacr.azurecr.io/subscriber:latest \
  -f Dockerfile.Subscriber .
docker push mqttbridgeacr.azurecr.io/subscriber:latest

# Build and push Mosquitto
docker build -t mqttbridgeacr.azurecr.io/mosquitto:latest \
  -f Dockerfile.Mosquitto .
docker push mqttbridgeacr.azurecr.io/mosquitto:latest
```

### Step 7: Create Container Apps Environment

```bash
# Create Application Insights
az monitor app-insights component create \
  --app mqtt-bridge-insights \
  --location eastus \
  --resource-group mqtt-bridge-prod \
  --application-type web

# Create Container Apps Environment
az containerapp env create \
  --resource-group mqtt-bridge-prod \
  --name mqtt-bridge-env \
  --location eastus \
  --logs-destination log-analytics
```

### Step 8: Deploy MQTT Broker (Mosquitto)

```bash
# Get ACR credentials
ACR_PASSWORD=$(az acr credential show \
  --name mqttbridgeacr \
  --query "passwords[0].value" -o tsv)

# Deploy Mosquitto
az containerapp create \
  --resource-group mqtt-bridge-prod \
  --name mosquitto \
  --environment mqtt-bridge-env \
  --image mqttbridgeacr.azurecr.io/mosquitto:latest \
  --registry-server mqttbridgeacr.azurecr.io \
  --registry-username mqttbridgeacr \
  --registry-password $ACR_PASSWORD \
  --target-port 1883 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.5 \
  --memory 1Gi
```

### Step 9: Deploy Publisher

```bash
# Get secrets from Key Vault
SQL_CONN_STRING=$(az keyvault secret show \
  --vault-name mqtt-bridge-kv \
  --name SqlConnectionString \
  --query value -o tsv)

# Deploy Publisher
az containerapp create \
  --resource-group mqtt-bridge-prod \
  --name publisher \
  --environment mqtt-bridge-env \
  --image mqttbridgeacr.azurecr.io/publisher:latest \
  --registry-server mqttbridgeacr.azurecr.io \
  --registry-username mqttbridgeacr \
  --registry-password $ACR_PASSWORD \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1Gi \
  --env-vars \
    "ConnectionStrings__MqttBridge=$SQL_CONN_STRING" \
    "MqttBroker=mosquitto" \
    "MqttPort=1883" \
    "APPINSIGHTS_INSTRUMENTATIONKEY=YOUR_INSIGHTS_KEY"
```

### Step 10: Deploy Subscribers

```bash
# Deploy Subscriber 1 (Monitor 1)
az containerapp create \
  --resource-group mqtt-bridge-prod \
  --name subscriber-monitor1 \
  --environment mqtt-bridge-env \
  --image mqttbridgeacr.azurecr.io/subscriber:latest \
  --registry-server mqttbridgeacr.azurecr.io \
  --registry-username mqttbridgeacr \
  --registry-password $ACR_PASSWORD \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --env-vars \
    "MonitorFilter=1" \
    "ClientIdSuffix=Monitor1" \
    "MqttSettings__BrokerAddress=mosquitto" \
    "MqttSettings__BrokerPort=1883"

# Deploy Subscriber 2 (Monitor 2)
az containerapp create \
  --resource-group mqtt-bridge-prod \
  --name subscriber-monitor2 \
  --environment mqtt-bridge-env \
  --image mqttbridgeacr.azurecr.io/subscriber:latest \
  --registry-server mqttbridgeacr.azurecr.io \
  --registry-username mqttbridgeacr \
  --registry-password $ACR_PASSWORD \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --env-vars \
    "MonitorFilter=2" \
    "ClientIdSuffix=Monitor2" \
    "MqttSettings__BrokerAddress=mosquitto" \
    "MqttSettings__BrokerPort=1883"
```

---

## 📊 Monitoring & Observability

### Application Insights Queries

```kusto
// Publisher processing metrics
traces
| where customDimensions.CategoryName == "MultiTablePublisher.Worker"
| where message contains "Processing"
| summarize count() by bin(timestamp, 5m), tostring(customDimensions.TableName)

// Subscriber message routing
traces
| where customDimensions.CategoryName == "SubscriberService.Worker"
| where message contains "RECEIVED MESSAGE"
| summarize count() by bin(timestamp, 5m), tostring(customDimensions.MonitorId)

// Error tracking
exceptions
| where timestamp > ago(24h)
| summarize count() by type, outerMessage
| order by count_ desc
```

---

## 🔄 CI/CD with GitHub Actions

### Continuous Deployment

```yaml
# .github/workflows/deploy-azure.yml
name: Deploy to Azure

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Build Publisher
      run: |
        docker build -t mqttbridgeacr.azurecr.io/publisher:${{ github.sha }} \
          -f Dockerfile.Publisher .

    - name: Push to ACR
      run: |
        az acr login --name mqttbridgeacr
        docker push mqttbridgeacr.azurecr.io/publisher:${{ github.sha }}

    - name: Deploy Publisher
      run: |
        az containerapp update \
          --name publisher \
          --resource-group mqtt-bridge-prod \
          --image mqttbridgeacr.azurecr.io/publisher:${{ github.sha }}
```

---

## 💰 Cost Optimization

### Estimated Monthly Costs (East US)

| Service | SKU/Size | Estimated Cost |
|---------|----------|----------------|
| Azure SQL Database | S0 (10 DTU) | ~$15/month |
| Azure Container Apps (Publisher) | 0.5 vCPU, 1 GiB | ~$30/month |
| Azure Container Apps (Mosquitto) | 0.5 vCPU, 1 GiB | ~$30/month |
| Azure Container Apps (2 Subscribers) | 0.25 vCPU, 0.5 GiB each | ~$30/month |
| Azure Container Registry | Basic | ~$5/month |
| Azure Files | Standard, 10 GB | ~$2/month |
| Application Insights | First 5GB free | ~$10/month |
| **Total** | | **~$122/month** |

### Cost Optimization Tips

1. **Use Azure Reserved Instances** - Save up to 72% on SQL Database
2. **Auto-scaling** - Scale down subscribers during off-peak hours
3. **Use Azure SQL Serverless** - Pay only for compute you use
4. **Combine small workloads** - Run multiple subscribers in one container

---

## 🔒 Security Best Practices

1. **Managed Identity** - Use for Azure service authentication
2. **Private Endpoints** - Isolate SQL Database from public internet
3. **Virtual Network** - Deploy Container Apps in VNet
4. **Key Vault** - Store all secrets and connection strings
5. **Azure Policy** - Enforce security compliance
6. **RBAC** - Least privilege access control

---

## 🔧 Maintenance Tasks

### Database Backup & Restore

```bash
# Manual backup
az sql db export \
  --resource-group mqtt-bridge-prod \
  --server mqtt-bridge-sql-server \
  --name MqttBridge \
  --admin-user sqladmin \
  --admin-password 'YourStrongP@ssw0rd123!' \
  --storage-key-type StorageAccessKey \
  --storage-key $STORAGE_KEY \
  --storage-uri https://mqttbridgestorage.blob.core.windows.net/backups/mqttbridge.bacpac

# Restore from backup
az sql db import \
  --resource-group mqtt-bridge-prod \
  --server mqtt-bridge-sql-server \
  --name MqttBridge-Restored \
  --admin-user sqladmin \
  --admin-password 'YourStrongP@ssw0rd123!' \
  --storage-key-type StorageAccessKey \
  --storage-key $STORAGE_KEY \
  --storage-uri https://mqttbridgestorage.blob.core.windows.net/backups/mqttbridge.bacpac
```

### Scaling Operations

```bash
# Scale Publisher up
az containerapp update \
  --name publisher \
  --resource-group mqtt-bridge-prod \
  --min-replicas 2 \
  --max-replicas 10 \
  --cpu 1.0 \
  --memory 2Gi

# Scale SQL Database
az sql db update \
  --resource-group mqtt-bridge-prod \
  --server mqtt-bridge-sql-server \
  --name MqttBridge \
  --service-objective S1
```

---

## 🚨 Disaster Recovery

### Multi-Region Setup

```bash
# Create secondary region resources
az group create \
  --name mqtt-bridge-prod-dr \
  --location westus

# Setup geo-replication for SQL
az sql db replica create \
  --resource-group mqtt-bridge-prod-dr \
  --server mqtt-bridge-sql-server-dr \
  --name MqttBridge \
  --partner-server mqtt-bridge-sql-server \
  --partner-resource-group mqtt-bridge-prod

# Deploy Container Apps to DR region
az containerapp env create \
  --resource-group mqtt-bridge-prod-dr \
  --name mqtt-bridge-env-dr \
  --location westus
```

### Failover Process

1. **Automatic SQL Failover** - Configure auto-failover group
2. **Traffic Manager** - Route traffic to healthy region
3. **Container Apps** - Deploy same configuration to DR region
4. **Monitoring** - Alert on failover events

---

## ⚡ Performance Tuning

### Database Optimization

```sql
-- Add indexes for better query performance
CREATE NONCLUSTERED INDEX IX_SentRecords_SourceName_RecordId
ON MQTT.SentRecords(SourceName, RecordId)
INCLUDE (SentAt, CorrelationId);

-- Partition large tables
CREATE PARTITION FUNCTION PF_SentRecordsByDate (DATETIME2)
AS RANGE RIGHT FOR VALUES
('2024-01-01', '2024-02-01', '2024-03-01', ...);

-- Enable Query Store
ALTER DATABASE MqttBridge SET QUERY_STORE = ON;
```

### Container Apps Optimization

- Use **Dedicated plan** for predictable workloads
- Enable **Dapr** for service-to-service communication
- Configure **Custom scaling rules** based on queue depth or CPU
- Use **Azure Front Door** for global load balancing

---

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure SQL Database Best Practices](https://docs.microsoft.com/azure/sql-database/best-practices)
- [Mosquitto MQTT Broker Guide](https://mosquitto.org/documentation/)
- [Application Insights Monitoring](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
