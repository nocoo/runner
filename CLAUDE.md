# Runner - Claude Instructions

Declarative task scheduler for macOS using launchd + opencode.

## Architecture

```
launchd (scheduled times)
    ↓
runner auto (Swift binary)
    ↓
Router (match hour/minute/weekday → task)
    ↓
Executor (opencode run --agent build < prompt)
    ↓
Logger (JSON to data/runs/)
    ↓
Notifier (task-notifier skill)
```

## Key Files

| File | Purpose |
|------|---------|
| `runner` | Swift binary (main scheduler) |
| `runner-swift/` | Swift source code |
| `data/tasks.json` | Task definitions (JSON) |
| `data/schedules.json` | Schedule rules (JSON) |
| `data/*.json` | File-system API for Web UI |
| `dashboard/` | React + TypeScript Web UI |

## Commands

```bash
# Build Swift binary
cd runner-swift && swift build && cp .build/debug/Runner ../runner

# Execute task
./runner run <task_name>

# Dry-run (preview prompt)
./runner run <task_name> --dry-run

# Auto mode (time-based routing)
./runner auto

# List tasks
./runner list

# Validate configuration
./runner validate

# API queries
./runner api tasks|schedules|runs|status

# Initialize data files
./runner init

# View logs
./runner logs [run_id]
```

## Build & Install

After modifying Swift code, rebuild and install:

```bash
# 1. Build
cd runner-swift && swift build

# 2. Copy binary to project root
cp .build/debug/Runner ../runner

# 3. Validate
cd .. && ./runner validate
```

No launchd reload needed - launchd calls `./runner auto` which uses the updated binary.

## Run Swift Tests

```bash
cd runner-swift && swift test
```

## Testing Policy

- Pre-commit hooks run TypeScript lint, TypeScript tests, Swift tests, and SwiftLint.
- Do not skip tests in normal workflows.
- For check-in validation, run the full suite three times before push.

```bash
cd dashboard && bun run lint
cd dashboard && bun test --bail
cd runner-swift && swift test
cd runner-swift && swiftlint --config .swiftlint.yml

# Repeat the full suite 3x before push
```

## launchd Management

```bash
# Check status
launchctl list | grep runner

# Reload after plist changes
launchctl unload ~/Library/LaunchAgents/com.runner.scheduler.plist
launchctl load ~/Library/LaunchAgents/com.runner.scheduler.plist

# View logs
tail -f logs/launchd.log
```

## Adding a New Task

Edit `data/tasks.json` and `data/schedules.json` directly:

**1. Add to `data/schedules.json`:**
```json
{
  "task": "my_task",
  "hour": 9,
  "minute": 0,
  "weekday": "*"
}
```

**2. Add to `data/tasks.json`:**
```json
{
  "id": "my_task",
  "type": "agent",
  "description": "My task description",
  "timeout": 300,
  "prompt": "Your prompt here"
}
```

## Dependencies

- Runtime: `opencode`
- Dashboard: `bun`
- Notify: `~/.claude/skills/task-notifier/scripts/notify.py`

## File-System API

Web UI reads these JSON files directly:

```
data/
├── state.json        # System status
├── tasks.json        # Task definitions
├── schedules.json    # Schedule rules
└── runs/
    ├── index.json    # Execution history
    └── <uuid>.json   # Individual run details
```

## Current Schedules

- **Heartbeat**: :10, :20, :40, :50 every hour
- **Clock**: :00 and :30 every hour (text-to-speech chime)
- **Obsidian Sync**: :00, :15, :30, :45 every hour
