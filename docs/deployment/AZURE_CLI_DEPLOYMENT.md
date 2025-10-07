# Azure CLI Deployment Guide

## Quick Start

Deploy the entire MQTT Bridge system to Azure with a single command:

```bash
./scripts/deployment/Deploy-Azure-CLI.sh
```

**Time to deploy:** ~15-20 minutes
**Cost estimate:** ~$50-100/month (Basic tier)

---

## What Gets Deployed

### Azure Resources

1. **Resource Group** (`rg-mqtt-bridge`)
   - Container for all resources
   - Location: East US

2. **Azure SQL Database**
   - Server: `sql-mqtt-bridge-XXXX`
   - Database: `MqttBridge` (S0 tier)
   - Change Tracking enabled
   - Azure services firewall rule

3. **Azure Container Registry** (`acrmqttbridgeXXXX`)
   - Stores Docker images
   - Basic tier
   - Admin enabled

4. **MQTT Broker** (Container Instance)
   - Eclipse Mosquitto 2.0
   - Public IP with ports 1883, 9001
   - 1 CPU, 1 GB memory

5. **App Service Plan** (`asp-mqtt-bridge`)
   - Linux-based
   - B1 tier (Basic)
   - Shared across all apps

6. **Three Web Apps:**
   - **ReceiverService**: MQTT → Database
   - **PublisherService**: Database → MQTT
   - **Dashboard**: Web UI

---

## Prerequisites

### Required Tools

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Docker
sudo apt install docker.io

# SQL Server command-line tools (optional, for database init)
sudo apt install mssql-tools
```

### Azure Account

- Active Azure subscription
- Contributor role (or Owner)
- Enough quota for:
  - 1 SQL Server
  - 3 App Services (B1 tier)
  - 1 Container Instance

### Local Setup

```bash
# Clone repository
git clone https://github.com/dbbuilder/mqtt-send.git
cd mqtt-send

# Login to Azure
az login

# Set subscription (if you have multiple)
az account set --subscription "Your Subscription Name"
```

---

## Deployment Steps

### 1. Run Deployment Script

```bash
./scripts/deployment/Deploy-Azure-CLI.sh
```

The script will:
1. ✅ Check prerequisites (Azure CLI, Docker)
2. ✅ Create resource group
3. ✅ Provision Azure SQL Database
4. ✅ Create Container Registry
5. ✅ Build Docker images (ReceiverService, PublisherService, Dashboard)
6. ✅ Push images to ACR
7. ✅ Deploy MQTT broker (Mosquitto)
8. ✅ Create App Service Plan
9. ✅ Deploy three web apps
10. ✅ Initialize database schema
11. ✅ Save deployment info to `deployment-info.txt`

### 2. Review Deployment Info

```bash
cat deployment-info.txt
```

**Example output:**
```
MQTT Bridge System - Azure Deployment Details
Generated: 2025-10-06 12:34:56

Resource Group: rg-mqtt-bridge
Location: eastus

SQL Server: sql-mqtt-bridge-a1b2c3d4.database.windows.net
SQL Database: MqttBridge
SQL Admin User: mqttadmin
SQL Admin Password: MqttBridge7aK2mP4xL9qR!

MQTT Broker: 20.123.45.67:1883

Dashboard: https://app-mqtt-dashboard.azurewebsites.net
Receiver Service: https://app-mqtt-receiver.azurewebsites.net
Publisher Service: https://app-mqtt-publisher.azurewebsites.net

Container Registry: acrmqttbridgea1b2c3d4.azurecr.io
```

⚠️ **IMPORTANT:** Keep this file secure! It contains passwords.

### 3. Configure Your IP Address

Allow your IP to access SQL Server:

```bash
# Get your public IP
MY_IP=$(curl -s ifconfig.me)

# Add firewall rule
az sql server firewall-rule create \
  --server sql-mqtt-bridge-XXXX \
  --resource-group rg-mqtt-bridge \
  --name MyIP \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP
```

### 4. Open Dashboard

```bash
# Dashboard will be available at:
https://app-mqtt-dashboard.azurewebsites.net
```

**First load may take 2-3 minutes** (cold start).

---

## Post-Deployment Configuration

### Add Receiver Configurations

Use the dashboard Configuration page to add MQTT topic subscriptions:

1. Open: `https://app-mqtt-dashboard.azurewebsites.net/Configuration`
2. Select a template (e.g., "Temperature Sensors")
3. Customize if needed
4. Click "Add Configuration"
5. Services auto-reload within 30 seconds

### Test the System

**Option 1: Use Dashboard Test Buttons**
1. Open dashboard home page
2. Click "Normal Temp (72°F)" button
3. Wait 2-3 seconds
4. Check "Recent Messages" section

**Option 2: Send MQTT Message Manually**

```bash
# Install mosquitto clients
sudo apt install mosquitto-clients

# Get MQTT broker IP from deployment-info.txt
MQTT_IP=20.123.45.67

# Send test message
mosquitto_pub -h $MQTT_IP -t 'sensor/device1/temperature' \
  -m '{"device_id":"device1","sensor_type":"temperature","value":72.5,"unit":"F","timestamp":"2025-01-06T12:00:00.000Z"}' \
  -q 1
```

### Verify Database

