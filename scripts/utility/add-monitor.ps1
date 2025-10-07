# Add New Monitor Configuration
# Interactive script to add a new monitor to monitors.json

param(
    [string]$ConfigPath = "config\monitors.json"
)

Write-Host "`n=== Add New Monitor Configuration ===`n" -ForegroundColor Cyan

# Load existing config
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Creating new config file at $ConfigPath..." -ForegroundColor Yellow
    $config = @{
        monitors = @{}
        generators = @{
            oscillate = @{
                description = "Sine wave oscillation between min and max"
                parameters = @("min", "max", "amplitude", "frequency")
            }
            random = @{
                description = "Random value between min and max"
                parameters = @("min", "max")
            }
            linear = @{
                description = "Linear increment/decrement"
                parameters = @("min", "max", "step")
            }
            static = @{
                description = "Fixed value"
                parameters = @("value")
            }
        }
    }
} else {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}

# Get monitor ID
$monitorId = Read-Host "Enter Monitor ID (e.g., 3, 4, device-abc)"
if ($config.monitors.PSObject.Properties.Name -contains $monitorId) {
    $overwrite = Read-Host "Monitor $monitorId already exists. Overwrite? (y/n)"
    if ($overwrite -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit
    }
}

# Get monitor details
$monitorName = Read-Host "Enter Monitor Name (e.g., Building C - Basement)"
$location = Read-Host "Enter Location (e.g., Building C - Room 101)"

# Get sensors
$sensors = @()
$addMore = $true

while ($addMore) {
    Write-Host "`n--- Adding Sensor ---" -ForegroundColor Yellow

    $sensorType = Read-Host "Sensor Type (e.g., temperature, humidity, pressure)"
    $unit = Read-Host "Unit (e.g., F, %, kPa)"

    Write-Host "`nAvailable Generators:" -ForegroundColor Gray
    Write-Host "  1. oscillate - Sine wave pattern" -ForegroundColor Gray
    Write-Host "  2. random - Random values" -ForegroundColor Gray
    Write-Host "  3. linear - Linear increment" -ForegroundColor Gray
    Write-Host "  4. static - Fixed value" -ForegroundColor Gray

    $generatorChoice = Read-Host "Choose generator (1-4)"

    $generator = switch ($generatorChoice) {
        "1" { "oscillate" }
        "2" { "random" }
        "3" { "linear" }
        "4" { "static" }
        default { "random" }
    }

    $sensor = @{
        type = $sensorType
        unit = $unit
        generator = $generator
    }

    # Get generator-specific parameters
    switch ($generator) {
        "oscillate" {
            $sensor.min = [double](Read-Host "Min value")
            $sensor.max = [double](Read-Host "Max value")
            $sensor.amplitude = [double](Read-Host "Amplitude (default: auto)")
            $sensor.frequency = [double](Read-Host "Frequency (default: 0.5)")
        }
        "random" {
            $sensor.min = [double](Read-Host "Min value")
            $sensor.max = [double](Read-Host "Max value")
        }
        "linear" {
            $sensor.min = [double](Read-Host "Min value")
            $sensor.max = [double](Read-Host "Max value")
            $sensor.step = [double](Read-Host "Step increment")
        }
        "static" {
            $sensor.value = [double](Read-Host "Fixed value")
        }
    }

    $sensors += $sensor

    $continue = Read-Host "`nAdd another sensor for this monitor? (y/n)"
    $addMore = ($continue -eq 'y')
}

# Get custom fields
Write-Host "`n--- Custom Fields (optional) ---" -ForegroundColor Yellow
$customFields = @{
    Status = "Active"
    DataQuality = "Good"
}

$addCustom = Read-Host "Add custom fields? (y/n)"
if ($addCustom -eq 'y') {
    $addMoreFields = $true
    while ($addMoreFields) {
        $fieldName = Read-Host "Field name"
        $fieldValue = Read-Host "Field value"
        $customFields[$fieldName] = $fieldValue

        $continue = Read-Host "Add another field? (y/n)"
        $addMoreFields = ($continue -eq 'y')
    }
}

# Build monitor config
$monitorConfig = @{
    name = $monitorName
    location = $location
    sensors = $sensors
    fields = $customFields
}

# Add to config
if (-not $config.monitors) {
    $config.monitors = @{}
}
$config.monitors | Add-Member -NotePropertyName $monitorId -NotePropertyValue $monitorConfig -Force

# Save config
$config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

Write-Host "`n=== Monitor Added Successfully ===`n" -ForegroundColor Green
Write-Host "Monitor ID: $monitorId" -ForegroundColor Gray
Write-Host "Name: $monitorName" -ForegroundColor Gray
Write-Host "Sensors: $($sensors.Count)" -ForegroundColor Gray
Write-Host "Config saved to: $ConfigPath`n" -ForegroundColor Gray

# Show test command
Write-Host "Test with:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File auto-send-messages-dynamic.ps1`n" -ForegroundColor White
