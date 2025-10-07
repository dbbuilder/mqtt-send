# Folder Structure Guide

## 📁 Organized Directory Structure

```
mqtt-send/
│
├── 📄 Core Files (Root Level)
│   ├── README.md                    ← Main entry point
│   ├── CLAUDE.md                    ← Claude Code guidance
│   ├── STREAMLINED_WORKFLOWS.md     ← Quick reference for 3 main workflows ⭐
│   ├── REQUIREMENTS.md              ← Original requirements
│   └── TODO.md                      ← Implementation checklist
│
├── 📚 docs/ (Documentation)
│   ├── README.md                    ← Documentation index
│   │
│   ├── guides/                      ← User guides & walkthroughs
│   │   ├── QUICK_START_DEMO.md     ← START HERE for first demo
│   │   ├── QUICK_START.md
│   │   ├── START_HERE.md
│   │   ├── MULTI_WINDOW_DEMO.md
│   │   ├── DEMO.md
│   │   ├── DEMO_RESULTS.md
│   │   ├── RECEIVER_README.md
│   │   ├── ORCHESTRATOR_README.md
│   │   ├── DASHBOARD_README.md
│   │   └── FULL_SYSTEM_GUIDE.md
│   │
│   ├── architecture/                ← System design & architecture
│   │   ├── PROJECT_SUMMARY.md
│   │   ├── DATABASE_DRIVEN_MQTT_SYSTEM.md
│   │   ├── HIGH_SCALE_ARCHITECTURE.md
│   │   └── SYSTEM_COMPLETE.md
│   │
│   ├── deployment/                  ← Azure & production deployment
│   │   ├── AZURE_DEPLOYMENT.md
│   │   ├── AZURE_SIMPLE_DEPLOY.md
│   │   └── DEPLOYMENT_QUICKSTART.md
│   │
│   ├── testing/                     ← Testing documentation
│   │   ├── TESTING_GUIDE.md
│   │   ├── TESTING_GUIDE_NEW.md
│   │   ├── TEST_SUITE_SUMMARY.md
│   │   ├── FILTERED_TEST_GUIDE.md
│   │   ├── AUTO_SEND_GUIDE.md
│   │   ├── MULTI_TABLE_TESTING_GUIDE.md
│   │   └── IMPORTANT_RUN_MULTIPLE_SUBSCRIBERS.md
│   │
│   └── reference/                   ← Reference documentation
│       ├── ADDING_NEW_TABLES.md
│       └── DYNAMIC_MESSAGE_GENERATION.md
│
├── 🔧 scripts/ (PowerShell Scripts)
│   │
│   ├── demo/                        ← Demo & presentation scripts
│   │   ├── demo.ps1                ← Main orchestrator ⭐
│   │   ├── auto-send-messages.ps1
│   │   ├── auto-send-messages-dynamic.ps1
│   │   ├── demo-continuous.ps1
│   │   ├── generate-data-simple.ps1
│   │   ├── generate-tracked-table-data.ps1
│   │   └── start-data-generator.ps1
│   │
│   ├── setup/                       ← Initial setup scripts
│   │   ├── init-database.ps1
│   │   ├── init-receiver-demo.ps1  ← Database initialization
│   │   ├── setup-and-test.ps1
│   │   ├── setup-database-driven-mqtt.ps1
│   │   ├── setup-filtered-test.ps1
│   │   └── setup-multi-table-system.ps1
│   │
│   ├── services/                    ← Service management
│   │   ├── Start-FullSystem.ps1
│   │   ├── run-receiver.ps1
│   │   ├── run-publisher.ps1
│   │   ├── run-multi-table-publisher.ps1
│   │   ├── run-subscriber1.ps1
│   │   ├── run-subscriber2.ps1
│   │   ├── start-subscriber-1.ps1
│   │   ├── start-subscriber-2.ps1
│   │   └── stop-services.ps1
│   │
│   ├── testing/                     ← Testing scripts
│   │   ├── test-complete-system.ps1 ← Complete system test ⭐
│   │   ├── run-complete-test.ps1
│   │   ├── run-filtered-test.ps1
│   │   ├── run-test.ps1
│   │   ├── test-add-new-table.ps1
│   │   ├── test-command-line-params.ps1
│   │   ├── test-connection.ps1
│   │   ├── test-enhanced-records.ps1
│   │   ├── test-send-mqtt-message.ps1
│   │   └── test-unique-clientids.ps1
│   │
│   ├── utility/                     ← Helper utilities
│   │   ├── add-demo-records.ps1
│   │   ├── add-monitor.ps1
│   │   ├── add-source-table.ps1
│   │   ├── add-test-message.ps1
│   │   ├── insert-test-records.ps1
│   │   ├── reset-messages.ps1
│   │   ├── verify-system-status.ps1
│   │   └── verify-tabled-published.ps1
│   │
│   └── deployment/                  ← Deployment automation
│       └── Deploy-ToAzure.ps1       ← Azure deployment script
│
├── 💻 src/ (Source Code)
│   ├── ReceiverService/             ← MQTT → Database
│   │   ├── Worker.cs
│   │   ├── Services/
│   │   │   └── MessageProcessor.cs
│   │   ├── Models/
│   │   │   └── ReceiverConfiguration.cs
│   │   └── appsettings.json
│   │
│   ├── MultiTablePublisher/         ← Database → MQTT
│   │   ├── Worker.cs
│   │   ├── Services/
│   │   └── appsettings.json
│   │
│   ├── MonitorDashboard/            ← Blazor Dashboard
│   │   ├── Pages/
│   │   │   └── Index.razor
│   │   └── appsettings.json
│   │
│   ├── PublisherService/            ← Legacy publisher
│   └── SubscriberService/           ← Legacy subscriber
│
├── 🗄️ sql/ (Database Scripts)
│   ├── INIT_RECEIVER_SCHEMA.sql     ← Receiver tables (ReceiverConfig, etc.)
│   ├── LOAD_RECEIVER_DEMO.sql       ← Demo configuration data
│   └── INIT_PUBLISHER_SCHEMA.sql    ← Publisher tables (SourceTableConfig)
│
├── 🐳 docker/ (Docker Configuration)
│   └── mosquitto/
│       ├── config/
│       ├── data/
│       └── log/
│
└── ⚙️ config/ (Configuration Files)
```

