<p align="center">
  <img src="../assets/brand/icon-rounded.png" alt="Runner" width="128" height="128" />
</p>

<h1 align="center">Runner</h1>

<p align="center">Schedule local tasks on macOS and inspect their runs and output in one place.</p>

<p align="center">
  <a href="../README.md">简体中文</a>
</p>

## What it does

Runner is a macOS task scheduler for personal workflows. A task can be a shell command, an OpenCode prompt, or an HTTP request, started manually through the CLI or triggered on a schedule by launchd. Its local Dashboard shows tasks, run history, and output, and can add and manually trigger tasks.

Task execution is managed on your Mac, where run records and output are stored. This makes Runner useful for recurring scripts and AI tasks you maintain yourself. The current Dashboard API runs inside the Vite development server; there is no separate production web server or sign-in system.

## Features

- Match schedules by hour, minute, and weekday, with wildcards, single values, ranges, lists, and `*/N` steps.
- Execute shell, OpenCode, and HTTP tasks with working directories and timeouts; keep output in text files.
- Store run records in SQLite, including start times, exit codes, durations, and interrupted states.
- Inspect task details, history, trends, and run statistics in the Dashboard, with file-change notifications updating the page.
- Query JSON data, save tasks, migrate older JSON data, and check interrupted tasks through the CLI.

Each `auto` invocation checks the current time once and starts matching tasks; recurring execution needs an external timer. Schedule matching currently uses UTC+8. The default command for an OpenCode prompt selects the `build` agent and `zai-coding-plan/glm-4.7`, so OpenCode and access to that model must already be configured locally.

## Usage

### Run from source

Requires macOS 13+ and a Swift 6 toolchain. HTTP tasks use the system `curl`; programs called by shell tasks must be available in the execution environment.

```bash
git clone https://github.com/nocoo/runner.git
cd runner
swift build --package-path runner-swift
cp runner-swift/.build/debug/Runner ./runner

./runner init
./runner validate
./runner run sample
./runner logs --list
```

`init` creates the data directory and a shell example that prints a greeting. Tasks run in the background: a returned `run` command means the task has started. Inspect the final result with `logs`, `api runs`, or the Dashboard.

| Command | Purpose |
| --- | --- |
| `./runner list` | List current tasks |
| `./runner run <task-id>` | Start a task manually |
| `./runner auto --dry-run --verbose` | Inspect tasks matching the current time |
| `./runner logs <run-id> --tail 30` | Read the final 30 lines of a run's output |
| `./runner api tasks` / `./runner api runs` | Print JSON data |
| `./runner monitor` | Check and mark interrupted tasks |
| `./runner cleanup` | Preview stale-run and process cleanup |
| `./runner task-save < task.json` | Save one task to SQLite |
| `./runner migrate --help` | Inspect older JSON data migration options |

The default data directory is `data/` under the working directory; override it with `--data-dir <path>`. Cleanup and process termination require `cleanup --force`.

### Configuration and scheduling

A newly initialized data directory uses `tasks.json` and `schedules.json` as its initial configuration. This schedule runs `sample` at 09:00 UTC+8 on weekdays:

```json
[
  { "task": "sample", "hour": 9, "minute": 0, "weekday": "1-5" }
]
```

Write the schedule to `data/schedules.json` and run `./runner validate`. Tasks and schedules each prefer enabled records in SQLite, falling back to JSON only when the respective query is empty. Once tasks are saved through the Dashboard or `task-save`, editing `tasks.json` may no longer affect them. Import existing JSON configuration with `./runner migrate --config`; see the [storage design record](06-storage-abstraction.md) for migration details. Run records live in `data/runner.db`, and output lives in `data/runs/<run-id>.output`.

The [launchd configuration](../launchd/com.runner.scheduler.plist) is an example from the maintainer's machine with absolute paths and specific trigger times. Adjust its binary, working directory, log paths, and `StartCalendarInterval` to cover your schedules before installing it as a macOS LaunchAgent. `auto` does not catch up on times that the external timer did not trigger.

## Development

The Dashboard requires Bun and a Node.js version supported by Vite (22.12+). From the repository root:

```bash
bun install
cd dashboard
bun install
bun run dev
```

Open `http://localhost:7008`. Build Swift and initialize data first using the steps above. The Dashboard uses `runner` and `data/` at the repository root. After changing Swift source, rebuild and copy the binary so Dashboard-triggered tasks use the updated implementation.

From `dashboard/`, run `bun run build` for a frontend build and `bun run typecheck` / `bun run lint` for types and code style. `preview` only previews static output; the API plugin is enabled only in the development server. The Dashboard status overview still reads `data/state.json`, a different path from the CLI's SQLite status query.

```text
runner-swift/    Swift CLI, scheduling, execution, and SQLite storage
dashboard/       React interface and Vite API plugin
launchd/         Example local timer configuration
schemas/         JSON data structures
data/           Runtime data (generated locally)
docs/           Design and usage records, and this English README
```

## Tests

After installing dependencies, run from the repository root:

| Layer | Command |
| --- | --- |
| Swift unit tests | `swift test --package-path runner-swift --no-parallel --skip IntegrationTests` |
| Swift integration tests | `swift build --package-path runner-swift && swift test --package-path runner-swift --no-parallel --filter IntegrationTests` |
| Dashboard unit and component tests | `bun run --cwd dashboard test` |

Swift tests use Swift Testing and require a compatible Xcode toolchain. Integration tests start local shell tasks in temporary directories and check SQLite records and output files. The Dashboard uses Vitest and happy-dom; `bun run --cwd dashboard test:watch` enables watch mode. There is currently no separately configured browser end-to-end test command.

## Stack

![Swift](https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?logo=sqlite&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?logo=react&logoColor=61DAFB)
![Vite](https://img.shields.io/badge/Vite-646CFF?logo=vite&logoColor=white)
![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-06B6D4?logo=tailwindcss&logoColor=white)

| Area | Implementation |
| --- | --- |
| Task engine | Swift, Swift Argument Parser, macOS launchd, Bash |
| Storage | SQLite / GRDB, JSON configuration fallback, and text output |
| Dashboard | TypeScript, React, React Router, Vite, Tailwind CSS |
| Tests | Swift Testing, Vitest, React Testing Library, happy-dom |

See [Package.swift](../runner-swift/Package.swift) and the [Dashboard package.json](../dashboard/package.json) for dependencies.

## Documentation

- [Chinese README](../README.md)
- [Project overview](01-overview.md)
- [Features](02-features.md)
- [Build and run](03-quickstart.md)
- [Architecture and data flow](05-architecture.md)
- [Storage migration design](06-storage-abstraction.md)
- [Logo usage](07-logo-usage.md) · [Identity study](https://hexly.ai/logos/runner)

Numbered documents retain implementation history; some runtime requirements and storage stages are older. This README and the source describe current commands and boundaries.

## License

The repository does not currently include a license file.
