# Insert Test Records into Source Tables
# Use this to continuously add records to see them published to MQTT

param(
    [int]$Count = 10,
    [string]$Table = "all"
)

Write-Host "`n=== Inserting Test Records ===`n" -ForegroundColor Cyan

$tablesSQL = @()

# TableA - Temperature
if ($Table -eq "all" -or $Table -eq "A") {
    $tableAInserts = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $monitorId = (Get-Random -Minimum 1 -Maximum 11)
        $temp = [math]::Round(68 + (Get-Random -Minimum 0 -Maximum 1000) / 100, 2)
        $tableAInserts += "('$monitorId', 'temperature', $temp, 'F', 'Building A - Floor 2')"
    }

    $tablesSQL += @"
INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location)
VALUES $($tableAInserts -join ',');
"@
}

# TableB - Pressure
if ($Table -eq "all" -or $Table -eq "B") {
    $tableBInserts = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $monitorId = (Get-Random -Minimum 1 -Maximum 11)
        $pressure = [math]::Round(100 + (Get-Random -Minimum 0 -Maximum 500) / 100, 2)
        $tableBInserts += "('$monitorId', 'pressure', $pressure, 'kPa', 'Building B - Floor 1')"
    }

    $tablesSQL += @"
INSERT INTO dbo.TableB (MonitorId, SensorType, Pressure, Unit, Location)
VALUES $($tableBInserts -join ',');
"@
}

# TableC - Flow
if ($Table -eq "all" -or $Table -eq "C") {
    $tableCInserts = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $monitorId = (Get-Random -Minimum 1 -Maximum 11)
        $flow = [math]::Round(240 + (Get-Random -Minimum 0 -Maximum 2000) / 100, 2)
        $tableCInserts += "('$monitorId', 'flow', $flow, 'L/min', 'Building C - Floor 3')"
    }

    $tablesSQL += @"
INSERT INTO dbo.TableC (MonitorId, SensorType, FlowRate, Unit, Location)
VALUES $($tableCInserts -join ',');
"@
}

# TableD - Humidity (if exists)
if ($Table -eq "all" -or $Table -eq "D") {
    # Check if TableD exists
    $checkTableD = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TableD' AND TABLE_SCHEMA = 'dbo';"
    $tableExists = $checkTableD | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>$null

    if ([int]($tableExists -replace '\s+', '') -gt 0) {
        $tableDInserts = @()
        for ($i = 0; $i -lt $Count; $i++) {
            $monitorId = (Get-Random -Minimum 1 -Maximum 11)
            $humidity = [math]::Round(45 + (Get-Random -Minimum 0 -Maximum 1500) / 100, 2)
            $tableDInserts += "('$monitorId', 'humidity', $humidity, '%', 'Building D - Floor 4')"
        }

        $tablesSQL += @"
INSERT INTO dbo.TableD (MonitorId, SensorType, Humidity, Unit, Location)
VALUES $($tableDInserts -join ',');
"@
    }
}

$fullSQL = $tablesSQL -join "`n"

$result = $fullSQL | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>&1

if ($LASTEXITCODE -eq 0) {
    $recordCount = switch ($Table) {
        "all" {
            # Check if TableD exists to calculate correct count
            $checkTableD = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TableD' AND TABLE_SCHEMA = 'dbo';"
            $tableExists = $checkTableD | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d MqttBridge -C -h -1 2>$null
            if ([int]($tableExists -replace '\s+', '') -gt 0) {
                $Count * 4
            } else {
                $Count * 3
            }
        }
        default { $Count }
    }
    Write-Host "+ Inserted $recordCount records successfully" -ForegroundColor Green
} else {
    Write-Host "- Failed to insert records!" -ForegroundColor Red
    Write-Host $result
}

Write-Host "`nThese records will be published to MQTT automatically by MultiTablePublisher`n" -ForegroundColor Cyan
