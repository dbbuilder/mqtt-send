using Microsoft.EntityFrameworkCore;
using PublisherService;
using PublisherService.Data;
using PublisherService.Services;
using Serilog;
using Serilog.Sinks.MSSqlServer;

// Configure Serilog
var connectionString = "Server=localhost,1433;Database=MqttBridge;User Id=sa;Password=YourStrong@Passw0rd;Encrypt=False;TrustServerCertificate=True;MultipleActiveResultSets=True";

var columnOptions = new ColumnOptions();
columnOptions.Store.Remove(StandardColumn.Properties);
columnOptions.Store.Add(StandardColumn.LogEvent);
columnOptions.AdditionalColumns = new[]
{
    new SqlColumn { ColumnName = "ServiceName", DataType = System.Data.SqlDbType.NVarChar, DataLength = 100, AllowNull = false }
};

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", Serilog.Events.LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("ServiceName", "PublisherService")
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File("logs/publisher-.txt", rollingInterval: RollingInterval.Day)
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
    Log.Information("Starting Publisher Service");

    IHost host = Host.CreateDefaultBuilder(args)
        .UseSerilog()
        .ConfigureServices((hostContext, services) =>
        {
            var configuration = hostContext.Configuration;

            // Register DbContext
            services.AddDbContext<MessageDbContext>(options =>
                options.UseSqlServer(configuration.GetConnectionString("AzureSql")));

            // Register MQTT Publisher as singleton
            services.AddSingleton<MqttPublisherService>();

            // Register Worker
            services.AddHostedService<Worker>();
        })
        .Build();

    await host.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Publisher Service terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
