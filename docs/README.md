# Documentation Index

## 📚 Documentation Structure

### 🚀 Guides (Start Here)
Located in `docs/guides/`

| Document | Purpose |
|----------|---------|
| **QUICK_START_DEMO.md** | 3-minute quick start walkthrough - **START HERE** |
| **QUICK_START.md** | Alternative quick start guide |
| **START_HERE.md** | Project orientation |
| **MULTI_WINDOW_DEMO.md** | Multi-window demonstration setup |
| **DEMO.md** | Complete demo guide |
| **DEMO_RESULTS.md** | Expected demo results and verification |
| **RECEIVER_README.md** | ReceiverService deep dive |
| **ORCHESTRATOR_README.md** | Demo orchestrator (demo.ps1) usage |
| **DASHBOARD_README.md** | MonitorDashboard setup and features |
| **FULL_SYSTEM_GUIDE.md** | Complete end-to-end system guide |

### 🏗️ Architecture
Located in `docs/architecture/`

| Document | Purpose |
|----------|---------|
| **PROJECT_SUMMARY.md** | Complete technical overview |
| **DATABASE_DRIVEN_MQTT_SYSTEM.md** | Database-driven configuration architecture |
| **HIGH_SCALE_ARCHITECTURE.md** | Scaling and performance considerations |
| **SYSTEM_COMPLETE.md** | System completion documentation |

### 🚢 Deployment
Located in `docs/deployment/`

| Document | Purpose |
|----------|---------|
| **AZURE_DEPLOYMENT.md** | Complete Azure deployment guide |
| **AZURE_SIMPLE_DEPLOY.md** | Simplified Azure deployment |
| **DEPLOYMENT_QUICKSTART.md** | Quick deployment reference |

### 🧪 Testing
Located in `docs/testing/`

| Document | Purpose |
|----------|---------|
| **TESTING_GUIDE.md** | Comprehensive testing guide |
| **TESTING_GUIDE_NEW.md** | Updated testing procedures |
| **TEST_SUITE_SUMMARY.md** | Test suite overview |
| **FILTERED_TEST_GUIDE.md** | Conditional filtering tests |
| **AUTO_SEND_GUIDE.md** | Automated message sending |
| **MULTI_TABLE_TESTING_GUIDE.md** | One-to-many routing tests |
| **IMPORTANT_RUN_MULTIPLE_SUBSCRIBERS.md** | Multiple subscriber testing |

### 📖 Reference
Located in `docs/reference/`

| Document | Purpose |
|----------|---------|
| **ADDING_NEW_TABLES.md** | How to add new destination tables |
| **DYNAMIC_MESSAGE_GENERATION.md** | Message generation patterns |

## 📂 Scripts Organization

### Setup Scripts (`scripts/setup/`)
- `init-database.ps1` - Initialize database schema
- `init-receiver-demo.ps1` - Setup receiver demo configuration
- `setup-*.ps1` - Various system setup scripts

### Demo Scripts (`scripts/demo/`)
- `demo.ps1` - **Main demo orchestrator** ⭐
- `auto-send-messages.ps1` - Automated message sending
- `generate-*.ps1` - Data generation utilities

### Service Management (`scripts/services/`)
- `run-receiver.ps1` - Start ReceiverService
- `run-publisher.ps1` - Start Publisher
- `Start-FullSystem.ps1` - Start all services
- `stop-services.ps1` - Stop all services

### Testing Scripts (`scripts/testing/`)
- `test-send-mqtt-message.ps1` - Send test messages
- `test-complete-system.ps1` - End-to-end testing
- `run-complete-test.ps1` - Full test suite

### Utility Scripts (`scripts/utility/`)
- `add-*.ps1` - Add configurations
- `verify-*.ps1` - Verification utilities
- `reset-*.ps1` - Reset/cleanup utilities

### Deployment Scripts (`scripts/deployment/`)
- `Deploy-ToAzure.ps1` - Azure deployment automation

## 🎯 Quick Navigation

### I want to...

**...run a demo**
1. Read: `docs/guides/QUICK_START_DEMO.md`
2. Run: `scripts/demo/demo.ps1 -Action full-demo`

**...understand the architecture**
1. Read: `docs/architecture/PROJECT_SUMMARY.md`
2. Read: `docs/architecture/DATABASE_DRIVEN_MQTT_SYSTEM.md`

**...deploy to Azure**
1. Read: `docs/deployment/AZURE_DEPLOYMENT.md`
2. Run: `scripts/deployment/Deploy-ToAzure.ps1`

**...add a new table**
1. Read: `docs/reference/ADDING_NEW_TABLES.md`
2. Execute SQL to add configuration
3. Wait 30 seconds for auto-reload

**...run tests**
1. Read: `docs/testing/TESTING_GUIDE.md`
2. Run: `scripts/testing/test-complete-system.ps1`

## 📝 Root-Level Files

Files that remain in the project root:
- **README.md** - Main project overview
- **CLAUDE.md** - Claude Code guidance
- **REQUIREMENTS.md** - Original requirements
- **TODO.md** - Implementation checklist
