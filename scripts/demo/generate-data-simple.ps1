# Simple Continuous Data Generator
param(
    [int]$Count = 5,
    [int]$IntervalSeconds = 10
)

Write-Host "`nStarting Continuous Data Generator..." -ForegroundColor Cyan
Write-Host "Generates $Count records per table every $IntervalSeconds seconds" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray

$iteration = 1

while ($true) {
    Write-Host "`n[Iteration $iteration - $(Get-Date -Format 'HH:mm:ss')]" -ForegroundColor Cyan

    & ".\insert-test-records.ps1" -Count $Count -Table "all"

    $iteration++
    Start-Sleep -Seconds $IntervalSeconds
}
