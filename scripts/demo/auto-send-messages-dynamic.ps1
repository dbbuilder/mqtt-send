# Dynamic Auto-Generate Messages
# Reads configuration from config/monitors.json

param(
    [int]$IntervalSeconds = 5,
    [int]$MessagesPerBatch = 2,
    [string]$ConfigPath = "config\monitors.json"
)

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Error: Config file not found at $ConfigPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$monitors = $config.monitors.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Id = $_.Name
        Config = $_.Value
    }
}

Write-Host "`n=== Dynamic Auto Message Generator ===`n" -ForegroundColor Cyan
Write-Host "Interval: $IntervalSeconds seconds" -ForegroundColor Gray
Write-Host "Messages per batch: $MessagesPerBatch per monitor" -ForegroundColor Gray
Write-Host "Monitors loaded: $($monitors.Count)" -ForegroundColor Gray
foreach ($mon in $monitors) {
    Write-Host "  - Monitor $($mon.Id): $($mon.Config.name) ($($mon.Config.sensors.Count) sensors)" -ForegroundColor Gray
}
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

$batchCount = 0
$totalMessages = 0

# Value generator functions
function Get-GeneratedValue {
    param(
        [PSCustomObject]$Sensor,
        [int]$BatchNumber,
        [int]$Index
    )

    switch ($Sensor.generator) {
        "oscillate" {
            $baseValue = ($Sensor.min + $Sensor.max) / 2
            $amplitude = if ($Sensor.amplitude) { $Sensor.amplitude } else { ($Sensor.max - $Sensor.min) / 2 }
            $frequency = if ($Sensor.frequency) { $Sensor.frequency } else { 0.5 }
            $phase = ($BatchNumber + $Index) * $frequency
            $value = $baseValue + ($amplitude * [math]::Sin($phase))
            return [math]::Round($value, 2)
        }
        "random" {
            $value = (Get-Random -Minimum ($Sensor.min * 100) -Maximum ($Sensor.max * 100)) / 100
            return [math]::Round($value, 2)
        }
        "linear" {
            $step = if ($Sensor.step) { $Sensor.step } else { 1 }
            $range = $Sensor.max - $Sensor.min
            $cycles = [math]::Floor($range / $step)
            $value = $Sensor.min + (($BatchNumber + $Index) % $cycles) * $step
            return [math]::Round($value, 2)
        }
        "static" {
            return $Sensor.value
        }
        default {
            return Get-Random -Minimum ($Sensor.min * 100) -Maximum ($Sensor.max * 100) / 100
        }
    }
}

try {
    while ($true) {
        $batchCount++
        $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

        Write-Host "[Batch $batchCount] Generating messages at $(Get-Date -Format 'HH:mm:ss')..." -ForegroundColor Cyan

        $insertStatements = @()

        foreach ($monitor in $monitors) {
            $monitorId = $monitor.Id
            $monitorConfig = $monitor.Config

            for ($i = 0; $i -lt $MessagesPerBatch; $i++) {
                # Pick a random sensor type for this monitor
                $sensor = $monitorConfig.sensors | Get-Random

                # Generate value using configured generator
                $value = Get-GeneratedValue -Sensor $sensor -BatchNumber $batchCount -Index $i

                # Build record with all fields
                $record = @{
                    RecordId = [guid]::NewGuid().ToString()
                    MonitorId = $monitorId
                    SensorType = $sensor.type
                    Value = $value
                    Unit = $sensor.unit
                    Timestamp = $timestamp
                    Location = $monitorConfig.location
                    AlertThreshold = $sensor.max
                    BatchNumber = $batchCount
                    SequenceNumber = $i + 1
                }

                # Add custom fields from config
                if ($monitorConfig.fields) {
                    foreach ($field in $monitorConfig.fields.PSObject.Properties) {
                        $record[$field.Name] = $field.Value
                    }
                }

                # Convert to JSON
                $content = $record | ConvertTo-Json -Compress

                # Escape single quotes for SQL
                $content = $content.Replace("'", "''")

                $insertStatements += "    ('$monitorId', '$content', 0, 'Pending')"

                Write-Host "  Monitor $monitorId : $($sensor.type) = $value $($sensor.unit)" -ForegroundColor Gray
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
            $messagesInBatch = $monitors.Count * $MessagesPerBatch
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
        Write-Host "`n=== Auto-Generator Stopped ===`n" -ForegroundColor Yellow
    } else {
        Write-Host "`nError: $_`n" -ForegroundColor Red
    }
}
finally {
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Total batches: $batchCount" -ForegroundColor Gray
    Write-Host "  Total messages: $totalMessages" -ForegroundColor Gray
    Write-Host ""
}
