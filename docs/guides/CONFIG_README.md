# Configuration Management

## 🔐 Secure Configuration Strategy

This project uses environment-specific configuration files that are **gitignored** to protect sensitive credentials.

---

## 📁 Configuration Files

### Checked into Git (Templates)
- ✅ `appsettings.json` - Base template with placeholder values
- ✅ `appsettings.template.json` - Example configuration

### Gitignored (Environment-Specific)
- 🔒 `appsettings.Azure.json` - Azure SQL credentials (ACTIVE)
- 🔒 `appsettings.Development.json` - Local development settings
- 🔒 `appsettings.Production.json` - Production settings
- 🔒 `appsettings.Local.json` - Local overrides

---

## 🚀 Current Configuration

**Active Environment:** Azure SQL

All services are configured to use:
- **Server:** mbox-eastasia.database.windows.net
- **Database:** MqttBridge
- **Authentication:** SQL Authentication (mbox-admin)

### Configuration Files Created:

1. **ReceiverService/appsettings.Azure.json** ✅
2. **MultiTablePublisher/appsettings.Azure.json** ✅
3. **MonitorDashboard/appsettings.Azure.json** ✅

---

## 🔧 How Configuration Merging Works

.NET merges configuration files in this order (later files override earlier):

1. `appsettings.json` (base template)
2. `appsettings.Azure.json` (environment-specific)
3. Environment variables (highest priority)

**Example:**
```json
// appsettings.json (template - checked into git)
{
  "ConnectionStrings": {
    "MqttBridge": "Server=YOUR_SERVER;Database=MqttBridge;..."
  }
}

// appsettings.Azure.json (actual credentials - gitignored)
{
  "ConnectionStrings": {
    "MqttBridge": "Server=mbox-eastasia.database.windows.net,1433;Database=MqttBridge;User Id=mbox-admin;Password=eTqEnC4KjnYbmDuraukP;..."
  }
}
```

**Result:** Application uses Azure SQL connection string ✅

---

## 🛠️ Setup for New Developers

### 1. Clone the repository
```bash
git clone <repo>
cd mqtt-send
```

### 2. Create your environment-specific config
```bash
# Copy the Azure template (or create your own)
cp src/ReceiverService/appsettings.Azure.json.example src/ReceiverService/appsettings.Azure.json

# Edit with your credentials
notepad src/ReceiverService/appsettings.Azure.json
```

### 3. Update all services
- ReceiverService/appsettings.Azure.json
- MultiTablePublisher/appsettings.Azure.json
- MonitorDashboard/appsettings.Azure.json

### 4. Run the system
```powershell
.\Start-System-Safe.ps1
```

---

## 🔒 .gitignore Protection

The following patterns are gitignored to protect credentials:

```gitignore
# Environment-specific configs
appsettings.Development.json
appsettings.Production.json
appsettings.Azure.json
appsettings.Local.json

# Secrets
*.pfx
*.key
secrets.json
```

---

## 📋 Configuration Checklist

Before deploying to a new environment:

- [ ] Create environment-specific `appsettings.<ENV>.json`
- [ ] Update connection strings with correct credentials
- [ ] Verify MQTT broker address and port
- [ ] Test database connectivity
- [ ] Ensure file is **NOT** committed to git
- [ ] Document connection details in secure password manager

---

## 🌍 Environment Variables (Optional)

You can also override settings using environment variables:

```bash
# Windows
set ConnectionStrings__MqttBridge=Server=...

# PowerShell
$env:ConnectionStrings__MqttBridge="Server=..."

# Linux/Mac
export ConnectionStrings__MqttBridge="Server=..."
```

**Note:** Use double underscores `__` to represent nested JSON structure.

---

## 🧪 Testing Configuration

### Test Azure SQL Connection:
```bash
sqlcmd -S mbox-eastasia.database.windows.net,1433 -U mbox-admin -P "YOUR_PASSWORD" -d MqttBridge -Q "SELECT @@VERSION;" -C
```

### Verify Configuration Loading:
Check service logs on startup - should show:
```
[INFO] Connecting to database: mbox-eastasia.database.windows.net
[INFO] Database: MqttBridge
```

---

## 🔄 Switching Environments

### To use Azure SQL (Current):
- Ensure `appsettings.Azure.json` exists
- Stop local Docker SQL Server: `docker stop sqlserver`
- Restart services: `.\Start-System-Safe.ps1`

### To use Local Docker SQL:
- Start Docker SQL Server: `docker start sqlserver`
- Rename/delete `appsettings.Azure.json`
- Create `appsettings.Local.json` with local connection string
- Restart services

---

## 📝 Security Best Practices

✅ **DO:**
- Use environment-specific config files (gitignored)
- Store credentials in Azure Key Vault (production)
- Use Managed Identities where possible
- Rotate passwords regularly
- Use strong passwords (20+ characters)

❌ **DON'T:**
- Commit credentials to git
- Share credentials via email/chat
- Use default passwords
- Store passwords in code
- Use the same password across environments

---

## 🆘 Troubleshooting

### "Connection string not found"
- Verify `appsettings.Azure.json` exists in service directory
- Check file is valid JSON (no syntax errors)
- Ensure file is copied to output directory on build

### "Cannot connect to database"
- Test connection with sqlcmd first
- Check firewall rules (Azure SQL needs your IP whitelisted)
- Verify credentials are correct
- Ensure TrustServerCertificate=True for Azure SQL

### "Configuration not loading"
- Check file naming (case-sensitive on Linux)
- Verify file is in service output directory
- Check .csproj includes `<CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>`

---

**Current Status:**
- ✅ Local Docker SQL Server: STOPPED
- ✅ Azure SQL Database: ACTIVE (MqttBridge)
- ✅ Configuration: appsettings.Azure.json
- ✅ Credentials: Protected via .gitignore
