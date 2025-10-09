using Microsoft.AspNetCore.Mvc;
using MonitorDashboard.Services;

namespace MonitorDashboard.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase
{
    private readonly TestingService _testingService;
    private readonly ILogger<TestController> _logger;

    public TestController(TestingService testingService, ILogger<TestController> logger)
    {
        _testingService = testingService;
        _logger = logger;
    }

    [HttpPost("send-mqtt")]
    public async Task<IActionResult> SendTestMqttMessage([FromBody] SendMqttRequest request)
    {
        var result = await _testingService.SendTestMqttMessageAsync(
            request.Topic,
            request.DeviceId,
            request.SensorType,
            request.Value,
            request.Unit
        );

        return Ok(result);
    }

    [HttpPost("insert-data")]
    public async Task<IActionResult> InsertTestData([FromBody] InsertDataRequest request)
    {
        var result = await _testingService.InsertTestDataAsync(request.TableName, request.MonitorId);
        return Ok(result);
    }

    [HttpPost("clear-data")]
    public async Task<IActionResult> ClearTestData()
    {
        var result = await _testingService.ClearTestDataAsync();
        return Ok(result);
    }

    [HttpGet("latest-data")]
    public async Task<IActionResult> GetLatestData()
    {
        var result = await _testingService.GetLatestReceivedDataAsync();
        return Ok(result);
    }
}

public class SendMqttRequest
{
    public string Topic { get; set; } = string.Empty;
    public string DeviceId { get; set; } = string.Empty;
    public string SensorType { get; set; } = string.Empty;
    public double Value { get; set; }
    public string Unit { get; set; } = string.Empty;
}

public class InsertDataRequest
{
    public string TableName { get; set; } = string.Empty;
    public int MonitorId { get; set; }
}
