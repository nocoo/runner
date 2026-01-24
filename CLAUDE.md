# Runner - Claude Instructions

Declarative task scheduler for macOS using launchd + opencode.

## Architecture

```
launchd (every 10 min)
    ↓
runner.sh auto
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
| `runner.sh` | Main scheduler (~400 lines bash) |
| `data/tasks.json` | Task definitions (JSON) |
| `data/schedules.json` | Schedule rules (JSON) |
| `data/*.json` | File-system API for Web UI |
| `tests/*.bats` | 135 bats tests |

## Commands

```bash
# Run tests
bats tests/*.bats

# Run specific test file
bats tests/routing.bats

# Execute task
./runner.sh <task_name>

# Dry-run (preview prompt)
./runner.sh <task_name> --dry-run

# Auto mode (time-based routing)
./runner.sh auto

# API queries
./runner.sh api tasks|schedules|runs|status

# Initialize/reinitialize data files
./runner.sh api init
```

## Testing with Mock Time

```bash
RUNNER_MOCK_HOUR=9 RUNNER_MOCK_MINUTE=20 RUNNER_MOCK_WEEKDAY=1 ./runner.sh auto
```

## launchd Management

```bash
# Check status
launchctl list | grep runner

# Reload after plist changes
launchctl unload ~/Library/LaunchAgents/com.runner.scheduler.plist
launchctl load ~/Library/LaunchAgents/com.runner.scheduler.plist

# View logs
tail -f logs/runner.log
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
  "prompt": "Your prompt here or path to prompt file"
}
```

## Dependencies

- Runtime: `jq`, `opencode`
- Test: `bats-core`, `bats-assert`, `bats-support`, `yq` (for tests)
- Notify: `~/.claude/skills/task-notifier/scripts/notify.py`

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RUNNER_DATA_DIR` | Data dir (default: `./data`) |
| `RUNNER_SKIP_NOTIFY` | Skip notifications if set |
| `RUNNER_MOCK_HOUR/MINUTE/WEEKDAY` | Mock time for testing |

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
