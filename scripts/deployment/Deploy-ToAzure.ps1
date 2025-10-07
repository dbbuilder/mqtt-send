# Simplified Azure Deployment Script
# Deploys MQTT Bridge to Azure Container Apps with external MQTT broker

param(
    [string]$ConfigFile = "deploy-config.env"
)

$ErrorActionPreference = "Stop"

# Load configuration from .env file
if (-not (Test-Path $ConfigFile)) {
    Write-Host "❌ Configuration file not found: $ConfigFile" -ForegroundColor Red
    Write-Host "   Create it from deploy-config.env.example" -ForegroundColor Yellow
    exit 1
}

Write-Host "📄 Loading configuration from $ConfigFile..." -ForegroundColor Cyan

$config = @{}
Get-Content $ConfigFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)\s*=\s*"?([^"]+)"?\s*$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $config[$key] = $value
    }
}

# Validate required configuration
$required = @(
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_LOCATION",
    "SQL_CONNECTION_STRING",
    "MQTT_BROKER_HOST",
    "MQTT_BROKER_PORT",
    "ACR_NAME"
)

foreach ($key in $required) {
    if (-not $config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($config[$key])) {
        Write-Host "❌ Missing required configuration: $key" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "🚀 Starting Azure Deployment..." -ForegroundColor Green
Write-Host "  Subscription: $($config.AZURE_SUBSCRIPTION_ID)" -ForegroundColor Gray
Write-Host "  Resource Group: $($config.AZURE_RESOURCE_GROUP)" -ForegroundColor Gray
Write-Host "  Location: $($config.AZURE_LOCATION)" -ForegroundColor Gray
Write-Host "  MQTT Broker: $($config.MQTT_BROKER_HOST):$($config.MQTT_BROKER_PORT)" -ForegroundColor Gray
Write-Host ""

# Login to Azure
Write-Host "📝 Logging into Azure..." -ForegroundColor Yellow
az login
az account set --subscription $config.AZURE_SUBSCRIPTION_ID

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Azure login failed" -ForegroundColor Red
    exit 1
}

# Create Resource Group
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create `
    --name $config.AZURE_RESOURCE_GROUP `
    --location $config.AZURE_LOCATION

# Create Azure Container Registry
Write-Host "🐳 Creating container registry '$($config.ACR_NAME)'..." -ForegroundColor Yellow
az acr create `
    --resource-group $config.AZURE_RESOURCE_GROUP `
    --name $config.ACR_NAME `
    --sku Basic `
    --admin-enabled true

# Get ACR credentials
Write-Host "🔑 Getting ACR credentials..." -ForegroundColor Yellow
$acrPassword = az acr credential show `
    --name $config.ACR_NAME `
    --query "passwords[0].value" -o tsv

$acrServer = "$($config.ACR_NAME).azurecr.io"

# Login to ACR
Write-Host "🔐 Logging into ACR..." -ForegroundColor Yellow
az acr login --name $config.ACR_NAME

# Build and push Publisher image
Write-Host "🔨 Building Publisher Docker image..." -ForegroundColor Yellow
docker build -t "$acrServer/publisher:latest" -f Dockerfile.Publisher .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Publisher image build failed" -ForegroundColor Red
    exit 1
}

Write-Host "📤 Pushing Publisher image to ACR..." -ForegroundColor Yellow
docker push "$acrServer/publisher:latest"

# Build and push Subscriber image
Write-Host "🔨 Building Subscriber Docker image..." -ForegroundColor Yellow
docker build -t "$acrServer/subscriber:latest" -f Dockerfile.Subscriber .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Subscriber image build failed" -ForegroundColor Red
    exit 1
}

Write-Host "📤 Pushing Subscriber image to ACR..." -ForegroundColor Yellow
docker push "$acrServer/subscriber:latest"

# Create Container Apps Environment
Write-Host "🌐 Creating Container Apps environment..." -ForegroundColor Yellow
az containerapp env create `
    --resource-group $config.AZURE_RESOURCE_GROUP `
    --name "mqtt-bridge-env" `
    --location $config.AZURE_LOCATION `
    --logs-destination log-analytics

# Deploy Publisher
Write-Host "📤 Deploying Publisher..." -ForegroundColor Yellow
az containerapp create `
    --resource-group $config.AZURE_RESOURCE_GROUP `
    --name "publisher" `
    --environment "mqtt-bridge-env" `
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

# Deploy Subscriber 1 (Monitor 1)
Write-Host "📥 Deploying Subscriber 1 (Monitor 1)..." -ForegroundColor Yellow
az containerapp create `
    --resource-group $config.AZURE_RESOURCE_GROUP `
    --name "subscriber-monitor1" `
    --environment "mqtt-bridge-env" `
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

# Deploy Subscriber 2 (Monitor 2)
Write-Host "📥 Deploying Subscriber 2 (Monitor 2)..." -ForegroundColor Yellow
az containerapp create `
    --resource-group $config.AZURE_RESOURCE_GROUP `
    --name "subscriber-monitor2" `
    --environment "mqtt-bridge-env" `
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

Write-Host ""
Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 View deployments:" -ForegroundColor Cyan
Write-Host "  az containerapp list --resource-group $($config.AZURE_RESOURCE_GROUP) -o table" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 View Publisher logs:" -ForegroundColor Cyan
Write-Host "  az containerapp logs show --name publisher --resource-group $($config.AZURE_RESOURCE_GROUP) --follow" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 View Subscriber logs:" -ForegroundColor Cyan
Write-Host "  az containerapp logs show --name subscriber-monitor1 --resource-group $($config.AZURE_RESOURCE_GROUP) --follow" -ForegroundColor Gray
Write-Host ""
