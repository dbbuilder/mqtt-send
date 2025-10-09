#Requires -Version 5.1
<#
.SYNOPSIS
    Copies all data from local Docker SQL Server to Azure SQL Database
.DESCRIPTION
    This script connects to both local and Azure SQL Server instances and copies
    all data from specified tables. It handles identity columns and preserves data integrity.
.PARAMETER SourceServer
    Source SQL Server connection string (default: Docker SQL Server)
.PARAMETER TargetServer
    Target SQL Server connection string (default: Azure SQL)
.PARAMETER SourceDatabase
    Source database name (default: MqttBridge)
.PARAMETER TargetDatabase
    Target database name (default: MqttBridge)
.PARAMETER Tables
    Array of tables to copy in format "Schema.TableName"
.PARAMETER TruncateTarget
    If specified, truncates target tables before copying
#>

param(
    [string]$SourceServer = "localhost,1433",
    [string]$SourceUser = "sa",
    [string]$SourcePassword = "YourStrong@Passw0rd",
    [string]$SourceDatabase = "MqttBridge",

    [string]$TargetServer = "mbox-eastasia.database.windows.net,1433",
    [string]$TargetUser = "mbox-admin",
    [string]$TargetPassword = "eTqEnC4KjnYbmDuraukP",
    [string]$TargetDatabase = "MqttBridge",

    [string[]]$Tables = @(
        "MQTT.SourceConfig",
        "MQTT.ReceiverConfig",
        "MQTT.TopicTableMapping",
        "MQTT.SentRecords",
        "MQTT.ReceivedMessages",
        "dbo.TableA",
        "dbo.TableB",
        "dbo.TableC",
        "dbo.RawSensorData"
    ),

    [switch]$TruncateTarget,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-SqlConnection {
    param(
        [string]$Server,
        [string]$Database,
        [string]$User,
        [string]$Password
    )

    $connStr = "Server=$Server;Database=$Database;User Id=$User;Password=$Password;TrustServerCertificate=True;Encrypt=True;Connection Timeout=30;"

    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
        $conn.Open()
        return $conn
    }
    catch {
        Write-ColorOutput "Failed to connect to $Server/$Database : $_" "Red"
        throw
    }
}

function Get-RowCount {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Schema,
        [string]$Table
    )

    $sql = "SELECT COUNT(*) FROM [$Schema].[$Table]"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($sql, $Connection)

    try {
        $count = $cmd.ExecuteScalar()
        return $count
    }
    catch {
        return 0
    }
}

function Test-HasIdentityColumn {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Schema,
        [string]$Table
    )

    $sql = @"
SELECT COUNT(*)
FROM sys.columns c
INNER JOIN sys.tables t ON c.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = @Schema
  AND t.name = @Table
  AND c.is_identity = 1
"@

    $cmd = New-Object System.Data.SqlClient.SqlCommand($sql, $Connection)
    $cmd.Parameters.AddWithValue("@Schema", $Schema) | Out-Null
    $cmd.Parameters.AddWithValue("@Table", $Table) | Out-Null

    $count = $cmd.ExecuteScalar()
    return ($count -gt 0)
}

