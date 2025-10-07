# How to Run Multiple Subscribers (IMPORTANT!)

## The Problem

You **CANNOT** run `dotnet run` multiple times for the same project - it tries to rebuild each time and locks the .exe file.

## The Solution - Build Once, Run Multiple Times

### Step 1: Build the Subscriber ONCE
```bash
cd src\SubscriberService
dotnet build
```

### Step 2: Run Multiple Instances with --no-build

Now you can run as many instances as you want!

**Terminal 1 - Subscriber for Monitor 1:**
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Subscriber1"
dotnet run --no-build
```

**Terminal 2 - Subscriber for Monitor 2:**
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Subscriber2"
dotnet run --no-build
```

**Terminal 3 - Subscriber for ALL Monitors:**
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet run --no-build
```

---

## Alternative: Run the EXE Directly

**Even better** - skip `dotnet run` entirely and run the compiled EXE:

**Terminal 1:**
```powershell
cd src\SubscriberService\bin\Debug\net6.0
$env:ASPNETCORE_ENVIRONMENT="Subscriber1"
.\SubscriberService.exe
```

**Terminal 2:**
```powershell
cd src\SubscriberService\bin\Debug\net6.0
$env:ASPNETCORE_ENVIRONMENT="Subscriber2"
.\SubscriberService.exe
```

---

## Quick Reference

| Command | What It Does | When To Use |
|---------|-------------|-------------|
| `dotnet build` | Compiles the project | **Do this ONCE first** |
| `$env:ASPNETCORE_ENVIRONMENT="Subscriber1"; dotnet run --no-build` | Sets environment and runs without rebuilding | **For multiple instances** |
| `dotnet run` | Builds then runs | **Only for single instance** |
| `$env:ASPNETCORE_ENVIRONMENT="Subscriber1"; .\SubscriberService.exe` | Sets environment and runs directly | **Best for multiple instances** |

---

## Complete Test Setup - 4 Terminals

### Initial Build (ONE TIME):
```bash
cd src\SubscriberService
dotnet build

cd ..\PublisherService
dotnet build
```

### Terminal 1 - Subscriber 1:
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Subscriber1"
dotnet run --no-build
```

### Terminal 2 - Subscriber 2:
```powershell
cd src\SubscriberService
$env:ASPNETCORE_ENVIRONMENT="Subscriber2"
dotnet run --no-build
```

### Terminal 3 - Publisher:
```powershell
cd src\PublisherService
dotnet run --no-build
```

### Terminal 4 - Auto Generator:
```powershell
powershell -ExecutionPolicy Bypass -File auto-send-messages.ps1
```

---

## If You Get "File Locked" Errors

**Stop ALL subscribers:**
```powershell
powershell -ExecutionPolicy Bypass -File stop-services.ps1
```

**Or manually:**
```powershell
Get-Process -Name "SubscriberService" | Stop-Process -Force
```

**Then rebuild:**
```bash
cd src\SubscriberService
dotnet build
```

**Then run again with --no-build flag**

---

## Key Takeaway

✅ **Always use `--no-build` when running multiple instances of the same service!**

This prevents file locking issues and lets you run as many subscribers as you want simultaneously.
