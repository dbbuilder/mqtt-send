# Simplified Azure Deployment Guide

Deploy the MQTT Bridge to Azure Container Apps with just **3 configuration values**.

## 📋 What You Need

1. **Azure Credentials** - Your Azure subscription access
2. **SQL Connection String** - Your SQL Server connection (Azure SQL or external)
3. **MQTT Broker Endpoint** - Your external MQTT server (host:port)

---

## 🚀 Quick Deployment (5 Minutes)

### Step 1: Prepare Your Configuration

Create a file `deploy-config.env` with your settings:

```bash
# Azure Configuration
AZURE_SUBSCRIPTION_ID="your-subscription-id"
AZURE_RESOURCE_GROUP="mqtt-bridge-prod"
AZURE_LOCATION="eastus"

# SQL Configuration (Azure SQL or external)
SQL_CONNECTION_STRING="Server=tcp:your-server.database.windows.net,1433;Database=MqttBridge;User ID=sqladmin;Password=YourPassword;Encrypt=True;"

# External MQTT Broker
MQTT_BROKER_HOST="mqtt.yourcompany.com"
MQTT_BROKER_PORT="1883"

# Optional: Container Registry Name (will be created)
ACR_NAME="mqttbridgeacr"
```

### Step 2: Run the Deployment Script

```bash
# Make script executable
chmod +x deploy-to-azure.sh

# Run deployment
./deploy-to-azure.sh
```

**That's it!** The script will:
- ✅ Create Azure Container Registry (ACR)
- ✅ Build and push Docker images
- ✅ Create Azure Container Apps Environment
- ✅ Deploy Publisher with your SQL + MQTT settings
- ✅ Deploy Subscriber instances with your MQTT settings

---

## 📝 Deployment Script

Save this as `deploy-to-azure.sh`:

```bash
#!/bin/bash
set -e

# Load configuration
source deploy-config.env

echo "🚀 Starting Azure Deployment..."
echo "  Resource Group: $AZURE_RESOURCE_GROUP"
echo "  Location: $AZURE_LOCATION"
echo "  MQTT Broker: $MQTT_BROKER_HOST:$MQTT_BROKER_PORT"

# Login to Azure
echo "📝 Logging into Azure..."
az login
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Create Resource Group
echo "📦 Creating resource group..."
az group create \
  --name "$AZURE_RESOURCE_GROUP" \
  --location "$AZURE_LOCATION"

# Create Azure Container Registry
echo "🐳 Creating container registry..."
az acr create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled true

# Get ACR credentials
ACR_PASSWORD=$(az acr credential show \
  --name "$ACR_NAME" \
  --query "passwords[0].value" -o tsv)

ACR_SERVER="${ACR_NAME}.azurecr.io"

# Build and push images
echo "🔨 Building and pushing Docker images..."
az acr login --name "$ACR_NAME"

docker build -t "$ACR_SERVER/publisher:latest" -f Dockerfile.Publisher .
docker push "$ACR_SERVER/publisher:latest"

docker build -t "$ACR_SERVER/subscriber:latest" -f Dockerfile.Subscriber .
docker push "$ACR_SERVER/subscriber:latest"

# Create Container Apps Environment
echo "🌐 Creating Container Apps environment..."
az containerapp env create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name mqtt-bridge-env \
  --location "$AZURE_LOCATION" \
  --logs-destination log-analytics

# Deploy Publisher
echo "📤 Deploying Publisher..."
az containerapp create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name publisher \
  --environment mqtt-bridge-env \
  --image "$ACR_SERVER/publisher:latest" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_NAME" \
  --registry-password "$ACR_PASSWORD" \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1Gi \
  --env-vars \
    "ConnectionStrings__MqttBridge=$SQL_CONNECTION_STRING" \
    "MqttBroker=$MQTT_BROKER_HOST" \
    "MqttPort=$MQTT_BROKER_PORT"

# Deploy Subscriber 1 (Monitor 1)
echo "📥 Deploying Subscriber 1..."
az containerapp create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name subscriber-monitor1 \
  --environment mqtt-bridge-env \
  --image "$ACR_SERVER/subscriber:latest" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_NAME" \
  --registry-password "$ACR_PASSWORD" \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --env-vars \
    "MonitorFilter=1" \
    "ClientIdSuffix=Monitor1" \
    "MqttSettings__BrokerAddress=$MQTT_BROKER_HOST" \
    "MqttSettings__BrokerPort=$MQTT_BROKER_PORT"

# Deploy Subscriber 2 (Monitor 2)
echo "📥 Deploying Subscriber 2..."
az containerapp create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name subscriber-monitor2 \
  --environment mqtt-bridge-env \
  --image "$ACR_SERVER/subscriber:latest" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_NAME" \
  --registry-password "$ACR_PASSWORD" \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --env-vars \
    "MonitorFilter=2" \
    "ClientIdSuffix=Monitor2" \
    "MqttSettings__BrokerAddress=$MQTT_BROKER_HOST" \
    "MqttSettings__BrokerPort=$MQTT_BROKER_PORT"

echo "✅ Deployment complete!"
echo ""
echo "📊 View your deployments:"
echo "  az containerapp list --resource-group $AZURE_RESOURCE_GROUP -o table"
echo ""
echo "📝 View logs:"
echo "  az containerapp logs show --name publisher --resource-group $AZURE_RESOURCE_GROUP --follow"
```