function Copy-TableData {
    param(
        [System.Data.SqlClient.SqlConnection]$SourceConn,
        [System.Data.SqlClient.SqlConnection]$TargetConn,
        [string]$Schema,
        [string]$Table,
        [bool]$Truncate
    )

    Write-ColorOutput "`nProcessing $Schema.$Table..." "Cyan"

    # Get row counts
    $sourceCount = Get-RowCount -Connection $SourceConn -Schema $Schema -Table $Table
    $targetCount = Get-RowCount -Connection $TargetConn -Schema $Schema -Table $Table

    Write-ColorOutput "  Source rows: $sourceCount" "Gray"
    Write-ColorOutput "  Target rows (before): $targetCount" "Gray"

    if ($sourceCount -eq 0) {
        Write-ColorOutput "  Skipping - no data in source" "Yellow"
        return
    }

    if ($WhatIf) {
        Write-ColorOutput "  [WHATIF] Would copy $sourceCount rows" "Yellow"
        return
    }

    # Truncate target if requested
    if ($Truncate -and $targetCount -gt 0) {
        Write-ColorOutput "  Truncating target table..." "Yellow"
        $truncateSql = "TRUNCATE TABLE [$Schema].[$Table]"
        $truncateCmd = New-Object System.Data.SqlClient.SqlCommand($truncateSql, $TargetConn)
        try {
            $truncateCmd.ExecuteNonQuery() | Out-Null
            Write-ColorOutput "  Truncated successfully" "Green"
        }
        catch {
            Write-ColorOutput "  Truncate failed (table may have FK constraints): $_" "Yellow"
            Write-ColorOutput "  Trying DELETE instead..." "Yellow"
            $deleteSql = "DELETE FROM [$Schema].[$Table]"
            $deleteCmd = New-Object System.Data.SqlClient.SqlCommand($deleteSql, $TargetConn)
            $deleteCmd.ExecuteNonQuery() | Out-Null
        }
    }

    # Check for identity column
    $hasIdentity = Test-HasIdentityColumn -Connection $TargetConn -Schema $Schema -Table $Table

    if ($hasIdentity) {
        Write-ColorOutput "  Enabling IDENTITY_INSERT..." "Gray"
        $setIdentityOn = "SET IDENTITY_INSERT [$Schema].[$Table] ON"
        $identityCmd = New-Object System.Data.SqlClient.SqlCommand($setIdentityOn, $TargetConn)
        $identityCmd.ExecuteNonQuery() | Out-Null
    }

    # Read data from source
    $selectSql = "SELECT * FROM [$Schema].[$Table]"
    $selectCmd = New-Object System.Data.SqlClient.SqlCommand($selectSql, $SourceConn)
    $selectCmd.CommandTimeout = 300

    $reader = $selectCmd.ExecuteReader()

    # Get column names
    $columns = @()
    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
        $columns += $reader.GetName($i)
    }

    $columnList = ($columns | ForEach-Object { "[$_]" }) -join ", "
    $paramList = ($columns | ForEach-Object { "@$_" }) -join ", "

    $insertSql = "INSERT INTO [$Schema].[$Table] ($columnList) VALUES ($paramList)"

    $insertedCount = 0
    $batchSize = 100
    $batch = 0

    # Prepare insert command
    $insertCmd = New-Object System.Data.SqlClient.SqlCommand($insertSql, $TargetConn)
    $insertCmd.CommandTimeout = 300

    # Add parameters
    foreach ($col in $columns) {
        $param = $insertCmd.Parameters.Add("@$col", [System.Data.SqlDbType]::Variant)
        $param.SourceColumn = $col
    }

    # Insert rows
    while ($reader.Read()) {
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $colName = $reader.GetName($i)
            $value = $reader.GetValue($i)

            if ($value -is [System.DBNull]) {
                $insertCmd.Parameters["@$colName"].Value = [System.DBNull]::Value
            }
            else {
                $insertCmd.Parameters["@$colName"].Value = $value
            }
        }

        try {
            $insertCmd.ExecuteNonQuery() | Out-Null
            $insertedCount++

            if ($insertedCount % $batchSize -eq 0) {
                Write-ColorOutput "  Inserted $insertedCount rows..." "Gray"
            }
        }
        catch {
            Write-ColorOutput "  Error inserting row: $_" "Red"
        }
    }

    $reader.Close()

    if ($hasIdentity) {
        Write-ColorOutput "  Disabling IDENTITY_INSERT..." "Gray"
        $setIdentityOff = "SET IDENTITY_INSERT [$Schema].[$Table] OFF"
        $identityCmd = New-Object System.Data.SqlClient.SqlCommand($setIdentityOff, $TargetConn)
        $identityCmd.ExecuteNonQuery() | Out-Null
    }

    $finalCount = Get-RowCount -Connection $TargetConn -Schema $Schema -Table $Table
    Write-ColorOutput "  Completed - Inserted: $insertedCount, Final count: $finalCount" "Green"
}

# Main execution
Write-ColorOutput "`n==========================================================" "Cyan"
Write-ColorOutput "  SQL Server Data Copy Tool" "Cyan"
Write-ColorOutput "  Local Docker SQL -> Azure SQL" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

if ($WhatIf) {
    Write-ColorOutput "`n[WHATIF MODE - No changes will be made]`n" "Yellow"
}

Write-ColorOutput "`nSource: $SourceServer / $SourceDatabase" "Gray"
Write-ColorOutput "Target: $TargetServer / $TargetDatabase" "Gray"
Write-ColorOutput "Tables: $($Tables.Count) tables to copy`n" "Gray"

# Connect to source
Write-ColorOutput "Connecting to source SQL Server..." "Yellow"
$sourceConn = Get-SqlConnection -Server $SourceServer -Database $SourceDatabase -User $SourceUser -Password $SourcePassword
Write-ColorOutput "Connected to source" "Green"

# Connect to target
Write-ColorOutput "Connecting to target Azure SQL..." "Yellow"
$targetConn = Get-SqlConnection -Server $TargetServer -Database $TargetDatabase -User $TargetUser -Password $TargetPassword
Write-ColorOutput "Connected to target" "Green"

# Copy each table
$totalCopied = 0
$summary = @()

foreach ($tableSpec in $Tables) {
    $parts = $tableSpec -split '\.'
    $schema = $parts[0]
    $table = $parts[1]

    try {
        Copy-TableData -SourceConn $sourceConn -TargetConn $targetConn -Schema $schema -Table $table -Truncate $TruncateTarget

        $sourceCount = Get-RowCount -Connection $sourceConn -Schema $schema -Table $table
        $targetCount = Get-RowCount -Connection $targetConn -Schema $schema -Table $table

        $summary += [PSCustomObject]@{
            Table = "$schema.$table"
            SourceRows = $sourceCount
            TargetRows = $targetCount
            Status = if ($targetCount -eq $sourceCount) { "OK" } else { "MISMATCH" }
        }

        $totalCopied += $targetCount
    }
    catch {
        Write-ColorOutput "  Failed to copy $schema.$table : $_" "Red"
        $summary += [PSCustomObject]@{
            Table = "$schema.$table"
            SourceRows = "N/A"
            TargetRows = "N/A"
            Status = "ERROR"
        }
    }
}

# Close connections
$sourceConn.Close()
$targetConn.Close()

# Summary
Write-ColorOutput "`n==========================================================" "Cyan"
Write-ColorOutput "  Copy Summary" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

$summary | Format-Table -AutoSize | Out-String | Write-Host

Write-ColorOutput "`nTotal rows copied: $totalCopied" "Green"
Write-ColorOutput "==========================================================" "Cyan"
