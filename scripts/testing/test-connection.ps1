# Test SQL Connection from .NET
$ErrorActionPreference = "Stop"

Write-Host "`nTesting SQL Server Connection..." -ForegroundColor Cyan

$connectionString = "Server=localhost,1433;Database=MqttBridge;User Id=sa;Password=YourStrong@Passw0rd;Encrypt=False;TrustServerCertificate=True;MultipleActiveResultSets=True"

try {
    Add-Type -AssemblyName System.Data
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = "SELECT COUNT(*) as MessageCount FROM Messages WHERE Status = 'Pending'"
    $reader = $command.ExecuteReader()

    if ($reader.Read()) {
        $count = $reader["MessageCount"]
        Write-Host " Connection successful!" -ForegroundColor Green
        Write-Host "  Pending messages: $count" -ForegroundColor Gray
    }

    $reader.Close()
    $connection.Close()

    Write-Host "`n Ready to start services!" -ForegroundColor Green
}
catch {
    Write-Host " Connection failed!" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}
