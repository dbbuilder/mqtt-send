using Microsoft.AspNetCore.SignalR;
using MonitorDashboard.Models;
using MonitorDashboard.Services;

namespace MonitorDashboard.Hubs;

public class MonitorHub : Hub
{
    private readonly MonitoringService _monitoringService;
    private readonly ILogger<MonitorHub> _logger;

    public MonitorHub(MonitoringService monitoringService, ILogger<MonitorHub> logger)
    {
        _monitoringService = monitoringService;
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);

        // Send initial data when client connects
        await SendSystemStatus();
        await SendReceiverStatus();
        await SendPublisherStatus();

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("Client disconnected: {ConnectionId}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    public async Task RequestSystemStatus()
    {
        await SendSystemStatus();
    }

    public async Task RequestReceiverStatus()
    {
        await SendReceiverStatus();
    }

    public async Task RequestPublisherStatus()
    {
        await SendPublisherStatus();
    }

    public async Task RequestFlowEvents()
    {
        var events = await _monitoringService.GetRecentFlowEventsAsync(20);
        await Clients.Caller.SendAsync("ReceiveFlowEvents", events);
    }

    private async Task SendSystemStatus()
    {
        try
        {
            var status = await _monitoringService.GetSystemStatusAsync();
            await Clients.Caller.SendAsync("ReceiveSystemStatus", status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending system status");
        }
    }

    private async Task SendReceiverStatus()
    {
        try
        {
            var status = await _monitoringService.GetReceiverStatusAsync();
            await Clients.Caller.SendAsync("ReceiveReceiverStatus", status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending receiver status");
        }
    }

    private async Task SendPublisherStatus()
    {
        try
        {
            var status = await _monitoringService.GetPublisherStatusAsync();
            await Clients.Caller.SendAsync("ReceivePublisherStatus", status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending publisher status");
        }
    }
}

public class MonitorBroadcastService : BackgroundService
{
    private readonly IHubContext<MonitorHub> _hubContext;
    private readonly MonitoringService _monitoringService;
    private readonly ILogger<MonitorBroadcastService> _logger;

    public MonitorBroadcastService(
        IHubContext<MonitorHub> hubContext,
        MonitoringService monitoringService,
        ILogger<MonitorBroadcastService> logger)
    {
        _hubContext = hubContext;
        _monitoringService = monitoringService;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Monitor broadcast service started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Broadcast updated status to all connected clients every 5 seconds
                var systemStatus = await _monitoringService.GetSystemStatusAsync();
                await _hubContext.Clients.All.SendAsync("ReceiveSystemStatus", systemStatus, stoppingToken);

                var receiverStatus = await _monitoringService.GetReceiverStatusAsync();
                await _hubContext.Clients.All.SendAsync("ReceiveReceiverStatus", receiverStatus, stoppingToken);

                var publisherStatus = await _monitoringService.GetPublisherStatusAsync();
                await _hubContext.Clients.All.SendAsync("ReceivePublisherStatus", publisherStatus, stoppingToken);

                var flowEvents = await _monitoringService.GetRecentFlowEventsAsync(20);
                await _hubContext.Clients.All.SendAsync("ReceiveFlowEvents", flowEvents, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error broadcasting monitor updates");
            }

            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }

        _logger.LogInformation("Monitor broadcast service stopped");
    }
}
