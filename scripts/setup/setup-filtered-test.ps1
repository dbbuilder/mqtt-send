# Setup Filtered Test Data
# Creates messages for MonitorId "1" and "2" to test subscriber filtering

Write-Host "`n=== Setup Filtered Subscriber Test ===" -ForegroundColor Cyan

# Clear existing messages
Write-Host "`nClearing existing messages..." -ForegroundColor Yellow

$clearSql = "DELETE FROM MqttBridge.dbo.Messages"
$clearSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host " Failed to clear messages!" -ForegroundColor Red
    exit 1
}

Write-Host " Messages cleared" -ForegroundColor Green

# Insert test messages for Monitor 1 and Monitor 2
Write-Host "`nInserting test messages..." -ForegroundColor Yellow

$insertSql = @"
-- Messages for Monitor 1 (will go to Subscriber 1)
INSERT INTO MqttBridge.dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('1', '{"monitor": 1, "sensor": "temperature", "value": 72.5, "sequence": 1}', 0, 'Pending'),
    ('1', '{"monitor": 1, "sensor": "temperature", "value": 73.2, "sequence": 2}', 0, 'Pending'),
    ('1', '{"monitor": 1, "sensor": "temperature", "value": 74.0, "sequence": 3}', 0, 'Pending'),
    ('1', '{"monitor": 1, "sensor": "humidity", "value": 45, "sequence": 4}', 0, 'Pending'),
    ('1', '{"monitor": 1, "sensor": "humidity", "value": 46, "sequence": 5}', 0, 'Pending')

-- Messages for Monitor 2 (will go to Subscriber 2)
INSERT INTO MqttBridge.dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
    ('2', '{"monitor": 2, "sensor": "pressure", "value": 101.3, "sequence": 1}', 0, 'Pending'),
    ('2', '{"monitor": 2, "sensor": "pressure", "value": 101.5, "sequence": 2}', 0, 'Pending'),
    ('2', '{"monitor": 2, "sensor": "pressure", "value": 101.4, "sequence": 3}', 0, 'Pending'),
    ('2', '{"monitor": 2, "sensor": "flow", "value": 250.5, "sequence": 4}', 0, 'Pending'),
    ('2', '{"monitor": 2, "sensor": "flow", "value": 248.3, "sequence": 5}', 0, 'Pending')

-- Summary
SELECT
    MonitorId,
    COUNT(*) as MessageCount
FROM MqttBridge.dbo.Messages
GROUP BY MonitorId
ORDER BY MonitorId
"@

$result = $insertSql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C

if ($LASTEXITCODE -eq 0) {
    Write-Host " Test data created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host $result
} else {
    Write-Host " Failed to insert test data!" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Test Data Ready ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Message Distribution:" -ForegroundColor Yellow
Write-Host "  Monitor 1: 5 messages (temperature + humidity)" -ForegroundColor Gray
Write-Host "  Monitor 2: 5 messages (pressure + flow)" -ForegroundColor Gray
Write-Host ""
Write-Host "MQTT Topics:" -ForegroundColor Yellow
Write-Host "  monitor/1/messages -> Subscriber 1 ONLY" -ForegroundColor Gray
Write-Host "  monitor/2/messages -> Subscriber 2 ONLY" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run: " -NoNewline -ForegroundColor White
Write-Host "powershell -ExecutionPolicy Bypass -File run-filtered-test.ps1" -ForegroundColor Gray
Write-Host "  2. Watch each subscriber receive ONLY their filtered messages!" -ForegroundColor White
Write-Host ""
