# Runner - Declarative Task Scheduler

Time-based automation task scheduler for macOS, executing AI tasks via `opencode`.

![Runner Dashboard](https://assets.lizheng.me/wp-content/uploads/2026/01/runner.png)

## Features

| Feature | Description |
|---------|-------------|
| **Crontab-style Scheduling** | Supports `*`, `N,M`, `N-M`, `*/N` expressions |
| **Declarative Config** | JSON-defined tasks and schedules |
| **Config Validation** | Pre-flight validation catches errors early |
| **File-system API** | JSON data files for Web UI integration |
| **Native macOS** | Swift binary with launchd integration |
| **Notifications** | Via task-notifier skill |
| **Matrix Dashboard** | React + TypeScript real-time monitoring |

## Quick Start

### 1. Build

```bash
cd runner-swift && swift build && cp .build/debug/Runner ../runner
```

### 2. Initialize

```bash
./runner init
```

### 3. Run

```bash
# List tasks
./runner list

# Run a task
./runner run heartbeat

# Dry-run (preview)
./runner run heartbeat --dry-run

# Auto mode (time-based)
./runner auto
```

## Directory Structure

```
runner/
├── runner              # Swift binary
├── runner-swift/       # Swift source code
├── data/               # JSON API data
│   ├── state.json
│   ├── tasks.json
│   ├── schedules.json
│   └── runs/
├── dashboard/          # React + TypeScript Web UI
├── launchd/            # launchd plist
└── logs/
```

## CLI Commands

```bash
# Task execution
./runner run <task>           # Execute task
./runner run <task> --dry-run # Preview only
./runner auto                 # Time-based routing

# Management
./runner list                 # List all tasks
./runner validate             # Validate config
./runner init                 # Initialize data files

# Monitoring
./runner logs                 # Latest run output
./runner logs <run_id>        # Specific run output
./runner monitor              # Check stale tasks

# API queries
./runner api tasks
./runner api schedules
./runner api runs
./runner api status
```

## Configuration

### tasks.json

```json
[
  {
    "id": "heartbeat",
    "type": "simple",
    "description": "Play notification sound",
    "timeout": 10,
    "command": "afplay /System/Library/Sounds/Pop.aiff"
  },
  {
    "id": "clock",
    "type": "agent",
    "description": "Announce time via TTS",
    "timeout": 60,
    "prompt": "Get current time and announce it using say command"
  }
]
```

### schedules.json

```json
[
  { "task": "clock", "hour": "*", "minute": 0, "weekday": "*" },
  { "task": "clock", "hour": "*", "minute": 30, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 10, "weekday": "*" }
]
```

### Crontab Expressions

| Syntax | Meaning | Example |
|--------|---------|---------|
| `*` | Any value | `hour: "*"` every hour |
| `N` | Exact value | `hour: 9` at 9:00 |
| `N,M,O` | List | `minute: "0,15,30,45"` |
| `N-M` | Range | `hour: "9-17"` 9am-5pm |
| `*/N` | Step | `minute: "*/10"` every 10 min |

## launchd Integration

### Install

```bash
cp launchd/com.runner.scheduler.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.runner.scheduler.plist
```

### Manage

```bash
launchctl list | grep runner                    # Status
launchctl start com.runner.scheduler            # Manual trigger
launchctl unload ~/Library/LaunchAgents/...     # Unload
```

## Dashboard

Matrix-style real-time monitoring panel.

```bash
cd dashboard
bun install
bun run dev
# Open http://localhost:7009
```

### Features

- Real-time clock with Matrix animation
- Task list with schedules
- Run history with pagination
- Activity heatmap (30 days)
- Trend chart (24 hours)
- Upcoming tasks countdown

### Tests

```bash
cd dashboard
bun test
bun test --coverage
```

## Swift Development

```bash
cd runner-swift

# Build
swift build

# Test
swift test

# Copy to project root
cp .build/debug/Runner ../runner
```

## File-system API

Web UI reads JSON files directly:

```
data/
├── state.json        # GET /api/status
├── tasks.json        # GET /api/tasks
├── schedules.json    # GET /api/schedules
└── runs/
    ├── index.json    # GET /api/runs
    └── <uuid>.json   # GET /api/runs/:id
```

## License

MIT
