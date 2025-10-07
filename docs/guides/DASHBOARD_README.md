# MQTT Bridge Monitor Dashboard

A real-time web-based monitoring dashboard for the MQTT Bridge system, providing visual insights into both Receiver and Publisher services.

## Features

### Real-Time Monitoring
- **System Status** - Live status of Receiver, Publisher, and Database
- **Message Flow** - Real-time visualization of MQTT message processing
- **Statistics** - Today's metrics with success rates and error tracking
- **Active Subscriptions** - All configured MQTT topic subscriptions
- **Table Monitors** - Database tables being monitored for changes
- **Recent Activity** - Latest messages received and published

### Technology
- **ASP.NET Core 9.0** - Modern web framework
- **SignalR** - Real-time bidirectional communication
- **Bootstrap 5** - Responsive UI framework
- **Auto-Refresh** - Updates every 5 seconds automatically

## Quick Start

### Using the Orchestrator (Recommended)
```powershell
# Start the dashboard
.\demo.ps1 -Action start-dashboard
```

The dashboard will:
1. Build the project (if needed)
2. Start on http://localhost:5000
3. Automatically open in your browser

### Manual Start
```powershell
cd src/MonitorDashboard
dotnet run --urls http://localhost:5000
```

### Access
Open your browser to: **http://localhost:5000**

## Dashboard Sections

### 1. System Overview (Top)
**Status Cards:**
- **MQTT Receiver** - Connection status and active subscriptions
- **MQTT Publisher** - Connection status and monitored tables
- **System Statistics** - Total active topics and monitored tables

### 2. Receiver Status (Left Column)
**Real-time metrics:**
- Messages received today
- Success/failure counts
- Success rate percentage

**Active Subscriptions:**
- Topic patterns (with wildcards)
- Number of target tables per subscription
- Enabled/disabled status

**Recent Messages:**
- Last 10 received messages
- Topic names
- Processing status
- Number of tables affected
- Error messages (if any)

### 3. Publisher Status (Right Column)
**Real-time metrics:**
- Publications sent today
- Success/failure counts
- Success rate percentage

**Table Monitors:**
- Monitored table names
- MQTT topics
- Polling intervals
- Enabled/disabled status

**Recent Publications:**
- Last 10 published messages
- Source table name
- MQTT topic
- Success/failure status
- Error messages (if any)

### 4. Live Message Flow (Bottom)
Unified view of all message activity:
- **RECEIVED** messages (blue badge) - MQTT → Database
- **PUBLISHED** messages (red badge) - Database → MQTT
- Timestamps and success/error indicators
- Last 20 events displayed

## How It Works

### SignalR Real-Time Updates
The dashboard uses SignalR for real-time communication:

1. **MonitorHub** - SignalR hub for client connections
2. **MonitorBroadcastService** - Background service that broadcasts updates every 5 seconds
3. **JavaScript Client** - Receives updates and refreshes UI

### Data Sources
All data comes from the MqttBridge database:

**Receiver Data:**
- `MQTT.ReceiverConfig` - Topic subscriptions
- `MQTT.TopicTableMapping` - One-to-many routing rules
- `MQTT.ReceivedMessages` - Message processing log

**Publisher Data:**
- `MQTT.PublisherConfig` - Table monitoring configuration
- `MQTT.PublishedMessages` - Publication log

**Statistics:**
- Real-time queries aggregating today's data
- Success rate calculations
- Recent activity (last 5 minutes) for connection detection

### Auto-Reconnect
The dashboard automatically reconnects if:
- Network connection is lost
- Services are restarted
- Browser tab is refreshed

## Configuration

### Connection String
Located in `appsettings.json`:
```json
{
  "ConnectionStrings": {
    "MqttBridge": "Server=localhost,1433;Database=MqttBridge;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;Encrypt=False;"
  }
}
```

### Port Configuration
Default port: **5000**

