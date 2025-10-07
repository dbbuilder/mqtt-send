# Stop All Running Services
# Stops Publisher and Subscriber processes

Write-Host "`n=== Stopping Services ===" -ForegroundColor Cyan

$stopped = $false

# Stop Publisher
$pubProcess = Get-Process -Name "PublisherService" -ErrorAction SilentlyContinue
if ($pubProcess) {
    Write-Host "Stopping PublisherService..." -ForegroundColor Yellow
    Stop-Process -Name "PublisherService" -Force
    $stopped = $true
}

# Stop Subscriber
$subProcess = Get-Process -Name "SubscriberService" -ErrorAction SilentlyContinue
if ($subProcess) {
    Write-Host "Stopping SubscriberService..." -ForegroundColor Yellow
    Stop-Process -Name "SubscriberService" -Force
    $stopped = $true
}

if ($stopped) {
    Start-Sleep -Seconds 2
    Write-Host " Services stopped!" -ForegroundColor Green
} else {
    Write-Host " No services were running" -ForegroundColor Gray
}

Write-Host ""
