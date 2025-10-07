# Add New Source Table Configuration
# Interactive script to add a new table as MQTT message source

param(
    [string]$ConfigPath = "config\source-tables.json"
)

Write-Host "`n=== Add New Source Table ===`n" -ForegroundColor Cyan

# Load existing config
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Error: Config file not found at $ConfigPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Get table details
$tableName = Read-Host "Table name (e.g., SensorReadings, AlarmEvents)"
$schema = Read-Host "Schema (default: dbo)"
if ([string]::IsNullOrWhiteSpace($schema)) { $schema = "dbo" }

$description = Read-Host "Description"

# Get tracking method
Write-Host "`nTracking Methods:" -ForegroundColor Yellow
Write-Host "  1. status_column - Use Status column (like Messages table)" -ForegroundColor Gray
Write-Host "  2. sent_flag - Use IsSent/SentAt columns" -ForegroundColor Gray
Write-Host "  3. tracking_table - Use separate tracking table (no table modifications)" -ForegroundColor Gray

$trackingChoice = Read-Host "Choose tracking method (1-3)"

$tracking = @{}

switch ($trackingChoice) {
    "1" {
        $tracking.method = "status_column"
        $tracking.statusColumn = Read-Host "Status column name (default: Status)"
        if ([string]::IsNullOrWhiteSpace($tracking.statusColumn)) { $tracking.statusColumn = "Status" }
        $tracking.sentValue = Read-Host "Value for 'sent' status (default: Sent)"
        if ([string]::IsNullOrWhiteSpace($tracking.sentValue)) { $tracking.sentValue = "Sent" }
        $tracking.pendingValue = Read-Host "Value for 'pending' status (default: Pending)"
        if ([string]::IsNullOrWhiteSpace($tracking.pendingValue)) { $tracking.pendingValue = "Pending" }
        $tracking.errorColumn = Read-Host "Error message column (optional)"
        $tracking.retryColumn = Read-Host "Retry count column (optional)"
    }
    "2" {
        $tracking.method = "sent_flag"
        $tracking.sentColumn = Read-Host "Sent flag column (default: IsSent)"
        if ([string]::IsNullOrWhiteSpace($tracking.sentColumn)) { $tracking.sentColumn = "IsSent" }
        $tracking.sentAtColumn = Read-Host "Sent timestamp column (default: SentAt)"
        if ([string]::IsNullOrWhiteSpace($tracking.sentAtColumn)) { $tracking.sentAtColumn = "SentAt" }
    }
    "3" {
        $tracking.method = "tracking_table"
        $tracking.trackingTable = "MqttSentRecords"
        $tracking.sourceTableColumn = "SourceTable"
        $tracking.recordIdColumn = "RecordId"
        Write-Host "Using tracking table: MqttSentRecords" -ForegroundColor Gray
    }
}

# Query configuration
Write-Host "`n--- Query Configuration ---" -ForegroundColor Yellow
$primaryKey = Read-Host "Primary key column"
$monitorIdColumn = Read-Host "Monitor/Device ID column"
$whereClause = Read-Host "WHERE clause (e.g., Status = 'Ready')"
$orderBy = Read-Host "ORDER BY clause (default: $primaryKey ASC)"
if ([string]::IsNullOrWhiteSpace($orderBy)) { $orderBy = "$primaryKey ASC" }
$batchSize = Read-Host "Batch size (default: 100)"
if ([string]::IsNullOrWhiteSpace($batchSize)) { $batchSize = 100 } else { $batchSize = [int]$batchSize }

$query = @{
    primaryKey = $primaryKey
    monitorIdColumn = $monitorIdColumn
    whereClause = $whereClause
    orderBy = $orderBy
    batchSize = $batchSize
}

# MQTT configuration
Write-Host "`n--- MQTT Configuration ---" -ForegroundColor Yellow
$topicPattern = Read-Host "Topic pattern (use {ColumnName} for substitution, e.g., data/{$monitorIdColumn}/readings)"
$qos = Read-Host "QoS level (0, 1, or 2, default: 1)"
if ([string]::IsNullOrWhiteSpace($qos)) { $qos = 1 } else { $qos = [int]$qos }
$retain = Read-Host "Retain messages? (y/n, default: n)"
$retain = ($retain -eq 'y')

$usePayloadColumn = Read-Host "Use specific column for pre-formatted JSON payload? (y/n)"
$payloadSource = $null
if ($usePayloadColumn -eq 'y') {
    $payloadSource = Read-Host "Payload column name"
}

$mqtt = @{
    topicPattern = $topicPattern
    qos = $qos
    retain = $retain
}
if ($payloadSource) {
    $mqtt.payloadSource = $payloadSource
}

# Field mapping
Write-Host "`n--- Field Mapping ---" -ForegroundColor Yellow
Write-Host "Map table columns to MQTT message fields" -ForegroundColor Gray

$fieldMapping = @{}
$addMore = $true

while ($addMore) {
    $tableColumn = Read-Host "Table column name"
    $mqttField = Read-Host "MQTT field name"
    $fieldMapping[$tableColumn] = $mqttField

    $continue = Read-Host "Add another mapping? (y/n)"
    $addMore = ($continue -eq 'y')
}

# Build source config
$sourceConfig = @{
    name = $tableName
    enabled = $true
    tableName = $tableName
    schema = $schema
    description = $description
    tracking = $tracking
    query = $query
    mqtt = $mqtt
    fieldMapping = $fieldMapping
}

# Add to config
$config.sources += $sourceConfig

# Save config
$config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

Write-Host "`n=== Source Table Added Successfully ===`n" -ForegroundColor Green
Write-Host "Table: $schema.$tableName" -ForegroundColor Gray
Write-Host "Tracking: $($tracking.method)" -ForegroundColor Gray
Write-Host "Topic: $topicPattern" -ForegroundColor Gray
Write-Host "Field mappings: $($fieldMapping.Count)" -ForegroundColor Gray
Write-Host "`nConfig saved to: $ConfigPath`n" -ForegroundColor Gray

# Show next steps
Write-Host "Next Steps:" -ForegroundColor Cyan
if ($tracking.method -eq "sent_flag") {
    Write-Host "  1. Add columns to table:" -ForegroundColor Yellow
    Write-Host "     ALTER TABLE $schema.$tableName ADD $($tracking.sentColumn) BIT DEFAULT 0;" -ForegroundColor White
    Write-Host "     ALTER TABLE $schema.$tableName ADD $($tracking.sentAtColumn) DATETIME2;" -ForegroundColor White
}
if ($tracking.method -eq "tracking_table") {
    Write-Host "  1. Tracking table will be auto-created on first run" -ForegroundColor Yellow
}
Write-Host "  2. Update Publisher Service to use multi-table config" -ForegroundColor Yellow
Write-Host "  3. Restart Publisher Service`n" -ForegroundColor Yellow