To change:
```powershell
# Using orchestrator
.\demo.ps1 -Action start-dashboard

# Manually
dotnet run --urls http://localhost:YOUR_PORT
```

## Use Cases

### 1. Demo Presentations
- Show live MQTT message processing
- Demonstrate one-to-many routing
- Visualize bidirectional data flow
- Prove system is working in real-time

### 2. Development & Testing
- Monitor message flow during development
- Debug routing issues
- Verify configuration changes
- Track error rates

### 3. Production Monitoring
- System health at a glance
- Real-time error detection
- Performance metrics
- Activity logging

## Integration with Demo Orchestrator

The dashboard integrates seamlessly with the orchestrator:

```powershell
# Start receiver and dashboard together
.\demo.ps1 -Action start-receiver
.\demo.ps1 -Action start-dashboard

# Run full demo (includes dashboard)
.\demo.ps1 -Action full-demo

# Stop everything (includes dashboard)
.\demo.ps1 -Action stop-all

# Check status (includes dashboard)
.\demo.ps1
```

## Troubleshooting

### Dashboard Won't Start
```powershell
# Stop all services and rebuild
.\demo.ps1 -Action stop-all
dotnet build src/MonitorDashboard/MonitorDashboard.csproj --configuration Release
.\demo.ps1 -Action start-dashboard
```

### No Data Showing
**Check:**
1. Database connection (verify connection string)
2. Receiver/Publisher services running
3. Test data exists: `.\demo.ps1 -Action send-test`

### SignalR Connection Failed
**Reasons:**
- Firewall blocking localhost:5000
- Another service using port 5000
- Browser security settings

**Fix:**
- Use a different port
- Check browser console for errors
- Restart the dashboard

### Slow Updates
**Normal behavior:** Dashboard updates every 5 seconds

**To change update frequency:**
Edit `MonitorBroadcastService.cs`:
```csharp
await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); // Change here
```

## Architecture

### Components

**Backend:**
- `Program.cs` - ASP.NET Core configuration
- `Hubs/MonitorHub.cs` - SignalR hub and broadcast service
- `Services/MonitoringService.cs` - Database query service
- `Models/MonitoringModels.cs` - Data models

**Frontend:**
- `Pages/Index.cshtml` - Main dashboard page
- SignalR JavaScript client
- Bootstrap 5 CSS
- Custom CSS for real-time visualizations

### Data Flow
```
Database → MonitoringService → MonitorBroadcastService → SignalR Hub → JavaScript Client → UI Update
```

### Update Cycle
1. **Every 5 seconds**, MonitorBroadcastService:
   - Queries database via MonitoringService
   - Broadcasts updates to all connected clients via MonitorHub

2. **JavaScript client receives updates:**
   - Updates system status cards
   - Refreshes statistics
   - Redraws message lists
   - Updates flow events

3. **UI updates immediately** (no page refresh needed)

## Performance

- **Database queries:** Optimized with TOP clauses and date filters
- **Network traffic:** Minimal (JSON payloads every 5 seconds)
- **Browser impact:** Low CPU usage, updates DOM efficiently
- **Concurrent users:** Supports multiple browsers simultaneously

## Security Considerations

⚠️ **Production Deployment:**
- Add authentication (ASP.NET Core Identity)
- Enable HTTPS
- Secure connection strings (Azure Key Vault)
- Implement role-based access control
- Add rate limiting

## Future Enhancements

Potential additions:
- Historical charts and graphs
- Alert notifications
- Export to CSV/Excel
- Configuration management UI
- Custom dashboards per user
- Dark mode toggle

## Dependencies

Required NuGet packages:
- `Microsoft.Data.SqlClient` (5.2.2) - Database connectivity

Included in ASP.NET Core 9.0:
- SignalR
- Razor Pages
- Logging

---

**Built for the MQTT Bridge System**
Part of the complete bidirectional MQTT ↔ SQL Server integration suite.
