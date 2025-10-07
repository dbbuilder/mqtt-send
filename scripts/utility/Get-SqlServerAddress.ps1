# SQL Server Address Auto-Detection
# Detects the correct SQL Server address (localhost or WSL host IP)

param(
    [switch]$Quiet
)

$ErrorActionPreference = "SilentlyContinue"

# Try localhost first
$localhostTest = & sqlcmd -S localhost,1433 -U sa -P "YourStrong@Passw0rd" -C -Q "SELECT 1" -h -1 2>$null
if ($LASTEXITCODE -eq 0) {
    if (-not $Quiet) {
        Write-Host "SQL Server: localhost,1433" -ForegroundColor Green
    }
    Write-Output "localhost,1433"
    exit 0
}

# Try WSL host IP
$wslHostIp = "172.31.208.1"
$wslTest = & sqlcmd -S "$wslHostIp,1433" -U sa -P "YourStrong@Passw0rd" -Q "SELECT 1" -h -1 2>$null
if ($LASTEXITCODE -eq 0) {
    if (-not $Quiet) {
        Write-Host "SQL Server: $wslHostIp,1433 (WSL host IP)" -ForegroundColor Green
    }
    Write-Output "$wslHostIp,1433"
    exit 0
}

# Try getting WSL host IP from resolv.conf
if (Test-Path "/etc/resolv.conf") {
    $nameserver = Get-Content "/etc/resolv.conf" | Where-Object { $_ -match "^nameserver" } | ForEach-Object { $_ -replace "nameserver\s+", "" } | Select-Object -First 1
    if ($nameserver) {
        $nameserverTest = & sqlcmd -S "$nameserver,1433" -U sa -P "YourStrong@Passw0rd" -Q "SELECT 1" -h -1 2>$null
        if ($LASTEXITCODE -eq 0) {
            if (-not $Quiet) {
                Write-Host "SQL Server: $nameserver,1433 (WSL nameserver)" -ForegroundColor Green
            }
            Write-Output "$nameserver,1433"
            exit 0
        }
    }
}

# Not found
if (-not $Quiet) {
    Write-Host "SQL Server: Not accessible" -ForegroundColor Red
}
Write-Output ""
exit 1