## 🎯 Quick Navigation

### I want to...

**...run a quick demo (5 minutes)**
→ `scripts/demo/demo.ps1 -Action full-demo-with-dashboard`
→ See: `STREAMLINED_WORKFLOWS.md` section 1

**...test the system (2 minutes)**
→ `scripts/testing/test-complete-system.ps1`
→ See: `STREAMLINED_WORKFLOWS.md` section 2

**...deploy to Azure (15 minutes)**
→ `scripts/deployment/Deploy-ToAzure.ps1`
→ See: `STREAMLINED_WORKFLOWS.md` section 3

**...understand how it works**
→ Read: `docs/guides/QUICK_START_DEMO.md`
→ Read: `docs/architecture/PROJECT_SUMMARY.md`

**...add a new table**
→ Read: `docs/reference/ADDING_NEW_TABLES.md`
→ Execute SQL INSERT into `MQTT.ReceiverConfig`

**...troubleshoot issues**
→ Read: `docs/guides/DEMO_RESULTS.md`
→ Run: `scripts/utility/verify-system-status.ps1`

## 📊 File Organization Principles

### Documentation (docs/)
- **guides/**: Step-by-step walkthroughs for users
- **architecture/**: Technical design documentation
- **deployment/**: Production deployment guides
- **testing/**: Testing strategies and procedures
- **reference/**: How-to guides and reference material

### Scripts (scripts/)
- **demo/**: Interactive demonstrations
- **setup/**: One-time initialization scripts
- **services/**: Start/stop service management
- **testing/**: Automated testing scripts
- **utility/**: Helper tools and verification
- **deployment/**: Production deployment automation

### Source Code (src/)
- **ReceiverService/**: Production MQTT→SQL service
- **MultiTablePublisher/**: Production SQL→MQTT service
- **MonitorDashboard/**: Optional Blazor dashboard
- **PublisherService/**: Legacy single-table publisher
- **SubscriberService/**: Legacy subscriber

## 🎨 Color Legend

📄 Documentation files
📚 Documentation folders
🔧 Scripts and automation
💻 Source code
🗄️ Database scripts
🐳 Docker configuration
⚙️ Configuration files
⭐ Most frequently used

## 📋 Recommended Reading Order

### First Time Users
1. `README.md` - Project overview
2. `STREAMLINED_WORKFLOWS.md` - Quick reference
3. `docs/guides/QUICK_START_DEMO.md` - 3-minute demo
4. `scripts/demo/demo.ps1 -Action full-demo-with-dashboard` - Run it!

### Developers
1. `docs/architecture/PROJECT_SUMMARY.md` - Full architecture
2. `docs/guides/RECEIVER_README.md` - ReceiverService internals
3. `docs/reference/ADDING_NEW_TABLES.md` - Extension guide
4. `src/ReceiverService/Worker.cs` - Source code review

### DevOps/Deployment
1. `docs/deployment/AZURE_DEPLOYMENT.md` - Azure setup
2. `scripts/deployment/Deploy-ToAzure.ps1` - Automation
3. `docs/deployment/DEPLOYMENT_QUICKSTART.md` - Quick reference
4. `scripts/utility/verify-system-status.ps1` - Verification

### QA/Testing
1. `docs/testing/TESTING_GUIDE.md` - Testing strategy
2. `scripts/testing/test-complete-system.ps1` - Automated tests
3. `docs/testing/MULTI_TABLE_TESTING_GUIDE.md` - One-to-many tests
4. `scripts/demo/auto-send-messages-dynamic.ps1` - Load testing
