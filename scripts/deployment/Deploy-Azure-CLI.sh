#!/bin/bash
# Azure Deployment Script for MQTT Bridge System
# Uses Azure CLI to provision and deploy all required resources

set -e  # Exit on error

# ========================================
# Configuration Variables
# ========================================

RESOURCE_GROUP="rg-mqtt-bridge"
LOCATION="eastus"
SQL_SERVER_NAME="sql-mqtt-bridge-$(openssl rand -hex 4)"
SQL_DB_NAME="MqttBridge"
SQL_ADMIN_USER="mqttadmin"
SQL_ADMIN_PASSWORD="MqttBridge$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)!"

ACR_NAME="acrmqttbridge$(openssl rand -hex 4)"
APP_SERVICE_PLAN="asp-mqtt-bridge"
SKU="B1"  # Basic tier for cost savings

# App Service names
RECEIVER_APP="app-mqtt-receiver"
PUBLISHER_APP="app-mqtt-publisher"
DASHBOARD_APP="app-mqtt-dashboard"

# Container instances for MQTT broker
MQTT_CONTAINER="aci-mosquitto"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========================================
# Helper Functions
# ========================================

print_header() {
    echo ""
    echo -e "${CYAN}========================================"
    echo -e " $1"
    echo -e "========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# ========================================
# Prerequisites Check
# ========================================

print_header "Prerequisites Check"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
print_success "Azure CLI installed"

# Check if logged in
if ! az account show &> /dev/null; then
    print_warning "Not logged into Azure. Running 'az login'..."
    az login
fi
print_success "Azure CLI authenticated"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker not found. Required for building container images."
    exit 1
fi
print_success "Docker installed"

# ========================================
# Resource Group
# ========================================

print_header "Creating Resource Group"

az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --output none

print_success "Resource group created: $RESOURCE_GROUP"

# ========================================
# Azure SQL Database
# ========================================

print_header "Creating Azure SQL Database"

print_info "Creating SQL Server: $SQL_SERVER_NAME"
az sql server create \
    --name $SQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --admin-user $SQL_ADMIN_USER \
    --admin-password "$SQL_ADMIN_PASSWORD" \
    --output none

print_success "SQL Server created"

# Allow Azure services access
az sql server firewall-rule create \
    --server $SQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name AllowAzureServices \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    --output none

print_success "Firewall rule created (Azure services)"

# Create database
print_info "Creating database: $SQL_DB_NAME"
az sql db create \
    --server $SQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name $SQL_DB_NAME \
    --service-objective S0 \
    --output none

print_success "Database created"

# Enable Change Tracking
CONNECTION_STRING="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Database=$SQL_DB_NAME;User ID=$SQL_ADMIN_USER;Password=$SQL_ADMIN_PASSWORD;Encrypt=True;TrustServerCertificate=False;"

print_info "Enabling Change Tracking..."
sqlcmd -S "$SQL_SERVER_NAME.database.windows.net" -U $SQL_ADMIN_USER -P "$SQL_ADMIN_PASSWORD" -d $SQL_DB_NAME -Q "
ALTER DATABASE $SQL_DB_NAME SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON)
" 2>/dev/null || print_warning "Change Tracking may already be enabled"

print_success "SQL Database configured"

# ========================================
# Container Registry
# ========================================

print_header "Creating Azure Container Registry"

az acr create \
    --name $ACR_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Basic \
    --admin-enabled true \
    --output none

print_success "Container Registry created: $ACR_NAME"

# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"

print_info "ACR Login Server: $ACR_LOGIN_SERVER"

# ========================================
# Build and Push Container Images
# ========================================

print_header "Building and Pushing Container Images"

# Login to ACR
az acr login --name $ACR_NAME

# Build and push ReceiverService
print_info "Building ReceiverService..."
docker build -t $ACR_LOGIN_SERVER/receiver-service:latest \
    -f Dockerfile.ReceiverService \
    --build-arg TARGETARCH=amd64 \
    .
docker push $ACR_LOGIN_SERVER/receiver-service:latest
print_success "ReceiverService image pushed"

