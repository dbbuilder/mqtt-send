# Auto-Generate Messages
# Continuously inserts messages every N seconds for testing

param(
    [int]$IntervalSeconds = 5,
    [int]$MessagesPerBatch = 2,
    [string[]]$MonitorIds = @("1", "2"),
    [switch]$RandomData
)

Write-Host "`n=== Auto Message Generator ===" -ForegroundColor Cyan
Write-Host "Interval: $IntervalSeconds seconds" -ForegroundColor Gray
Write-Host "Messages per batch: $MessagesPerBatch per monitor" -ForegroundColor Gray
Write-Host "Monitor IDs: $($MonitorIds -join ', ')" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

$batchCount = 0
$totalMessages = 0

# Sensor data generators
$sensors = @{
    "1" = @(
        @{name="temperature"; min=68.0; max=78.0; unit="F"},
        @{name="humidity"; min=35; max=55; unit="%"}
    )
    "2" = @(
        @{name="pressure"; min=100.0; max=103.0; unit="kPa"},
        @{name="flow"; min=240.0; max=260.0; unit="L/min"}
    )
}

try {
    while ($true) {
        $batchCount++
        $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

        Write-Host "[Batch $batchCount] Generating messages at $(Get-Date -Format 'HH:mm:ss')..." -ForegroundColor Cyan

        $insertStatements = @()

        foreach ($monitorId in $MonitorIds) {
            $monitorSensors = $sensors[$monitorId]

            for ($i = 0; $i -lt $MessagesPerBatch; $i++) {
                # Pick a random sensor type for this monitor
                $sensor = $monitorSensors | Get-Random

                # Generate random value within range
                if ($RandomData) {
                    $value = [math]::Round((Get-Random -Minimum ($sensor.min * 100) -Maximum ($sensor.max * 100)) / 100, 2)
                } else {
                    # Generate oscillating values for more interesting patterns
                    $baseValue = ($sensor.min + $sensor.max) / 2
                    $amplitude = ($sensor.max - $sensor.min) / 2
                    $phase = ($batchCount + $i) * 0.5
                    $value = [math]::Round($baseValue + ($amplitude * [math]::Sin($phase)), 2)
                }

                # Create complete record with all fields
                $content = @{
                    RecordId = [guid]::NewGuid().ToString()
                    MonitorId = $monitorId
                    SensorType = $sensor.name
                    Value = $value
                    Unit = $sensor.unit
                    Timestamp = $timestamp
                    Status = "Active"
                    Location = if ($monitorId -eq "1") { "Building A - Floor 2" } else { "Building B - Floor 1" }
                    AlertThreshold = $sensor.max
                    BatchNumber = $batchCount
                    SequenceNumber = $i + 1
                    DataQuality = "Good"
                } | ConvertTo-Json -Compress

                # Escape single quotes for SQL
                $content = $content.Replace("'", "''")

                $insertStatements += "    ('$monitorId', '$content', 0, 'Pending')"

                Write-Host "  Monitor $monitorId : $($sensor.name) = $value $($sensor.unit)" -ForegroundColor Gray
            }
        }

        # Build and execute SQL
        $sql = @"
INSERT INTO MqttBridge.dbo.Messages (MonitorId, MessageContent, Priority, Status)
VALUES
$($insertStatements -join ",`n")
"@

        $result = $sql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1

        if ($LASTEXITCODE -eq 0) {
            $messagesInBatch = $MonitorIds.Count * $MessagesPerBatch
            $totalMessages += $messagesInBatch
            Write-Host "  + Inserted $messagesInBatch messages (Total: $totalMessages)" -ForegroundColor Green
        } else {
            Write-Host "  - Failed to insert messages!" -ForegroundColor Red
            Write-Host $result
        }

        Write-Host ""

        # Wait for next batch
        Start-Sleep -Seconds $IntervalSeconds
    }
}
catch {
    if ($_.Exception.Message -match "Ctrl\+C") {
        Write-Host "`n=== Auto-Generator Stopped ===" -ForegroundColor Yellow
    } else {
        Write-Host "`nError: $_" -ForegroundColor Red
    }
}
finally {
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Total batches: $batchCount" -ForegroundColor Gray
    Write-Host "  Total messages: $totalMessages" -ForegroundColor Gray
    Write-Host ""
}
