using ReceiverService;
using Serilog;
using Serilog.Sinks.MSSqlServer;

// Build configuration to read connection string
var configuration = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile("appsettings.Azure.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables()
    .Build();

// Configure Serilog
var connectionString = configuration.GetConnectionString("MqttBridge")
    ?? throw new InvalidOperationException("Connection string 'MqttBridge' not found.");

var columnOptions = new ColumnOptions();
columnOptions.Store.Remove(StandardColumn.Properties);
columnOptions.Store.Add(StandardColumn.LogEvent);
columnOptions.AdditionalColumns = new[]
{
    new SqlColumn { ColumnName = "ServiceName", DataType = System.Data.SqlDbType.NVarChar, DataLength = 100, AllowNull = false }
};

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .Enrich.WithProperty("ServiceName", "ReceiverService")
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File("logs/receiver-.log", rollingInterval: RollingInterval.Day)
    .WriteTo.MSSqlServer(
        connectionString: connectionString,
        sinkOptions: new MSSqlServerSinkOptions
        {
            TableName = "ApplicationLogs",
            SchemaName = "Logging",
            AutoCreateSqlTable = false,
            BatchPostingLimit = 50,
            BatchPeriod = TimeSpan.FromSeconds(5)
        },
        columnOptions: columnOptions)
    .CreateLogger();

try
{
    Log.Information("Starting MQTT Receiver Service");

    var builder = Host.CreateApplicationBuilder(args);

    // Configure builder to load Azure settings
    builder.Configuration.AddJsonFile("appsettings.Azure.json", optional: true, reloadOnChange: true);

    // Add Serilog
    builder.Services.AddSerilog();

    // Add Worker
    builder.Services.AddHostedService<Worker>();

    var host = builder.Build();
    host.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