---

## 🪟 PowerShell Version

Save this as `Deploy-ToAzure.ps1`:

```powershell
# Load configuration
$config = Get-Content deploy-config.env | ConvertFrom-StringData

Write-Host "🚀 Starting Azure Deployment..." -ForegroundColor Cyan
Write-Host "  Resource Group: $($config.AZURE_RESOURCE_GROUP)" -ForegroundColor Gray
Write-Host "  MQTT Broker: $($config.MQTT_BROKER_HOST):$($config.MQTT_BROKER_PORT)" -ForegroundColor Gray

# Login to Azure
Write-Host "📝 Logging into Azure..." -ForegroundColor Yellow
az login
az account set --subscription $config.AZURE_SUBSCRIPTION_ID

# Create Resource Group
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create `
  --name $config.AZURE_RESOURCE_GROUP `
  --location $config.AZURE_LOCATION

# Create Azure Container Registry
Write-Host "🐳 Creating container registry..." -ForegroundColor Yellow
az acr create `
  --resource-group $config.AZURE_RESOURCE_GROUP `
  --name $config.ACR_NAME `
  --sku Basic `
  --admin-enabled true

# Get ACR credentials
$acrPassword = az acr credential show `
  --name $config.ACR_NAME `
  --query "passwords[0].value" -o tsv

$acrServer = "$($config.ACR_NAME).azurecr.io"

# Build and push images
Write-Host "🔨 Building and pushing Docker images..." -ForegroundColor Yellow
az acr login --name $config.ACR_NAME

docker build -t "$acrServer/publisher:latest" -f Dockerfile.Publisher .
docker push "$acrServer/publisher:latest"

docker build -t "$acrServer/subscriber:latest" -f Dockerfile.Subscriber .
docker push "$acrServer/subscriber:latest"

# Create Container Apps Environment
Write-Host "🌐 Creating Container Apps environment..." -ForegroundColor Yellow
az containerapp env create `
  --resource-group $config.AZURE_RESOURCE_GROUP `
  --name mqtt-bridge-env `
  --location $config.AZURE_LOCATION `
  --logs-destination log-analytics

# Deploy Publisher
Write-Host "📤 Deploying Publisher..." -ForegroundColor Yellow
az containerapp create `
  --resource-group $config.AZURE_RESOURCE_GROUP `
  --name publisher `
  --environment mqtt-bridge-env `
  --image "$acrServer/publisher:latest" `
  --registry-server $acrServer `
  --registry-username $config.ACR_NAME `
  --registry-password $acrPassword `
  --min-replicas 1 `
  --max-replicas 3 `
  --cpu 0.5 `
  --memory 1Gi `
  --env-vars `
    "ConnectionStrings__MqttBridge=$($config.SQL_CONNECTION_STRING)" `
    "MqttBroker=$($config.MQTT_BROKER_HOST)" `
    "MqttPort=$($config.MQTT_BROKER_PORT)"

# Deploy Subscriber 1
Write-Host "📥 Deploying Subscriber 1..." -ForegroundColor Yellow
az containerapp create `
  --resource-group $config.AZURE_RESOURCE_GROUP `
  --name subscriber-monitor1 `
  --environment mqtt-bridge-env `
  --image "$acrServer/subscriber:latest" `
  --registry-server $acrServer `
  --registry-username $config.ACR_NAME `
  --registry-password $acrPassword `
  --min-replicas 1 `
  --max-replicas 1 `
  --cpu 0.25 `
  --memory 0.5Gi `
  --env-vars `
    "MonitorFilter=1" `
    "ClientIdSuffix=Monitor1" `
    "MqttSettings__BrokerAddress=$($config.MQTT_BROKER_HOST)" `
    "MqttSettings__BrokerPort=$($config.MQTT_BROKER_PORT)"

