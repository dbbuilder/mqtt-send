using MonitorDashboard.Services;
using MonitorDashboard.Hubs;
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
    .MinimumLevel.Override("Microsoft.AspNetCore", Serilog.Events.LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("ServiceName", "MonitorDashboard")
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
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

var builder = WebApplication.CreateBuilder(args);

// Configure builder to load Azure settings
builder.Configuration.AddJsonFile("appsettings.Azure.json", optional: true, reloadOnChange: true);

// Add Serilog
builder.Host.UseSerilog();

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddControllers(); // Add API controller support
builder.Services.AddSignalR();

// Register monitoring service
builder.Services.AddSingleton<MonitoringService>();

// Register testing service
builder.Services.AddSingleton<TestingService>();

// Register background service for broadcasting updates
builder.Services.AddHostedService<MonitorBroadcastService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

// Map API controllers
app.MapControllers();

// Map SignalR hub
app.MapHub<MonitorHub>("/monitorHub");

app.Run();
