# Run MQTT Receiver Service
# Subscribes to configured MQTT topics and routes messages to database tables

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "MQTT Receiver Service" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting receiver... (Press Ctrl+C to stop)" -ForegroundColor Yellow
Write-Host ""

# Run the receiver
dotnet run --project src/ReceiverService/ReceiverService.csproj --configuration Release --no-build