# Deploy Subscriber 2
Write-Host "📥 Deploying Subscriber 2..." -ForegroundColor Yellow
az containerapp create `
  --resource-group $config.AZURE_RESOURCE_GROUP `
  --name subscriber-monitor2 `
  --environment mqtt-bridge-env `
  --image "$acrServer/subscriber:latest" `
  --registry-server $acrServer `
  --registry-username $config.ACR_NAME `
  --registry-password $acrPassword `
  --min-replicas 1 `
  --max-replicas 1 `
  --cpu 0.25 `
  --memory 0.5Gi `
  --env-vars `
    "MonitorFilter=2" `
    "ClientIdSuffix=Monitor2" `
    "MqttSettings__BrokerAddress=$($config.MQTT_BROKER_HOST)" `
    "MqttSettings__BrokerPort=$($config.MQTT_BROKER_PORT)"

Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 View deployments:" -ForegroundColor Cyan
Write-Host "  az containerapp list --resource-group $($config.AZURE_RESOURCE_GROUP) -o table" -ForegroundColor Gray
```

---

## 🔐 Using Azure Key Vault (Recommended)

For production, store secrets in Key Vault:

```bash
# Create Key Vault
az keyvault create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "mqtt-bridge-kv" \
  --location "$AZURE_LOCATION"

# Store SQL connection string
az keyvault secret set \
  --vault-name "mqtt-bridge-kv" \
  --name "SqlConnectionString" \
  --value "$SQL_CONNECTION_STRING"

# Update Container App to use Key Vault
az containerapp update \
  --name publisher \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --set-env-vars "ConnectionStrings__MqttBridge=secretref:sqlconnectionstring"
```

---

## 📊 Cost Estimate (External MQTT)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| Container Apps (Publisher) | 0.5 vCPU, 1 GiB | ~$30 |
| Container Apps (2 Subscribers) | 0.25 vCPU, 0.5 GiB each | ~$30 |
| Azure Container Registry | Basic | ~$5 |
| Log Analytics | First 5GB free | ~$5 |
| **Total** | | **~$70/month** |

*Savings: ~$52/month vs full deployment (no Mosquitto, no Azure SQL)*

---

## 🔄 Update Deployment

To update with new code:

```bash
# Rebuild and push images
docker build -t "$ACR_SERVER/publisher:latest" -f Dockerfile.Publisher .
docker push "$ACR_SERVER/publisher:latest"

# Update Container App (triggers restart)
az containerapp update \
  --name publisher \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --image "$ACR_SERVER/publisher:latest"
```

---

## 🛡️ Security Checklist

- ✅ Use Azure Key Vault for SQL connection string
- ✅ Enable VNET integration if MQTT broker is on-premise
- ✅ Use Managed Identity for ACR access (no passwords)
- ✅ Enable TLS for MQTT if supported by your broker
- ✅ Restrict Container Apps ingress to internal only

---

## 🐛 Troubleshooting

### View Publisher Logs
```bash
az containerapp logs show \
  --name publisher \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --follow
```

### View Subscriber Logs
```bash
az containerapp logs show \
  --name subscriber-monitor1 \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --follow
```

### Check Container App Status
```bash
az containerapp show \
  --name publisher \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query "{name:name, status:properties.provisioningState, fqdn:properties.configuration.ingress.fqdn}"
```

### Common Issues

**1. MQTT Connection Fails**
- Verify firewall allows Azure IPs to reach your MQTT broker
- Check MQTT broker logs for connection attempts
- Test with: `telnet $MQTT_BROKER_HOST $MQTT_BROKER_PORT`

**2. SQL Connection Fails**
- Verify SQL Server firewall allows Azure services
- Test connection string locally first
- Check for special characters in password (may need escaping)

**3. Image Build Fails**
- Ensure Docker is running
- Verify ACR credentials with: `az acr login --name $ACR_NAME`
- Check Dockerfile syntax

---

## 🎯 Next Steps

1. **Monitor Performance**: Set up Application Insights
2. **Auto-Scaling**: Configure based on CPU/memory/queue depth
3. **High Availability**: Deploy to multiple Azure regions
4. **CI/CD**: Integrate with GitHub Actions or Azure DevOps
