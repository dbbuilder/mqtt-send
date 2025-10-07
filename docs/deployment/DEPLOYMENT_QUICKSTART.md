# Azure Deployment - Quick Start Guide

## 🎯 3-Step Deployment

### Prerequisites
- Azure CLI installed (`az --version`)
- Docker running locally
- Azure subscription access

---

## Step 1: Configure

Copy the example config and fill in your values:

```powershell
Copy-Item deploy-config.env.example deploy-config.env
notepad deploy-config.env
```

**Required values:**
```bash
AZURE_SUBSCRIPTION_ID="12345678-1234-1234-1234-123456789abc"
SQL_CONNECTION_STRING="Server=tcp:myserver.database.windows.net,1433;Database=MqttBridge;User ID=admin;Password=Pass123!;Encrypt=True;"
MQTT_BROKER_HOST="mqtt.mycompany.com"
MQTT_BROKER_PORT="1883"
ACR_NAME="mymqttacr"  # Must be globally unique
```

---

## Step 2: Deploy

```powershell
.\Deploy-ToAzure.ps1
```

This will:
1. ✅ Login to Azure
2. ✅ Create resource group and container registry
3. ✅ Build and push Docker images
4. ✅ Deploy Publisher and 2 Subscribers

**Time:** ~10-15 minutes

---

## Step 3: Verify

```bash
# Check deployment status
az containerapp list --resource-group mqtt-bridge-prod -o table

# View Publisher logs
az containerapp logs show --name publisher --resource-group mqtt-bridge-prod --follow

# View Subscriber logs
az containerapp logs show --name subscriber-monitor1 --resource-group mqtt-bridge-prod --follow
```

---

## 🔄 Update Deployment

After code changes:

```powershell
# Rebuild and push images
az acr login --name mymqttacr
docker build -t mymqttacr.azurecr.io/publisher:latest -f Dockerfile.Publisher .
docker push mymqttacr.azurecr.io/publisher:latest

# Restart Publisher (pulls new image)
az containerapp update --name publisher --resource-group mqtt-bridge-prod --image mymqttacr.azurecr.io/publisher:latest
```

---

## 💰 Monthly Cost

| Component | Cost |
|-----------|------|
| Publisher (0.5 vCPU, 1GB) | ~$30 |
| 2x Subscribers (0.25 vCPU, 0.5GB) | ~$30 |
| Container Registry (Basic) | ~$5 |
| Log Analytics (5GB free) | ~$5 |
| **Total** | **~$70/month** |

---

## 🛡️ Security Best Practices

### Use Azure Key Vault (Recommended)

```bash
# Create Key Vault
az keyvault create --resource-group mqtt-bridge-prod --name mqtt-kv --location eastus

# Store SQL connection string
az keyvault secret set --vault-name mqtt-kv --name SqlConnectionString --value "Server=..."

# Update Publisher to use Key Vault
az containerapp update \
  --name publisher \
  --resource-group mqtt-bridge-prod \
  --set-env-vars "ConnectionStrings__MqttBridge=secretref:sqlconnectionstring"
```

### Enable Managed Identity

```bash
# Enable system-assigned identity
az containerapp identity assign --name publisher --resource-group mqtt-bridge-prod --system-assigned

# Grant access to Key Vault
PRINCIPAL_ID=$(az containerapp identity show --name publisher --resource-group mqtt-bridge-prod --query principalId -o tsv)
az keyvault set-policy --name mqtt-kv --object-id $PRINCIPAL_ID --secret-permissions get list
```

---

## 🔧 Common Operations

### Scale Publisher
```bash
az containerapp update \
  --name publisher \
  --resource-group mqtt-bridge-prod \
  --min-replicas 2 \
  --max-replicas 10
```

### Add More Subscribers
```bash
az containerapp create \
  --resource-group mqtt-bridge-prod \
  --name subscriber-monitor3 \
  --environment mqtt-bridge-env \
  --image mymqttacr.azurecr.io/subscriber:latest \
  --env-vars "MonitorFilter=3" "ClientIdSuffix=Monitor3" "MqttSettings__BrokerAddress=mqtt.mycompany.com" "MqttSettings__BrokerPort=1883"
```

### Delete Everything
```bash
az group delete --name mqtt-bridge-prod --yes --no-wait
```

---

## 🐛 Troubleshooting

### MQTT Connection Issues

**Check if MQTT broker is reachable from Azure:**
```bash
# Get Publisher's outbound IP
az containerapp show --name publisher --resource-group mqtt-bridge-prod --query properties.outboundIpAddresses

# Whitelist these IPs on your MQTT broker firewall
```

**Test MQTT connection:**
```bash
# Exec into Publisher container
az containerapp exec --name publisher --resource-group mqtt-bridge-prod --command /bin/sh

# Inside container
apt-get update && apt-get install -y telnet
telnet mqtt.mycompany.com 1883
```

### SQL Connection Issues

**Test connection string:**
```bash
# From local machine
sqlcmd -S tcp:myserver.database.windows.net,1433 -U admin -P 'Pass123!' -d MqttBridge -Q "SELECT @@VERSION"

# Verify Azure SQL firewall allows Azure services
az sql server firewall-rule create \
  --resource-group mqtt-bridge-prod \
  --server myserver \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Image Pull Errors

**If Container App can't pull images:**
```bash
# Verify ACR credentials
az acr credential show --name mymqttacr

# Update Container App with correct credentials
az containerapp update \
  --name publisher \
  --resource-group mqtt-bridge-prod \
  --set-env-vars "DOCKER_REGISTRY_SERVER_USERNAME=mymqttacr" "DOCKER_REGISTRY_SERVER_PASSWORD=<password>"
```

---

## 📊 Monitoring

### View Application Insights

```bash
# Get Application Insights connection string
az monitor app-insights component show \
  --app mqtt-bridge-insights \
  --resource-group mqtt-bridge-prod \
  --query connectionString -o tsv

# Add to Container Apps
az containerapp update \
  --name publisher \
  --resource-group mqtt-bridge-prod \
  --set-env-vars "APPLICATIONINSIGHTS_CONNECTION_STRING=<connection-string>"
```

### Common Queries

**Publisher processing rate:**
```kusto
traces
| where customDimensions.CategoryName contains "Publisher"
| summarize count() by bin(timestamp, 5m)
| render timechart
```

**Subscriber message count:**
```kusto
traces
| where message contains "RECEIVED MESSAGE"
| summarize count() by tostring(customDimensions.MonitorId), bin(timestamp, 5m)
| render timechart
```

---

## 📚 Additional Resources

- **Full deployment guide:** See `AZURE_DEPLOYMENT.md` for detailed options
- **Local development:** See `DEMO.md` for local testing
- **Architecture:** See `README.md` for system overview