```bash
# Connect to SQL Server
sqlcmd -S sql-mqtt-bridge-XXXX.database.windows.net \
       -U mqttadmin \
       -P 'YOUR_PASSWORD' \
       -d MqttBridge \
       -C

# Query received messages
SELECT TOP 10 * FROM MQTT.ReceivedMessages ORDER BY ReceivedAt DESC;
GO

SELECT TOP 10 * FROM dbo.RawSensorData ORDER BY ReceivedAt DESC;
GO
```

---

## Monitoring and Logs

### View Application Logs

```bash
# ReceiverService logs
az webapp log tail --name app-mqtt-receiver --resource-group rg-mqtt-bridge

# PublisherService logs
az webapp log tail --name app-mqtt-publisher --resource-group rg-mqtt-bridge

# Dashboard logs
az webapp log tail --name app-mqtt-dashboard --resource-group rg-mqtt-bridge
```

### Check Resource Status

```bash
# List all resources
az resource list --resource-group rg-mqtt-bridge --output table

# Check web app status
az webapp list --resource-group rg-mqtt-bridge --query "[].{Name:name,State:state,Url:defaultHostName}" --output table
```

### Dashboard Monitoring

Open the dashboard to see real-time metrics:
- System status (Receiver/Publisher ONLINE/OFFLINE)
- Message statistics (total, success, failed)
- Recent messages
- Live message flow

---

## Scaling and Performance

### Scale App Service Plan

```bash
# Upgrade to S1 (Standard tier)
az appservice plan update \
  --name asp-mqtt-bridge \
  --resource-group rg-mqtt-bridge \
  --sku S1
```

### Scale SQL Database

```bash
# Upgrade to S1 tier (more DTUs)
az sql db update \
  --server sql-mqtt-bridge-XXXX \
  --resource-group rg-mqtt-bridge \
  --name MqttBridge \
  --service-objective S1
```

### Add More App Instances

```bash
# Scale out ReceiverService to 2 instances
az webapp update \
  --name app-mqtt-receiver \
  --resource-group rg-mqtt-bridge \
  --instance-count 2
```

---

## Troubleshooting

### Services Show OFFLINE on Dashboard

**Cause:** Services may be in cold start or not receiving messages

**Solution:**
1. Wait 2-3 minutes for cold start
2. Send a test message via dashboard buttons
3. Check app logs: `az webapp log tail --name app-mqtt-receiver --resource-group rg-mqtt-bridge`

### MQTT Connection Failures

**Cause:** MQTT broker IP changed or firewall blocking

**Solution:**
```bash
# Get current MQTT broker IP
az container show \
  --resource-group rg-mqtt-bridge \
  --name aci-mosquitto \
  --query ipAddress.ip \
  --output tsv

# Update app settings with new IP
NEW_MQTT_IP=20.123.45.67

az webapp config appsettings set \
  --name app-mqtt-receiver \
  --resource-group rg-mqtt-bridge \
  --settings MqttSettings__BrokerAddress="$NEW_MQTT_IP"
```

### Database Connection Errors

**Cause:** Firewall blocking your IP

**Solution:**
```bash
# Add your current IP
MY_IP=$(curl -s ifconfig.me)

az sql server firewall-rule create \
  --server sql-mqtt-bridge-XXXX \
  --resource-group rg-mqtt-bridge \
  --name MyCurrentIP \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP
```

### Container Build Failures

**Cause:** Docker not running or permission issues

**Solution:**
```bash
# Start Docker daemon
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then retry deployment
```

---

## Cost Optimization

### Current Monthly Estimate

- **SQL Database (S0):** ~$15/month
- **App Service Plan (B1):** ~$13/month
- **Container Instance (1 CPU, 1GB):** ~$12/month
- **Container Registry (Basic):** ~$5/month
- **Outbound Data Transfer:** Variable

**Total:** ~$45-50/month base + data transfer

### Reduce Costs

**Option 1: Use Free Tier (Development Only)**
```bash
# Free App Service Plan (limited hours)
--sku F1

# SQL Database (Free tier - limited to 1)
--service-objective Free
```

**Option 2: Stop Non-Production Resources**
```bash
# Stop container instance when not in use
az container stop --resource-group rg-mqtt-bridge --name aci-mosquitto

# Delete app service plan (stop all apps)
az appservice plan delete --name asp-mqtt-bridge --resource-group rg-mqtt-bridge --yes
```

---

## Cleanup

### Delete All Resources

```bash
# Delete entire resource group (removes everything)
az group delete --name rg-mqtt-bridge --yes --no-wait
```

This removes:
- SQL Server and Database
- Container Registry and Images
- MQTT Broker Container
- App Service Plan and Web Apps
- All configuration and data

⚠️ **WARNING:** This is irreversible!

---

## CI/CD Integration

### Azure DevOps Pipeline

Create `azure-pipelines.yml`:

```yaml
trigger:
  - master

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Your-Service-Connection'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: 'scripts/deployment/Deploy-Azure-CLI.sh'
```

### GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Azure

on:
  push:
    branches: [ master ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy
        run: ./scripts/deployment/Deploy-Azure-CLI.sh
```

---

## Next Steps

1. ✅ Configure receiver topics via dashboard
2. ✅ Set up continuous deployment (CI/CD)
3. ✅ Configure alerts and monitoring
4. ✅ Enable Azure Application Insights
5. ✅ Set up custom domain (optional)
6. ✅ Configure SSL certificate (optional)

---

## Support

**Documentation:** https://github.com/dbbuilder/mqtt-send
**Issues:** https://github.com/dbbuilder/mqtt-send/issues

**Azure Support:** https://azure.microsoft.com/support/