# Build and push PublisherService
print_info "Building PublisherService..."
docker build -t $ACR_LOGIN_SERVER/publisher-service:latest \
    -f Dockerfile.PublisherService \
    --build-arg TARGETARCH=amd64 \
    .
docker push $ACR_LOGIN_SERVER/publisher-service:latest
print_success "PublisherService image pushed"

# Build and push Dashboard
print_info "Building Dashboard..."
docker build -t $ACR_LOGIN_SERVER/dashboard:latest \
    -f Dockerfile.Dashboard \
    --build-arg TARGETARCH=amd64 \
    .
docker push $ACR_LOGIN_SERVER/dashboard:latest
print_success "Dashboard image pushed"

# ========================================
# MQTT Broker (Container Instance)
# ========================================

print_header "Deploying MQTT Broker"

az container create \
    --resource-group $RESOURCE_GROUP \
    --name $MQTT_CONTAINER \
    --image eclipse-mosquitto:2.0 \
    --cpu 1 \
    --memory 1 \
    --ports 1883 9001 \
    --ip-address Public \
    --output none

MQTT_IP=$(az container show --resource-group $RESOURCE_GROUP --name $MQTT_CONTAINER --query ipAddress.ip --output tsv)

print_success "MQTT Broker deployed at: $MQTT_IP:1883"

# ========================================
# App Service Plan
# ========================================

print_header "Creating App Service Plan"

az appservice plan create \
    --name $APP_SERVICE_PLAN \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --is-linux \
    --sku $SKU \
    --output none

print_success "App Service Plan created"

# ========================================
# Deploy ReceiverService
# ========================================

print_header "Deploying ReceiverService"

az webapp create \
    --name $RECEIVER_APP \
    --resource-group $RESOURCE_GROUP \
    --plan $APP_SERVICE_PLAN \
    --deployment-container-image-name $ACR_LOGIN_SERVER/receiver-service:latest \
    --output none

# Configure container registry credentials
az webapp config container set \
    --name $RECEIVER_APP \
    --resource-group $RESOURCE_GROUP \
    --docker-registry-server-url https://$ACR_LOGIN_SERVER \
    --docker-registry-server-user $ACR_USERNAME \
    --docker-registry-server-password $ACR_PASSWORD \
    --output none

# Set environment variables
az webapp config appsettings set \
    --name $RECEIVER_APP \
    --resource-group $RESOURCE_GROUP \
    --settings \
        ConnectionStrings__MqttBridge="$CONNECTION_STRING" \
        MqttSettings__BrokerAddress="$MQTT_IP" \
        MqttSettings__BrokerPort="1883" \
    --output none

print_success "ReceiverService deployed"

# ========================================
# Deploy PublisherService
# ========================================

print_header "Deploying PublisherService"

az webapp create \
    --name $PUBLISHER_APP \
    --resource-group $RESOURCE_GROUP \
    --plan $APP_SERVICE_PLAN \
    --deployment-container-image-name $ACR_LOGIN_SERVER/publisher-service:latest \
    --output none

az webapp config container set \
    --name $PUBLISHER_APP \
    --resource-group $RESOURCE_GROUP \
    --docker-registry-server-url https://$ACR_LOGIN_SERVER \
    --docker-registry-server-user $ACR_USERNAME \
    --docker-registry-server-password $ACR_PASSWORD \
    --output none

az webapp config appsettings set \
    --name $PUBLISHER_APP \
    --resource-group $RESOURCE_GROUP \
    --settings \
        ConnectionStrings__MqttBridge="$CONNECTION_STRING" \
        MqttSettings__BrokerAddress="$MQTT_IP" \
        MqttSettings__BrokerPort="1883" \
    --output none

print_success "PublisherService deployed"

# ========================================
# Deploy Dashboard
# ========================================

print_header "Deploying Monitor Dashboard"

az webapp create \
    --name $DASHBOARD_APP \
    --resource-group $RESOURCE_GROUP \
    --plan $APP_SERVICE_PLAN \
    --deployment-container-image-name $ACR_LOGIN_SERVER/dashboard:latest \
    --output none

