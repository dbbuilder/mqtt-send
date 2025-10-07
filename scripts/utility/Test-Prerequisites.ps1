# Prerequisites Checker for MQTT Bridge System
# Verifies all required dependencies before running demos

param(
    [switch]$Quiet  # If set, returns $true/$false without prompts
)

$ErrorActionPreference = "SilentlyContinue"

# Color functions
function Write-Check {
    param([string]$Text, [bool]$Passed)
    if ($Passed) {
        Write-Host "  [✓] $Text" -ForegroundColor Green
    } else {
        Write-Host "  [✗] $Text" -ForegroundColor Red
    }
}

function Write-Warning-Custom {
    param([string]$Text)
    Write-Host "  [!] $Text" -ForegroundColor Yellow
}

function Write-Info-Custom {
    param([string]$Text)
    Write-Host "  [i] $Text" -ForegroundColor Cyan
}

# Results tracking
$allPassed = $true
$criticalFailed = $false

if (-not $Quiet) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Prerequisites Check" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# 1. Check .NET SDK
if (-not $Quiet) { Write-Host "Checking .NET SDK..." -ForegroundColor Yellow }
$dotnetVersion = & dotnet --version 2>$null
if ($dotnetVersion) {
    $versionNumber = [version]($dotnetVersion -replace '-.*$')
    $dotnetOk = $versionNumber.Major -ge 6
    if (-not $Quiet) {
        Write-Check ".NET SDK installed (Version: $dotnetVersion)" $dotnetOk
    }
    if (-not $dotnetOk) {
        $allPassed = $false
        $criticalFailed = $true
        if (-not $Quiet) {
            Write-Info-Custom "Required: .NET 6.0 or higher (9.0 recommended)"
            Write-Info-Custom "Download from: https://dotnet.microsoft.com/download"
        }
    }
} else {
    $allPassed = $false
    $criticalFailed = $true
    if (-not $Quiet) {
        Write-Check ".NET SDK installed" $false
        Write-Info-Custom "Download from: https://dotnet.microsoft.com/download"
    }
}

# 2. Check Docker Desktop
if (-not $Quiet) { Write-Host "" ; Write-Host "Checking Docker..." -ForegroundColor Yellow }
$dockerRunning = & docker ps 2>$null
if ($LASTEXITCODE -eq 0) {
    if (-not $Quiet) {
        Write-Check "Docker Desktop is running" $true
    }

    # Check if mosquitto container exists
    $mosquittoExists = & docker ps -a --filter "name=mosquitto" --format "{{.Names}}" 2>$null
    if ($mosquittoExists -eq "mosquitto") {
        # Check if it's running
        $mosquittoRunning = & docker ps --filter "name=mosquitto" --format "{{.Names}}" 2>$null
        if ($mosquittoRunning -eq "mosquitto") {
            if (-not $Quiet) {
                Write-Check "Mosquitto MQTT broker is running" $true
            }
        } else {
            $allPassed = $false
            if (-not $Quiet) {
                Write-Check "Mosquitto MQTT broker is running" $false
                Write-Info-Custom "Container exists but not running. Start with: docker start mosquitto"
            }
        }
    } else {
        $allPassed = $false
        if (-not $Quiet) {
            Write-Check "Mosquitto MQTT broker exists" $false
            Write-Info-Custom "Create with: docker run -d --name mosquitto -p 1883:1883 eclipse-mosquitto"
        }
    }
} else {
    $allPassed = $false
    $criticalFailed = $true
    if (-not $Quiet) {
        Write-Check "Docker Desktop is running" $false
        Write-Info-Custom "Start Docker Desktop and try again"
    }
}

# 3. Check SQL Server
if (-not $Quiet) { Write-Host "" ; Write-Host "Checking SQL Server..." -ForegroundColor Yellow }

$sqlServerAddress = & "$PSScriptRoot\Get-SqlServerAddress.ps1" -Quiet
if (-not [string]::IsNullOrEmpty($sqlServerAddress)) {
    if (-not $Quiet) {
        if ($sqlServerAddress -match "172\.31\.208\.1" -or $sqlServerAddress -notmatch "localhost") {
            Write-Check "SQL Server accessible ($sqlServerAddress)" $true
            Write-Warning-Custom "Using WSL host IP - this is normal for WSL environments"
        } else {
            Write-Check "SQL Server accessible ($sqlServerAddress)" $true
        }
    }
} else {
    $allPassed = $false
    $criticalFailed = $true
    if (-not $Quiet) {
        Write-Check "SQL Server accessible" $false
        Write-Info-Custom "Ensure SQL Server is running and accessible"
        Write-Info-Custom "Tried: localhost:1433 and 172.31.208.1:1433"
        Write-Info-Custom "Check SQL Server service is running"
    }
}

# 4. Check sqlcmd utility
if (-not $Quiet) { Write-Host "" ; Write-Host "Checking Tools..." -ForegroundColor Yellow }
$sqlcmdVersion = & sqlcmd -? 2>$null
if ($sqlcmdVersion) {
    if (-not $Quiet) {
        Write-Check "sqlcmd utility installed" $true
    }
} else {
    $allPassed = $false
    if (-not $Quiet) {
        Write-Check "sqlcmd utility installed" $false
        Write-Info-Custom "Install SQL Server Command Line Utilities"
    }
}

# 5. Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
$psOk = $psVersion.Major -ge 5
if (-not $Quiet) {
    Write-Check "PowerShell version $($psVersion.Major).$($psVersion.Minor)" $psOk
}
if (-not $psOk) {
    $allPassed = $false
    if (-not $Quiet) {
        Write-Info-Custom "PowerShell 5.1 or higher recommended"
    }
}

# 6. Check if database exists
if (-not [string]::IsNullOrEmpty($sqlServerAddress)) {
    if (-not $Quiet) { Write-Host "" ; Write-Host "Checking Database..." -ForegroundColor Yellow }

    $certFlag = if ($sqlServerAddress -match "localhost") { "-C" } else { "" }

    $dbExists = & sqlcmd -S $sqlServerAddress -U sa -P "YourStrong@Passw0rd" $certFlag -Q "SELECT DB_ID('MqttBridge')" -h -1 2>$null
    if ($dbExists -and $dbExists.Trim() -ne "NULL") {
        if (-not $Quiet) {
            Write-Check "MqttBridge database exists" $true
        }
    } else {
        $allPassed = $false
        if (-not $Quiet) {
            Write-Check "MqttBridge database exists" $false
            Write-Info-Custom "Initialize database with: scripts\demo\demo.ps1 -Action init-db"
        }
    }
}

# Summary
if (-not $Quiet) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    if ($allPassed) {
        Write-Host " ✓ All Prerequisites Met" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You're ready to run the demo!" -ForegroundColor Green
    } elseif ($criticalFailed) {
        Write-Host " ✗ Critical Prerequisites Missing" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please resolve the issues above before continuing." -ForegroundColor Red
    } else {
        Write-Host " ! Some Prerequisites Missing" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You may continue, but some features may not work." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Return result
if ($Quiet) {
    return $allPassed
} else {
    exit $(if ($allPassed) { 0 } else { 1 })
}
