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
| `tasks.yaml` | Schedule rules + task metadata |
| `tasks/*.md` | Task prompts (markdown) |
| `data/*.json` | File-system API for Web UI |
| `schemas/*.json` | JSON Schema validation |
| `tests/*.bats` | 45 bats tests |

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

1. Create prompt file: `tasks/<task_name>.md`
2. Add schedule in `tasks.yaml`:
   ```yaml
   schedules:
     - task: <task_name>
       hour: 9
       minute: 0
       weekday: "*"  # 0=Sun, 1=Mon, ..., 6=Sat, "*"=daily
   
   tasks:
     <task_name>:
       description: "..."
       timeout: 300
   ```
3. Regenerate API: `./runner.sh api tasks > /dev/null`

## Dependencies

- Runtime: `jq`, `yq`, `opencode`
- Test: `bats-core`, `bats-assert`, `bats-support`, `ajv-cli`
- Notify: `~/.claude/skills/task-notifier/scripts/notify.py`

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RUNNER_CONFIG_FILE` | Config path (default: `./tasks.yaml`) |
| `RUNNER_TASKS_DIR` | Tasks dir (default: `./tasks`) |
| `RUNNER_DATA_DIR` | Data dir (default: `./data`) |
| `RUNNER_SKIP_NOTIFY` | Skip notifications if set |
| `RUNNER_MOCK_HOUR/MINUTE/WEEKDAY` | Mock time for testing |

## File-System API

Web UI reads these JSON files directly:

```
data/
├── state.json        # System status
├── tasks.json        # Task list
├── schedules.json    # Schedule rules
└── runs/
    ├── index.json    # Execution history
    └── <uuid>.json   # Individual run details
```

## Current Schedules

- **Heartbeat**: :20 and :50 of hours 9-12 (speaks "调度器正常运行")
- **Morning briefing**: 09:00 daily
- **Twitter collect**: 10:00 daily
- **Evening review**: 21:00 daily
- **Weekly synthesis**: 20:00 Sunday
- **Memory cleanup**: 03:00 Monday