az webapp config container set \
    --name $DASHBOARD_APP \
    --resource-group $RESOURCE_GROUP \
    --docker-registry-server-url https://$ACR_LOGIN_SERVER \
    --docker-registry-server-user $ACR_USERNAME \
    --docker-registry-server-password $ACR_PASSWORD \
    --output none

az webapp config appsettings set \
    --name $DASHBOARD_APP \
    --resource-group $RESOURCE_GROUP \
    --settings \
        ConnectionStrings__MqttBridge="$CONNECTION_STRING" \
    --output none

DASHBOARD_URL=$(az webapp show --name $DASHBOARD_APP --resource-group $RESOURCE_GROUP --query defaultHostName --output tsv)

print_success "Dashboard deployed at: https://$DASHBOARD_URL"

# ========================================
# Initialize Database Schema
# ========================================

print_header "Initializing Database Schema"

print_info "Running SQL initialization scripts..."

# Run initialization scripts in order
for script in sql/00_CreateMqttSchema.sql sql/INIT_RECEIVER_SCHEMA.sql sql/SETUP_MQTT_SYSTEM.sql sql/LOAD_RECEIVER_DEMO.sql; do
    if [ -f "$script" ]; then
        print_info "Executing: $script"
        sqlcmd -S "$SQL_SERVER_NAME.database.windows.net" \
                -U $SQL_ADMIN_USER \
                -P "$SQL_ADMIN_PASSWORD" \
                -d $SQL_DB_NAME \
                -i "$script" \
                -C || print_warning "Script may have partial errors: $script"
    fi
done

print_success "Database schema initialized"

# ========================================
# Deployment Summary
# ========================================

print_header "Deployment Complete!"

echo ""
echo -e "${GREEN}✓ All resources deployed successfully${NC}"
echo ""
echo -e "${CYAN}Resource Details:${NC}"
echo "──────────────────────────────────────"
echo "Resource Group:    $RESOURCE_GROUP"
echo "Location:          $LOCATION"
echo ""
echo "SQL Server:        $SQL_SERVER_NAME.database.windows.net"
echo "SQL Database:      $SQL_DB_NAME"
echo "SQL Admin User:    $SQL_ADMIN_USER"
echo ""
echo "MQTT Broker:       $MQTT_IP:1883"
echo ""
echo "Dashboard:         https://$DASHBOARD_URL"
echo "Receiver Service:  https://$RECEIVER_APP.azurewebsites.net"
echo "Publisher Service: https://$PUBLISHER_APP.azurewebsites.net"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "1. SQL Admin Password: $SQL_ADMIN_PASSWORD"
echo "   (Store this securely!)"
echo ""
echo "2. Open dashboard: https://$DASHBOARD_URL"
echo "   (May take 2-3 minutes to warm up)"
echo ""
echo "3. Configure firewall for your IP:"
echo "   az sql server firewall-rule create \\"
echo "     --server $SQL_SERVER_NAME \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --name MyIP \\"
echo "     --start-ip-address YOUR_IP \\"
echo "     --end-ip-address YOUR_IP"
echo ""

# Save deployment info to file
cat > deployment-info.txt <<EOF
MQTT Bridge System - Azure Deployment Details
Generated: $(date)

Resource Group: $RESOURCE_GROUP
Location: $LOCATION

SQL Server: $SQL_SERVER_NAME.database.windows.net
SQL Database: $SQL_DB_NAME
SQL Admin User: $SQL_ADMIN_USER
SQL Admin Password: $SQL_ADMIN_PASSWORD

MQTT Broker: $MQTT_IP:1883

Dashboard: https://$DASHBOARD_URL
Receiver Service: https://$RECEIVER_APP.azurewebsites.net
Publisher Service: https://$PUBLISHER_APP.azurewebsites.net

Container Registry: $ACR_LOGIN_SERVER
EOF

print_success "Deployment details saved to: deployment-info.txt"
print_warning "Keep deployment-info.txt secure (contains passwords)"

echo ""
