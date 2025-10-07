# Generate Data for Tracked Tables (TableA, TableB, TableC, TableD)
# This replaces the old auto-gen messages system

param(
    [int]$Count = 10,
    [string]$Table = "ALL",
    [int]$IntervalSeconds = 0
)

$ErrorActionPreference = "Stop"

function Insert-TableData {
    param(
        [string]$TableName,
        [int]$RecordCount
    )

    Write-Host "  Inserting $RecordCount records into $TableName..." -ForegroundColor Yellow

    $sql = switch ($TableName) {
        "TableA" {
@"
USE MqttBridge;
DECLARE @i INT = 0;
WHILE @i < $RecordCount
BEGIN
    INSERT INTO dbo.TableA (MonitorId, SensorType, Temperature, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'temperature',
        68 + (RAND() * 10),
        'F',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted $RecordCount records into TableA';
"@
        }
        "TableB" {
@"
USE MqttBridge;
DECLARE @i INT = 0;
WHILE @i < $RecordCount
BEGIN
    INSERT INTO dbo.TableB (MonitorId, SensorType, Pressure, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'pressure',
        100 + (RAND() * 5),
        'kPa',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted $RecordCount records into TableB';
"@
        }
        "TableC" {
@"
USE MqttBridge;
DECLARE @i INT = 0;
WHILE @i < $RecordCount
BEGIN
    INSERT INTO dbo.TableC (MonitorId, SensorType, FlowRate, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'flow',
        240 + (RAND() * 20),
        'L/min',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted $RecordCount records into TableC';
"@
        }
        "TableD" {
@"
USE MqttBridge;
DECLARE @i INT = 0;
WHILE @i < $RecordCount
BEGIN
    INSERT INTO dbo.TableD (MonitorId, SensorType, Humidity, Unit, Location)
    VALUES (
        CAST((@i % 10) + 1 AS NVARCHAR),
        'humidity',
        45 + (RAND() * 15),
        '%',
        'Building ' + CHAR(65 + (@i % 3)) + ' - Floor ' + CAST(((@i % 5) + 1) AS NVARCHAR)
    );
    SET @i = @i + 1;
END
PRINT 'Inserted $RecordCount records into TableD';
"@
        }
    }

    $password = "YourStrong@Passw0rd"
    $result = $sql | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $password -C -h -1 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ $RecordCount records inserted into $TableName" -ForegroundColor Green
    } else {
        Write-Host "    ✗ Failed to insert into $TableName" -ForegroundColor Red
    }
}

if ($IntervalSeconds -gt 0) {
    Write-Host "`n=== Continuous Data Generator ===" -ForegroundColor Cyan
    Write-Host "Generating $Count records every $IntervalSeconds seconds" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray

    $iteration = 1
    while ($true) {
        Write-Host "`n[Iteration $iteration - $(Get-Date -Format 'HH:mm:ss')]" -ForegroundColor Cyan

        if ($Table -eq "ALL") {
            Insert-TableData -TableName "TableA" -RecordCount $Count
            Insert-TableData -TableName "TableB" -RecordCount $Count
            Insert-TableData -TableName "TableC" -RecordCount $Count
            if (Test-Path -Path "D:\dev2\clients\mbox\mqtt-send\sql\TableD.sql" -PathType Leaf) {
                Insert-TableData -TableName "TableD" -RecordCount $Count
            }
        } else {
            Insert-TableData -TableName $Table -RecordCount $Count
        }

        $iteration++
        Start-Sleep -Seconds $IntervalSeconds
    }
} else {
    Write-Host "`n=== One-Time Data Generator ===" -ForegroundColor Cyan

    if ($Table -eq "ALL") {
        Write-Host "Generating $Count records for all tables`n" -ForegroundColor Yellow
        Insert-TableData -TableName "TableA" -RecordCount $Count
        Insert-TableData -TableName "TableB" -RecordCount $Count
        Insert-TableData -TableName "TableC" -RecordCount $Count

        # Check if TableD exists
        $checkTableD = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TableD' AND TABLE_SCHEMA = 'dbo';"
        $password = "YourStrong@Passw0rd"
        $tableExists = $checkTableD | docker exec -i sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $password -d MqttBridge -C -h -1 2>$null

        if ([int]($tableExists -replace '\s+', '') -gt 0) {
            Insert-TableData -TableName "TableD" -RecordCount $Count
        } else {
            Write-Host "  (TableD not created yet - skipping)" -ForegroundColor Gray
        }
    } else {
        Write-Host "Generating $Count records for $Table`n" -ForegroundColor Yellow
        Insert-TableData -TableName $Table -RecordCount $Count
    }

    Write-Host "`n✓ Data generation complete!`n" -ForegroundColor Green
}
