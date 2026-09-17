# Runner

macOS CLI scheduler for local shell, OpenCode and HTTP tasks with a local web dashboard.
Profile: native-tool (Swift CLI) + ts-web.
Direction: [README.md](README.md). Frameworks must preserve this handbook.

## Sources of Truth

This file is the quality contract; hooks, CI and config are enforcement. Close implementation gaps without lowering the contract. Historical test results are not evidence of a current passing run.

| Fact | Where |
|---|---|
| Product / startup | [README.md](README.md), [architecture](docs/05-architecture.md) |
| Storage | [storage design](docs/06-storage-abstraction.md), `runner-swift/Sources/RunnerLib` |
| Toolchain / versions | `runner-swift/Package.swift`, `dashboard/package.json`, `VERSION` |
| Enforcement | `.husky`, `dashboard/vitest.config.ts`, `.github/workflows/ci.yml` |
| Accidents | [Retrospective.md](Retrospective.md) |
| Machine workflow | global `AGENTS.md` and Git rules |

## Project Invariants

- Tasks execute local programs with current user permissions; OpenCode needs configured model access. Do not launch live user tasks for routine tests.
- `auto` matches the current UTC+8 time once; launchd provides recurring triggers and does not backfill missed times. Installed launchd examples contain machine-specific paths.
- Task and schedule reads prefer enabled SQLite rows, independently falling back to JSON only when empty. Preserve migration semantics and output retention.
- Dashboard API exists only in the Vite development plugin, with no standalone production API/auth service. Keep it local; preview only serves static files.
- Dashboard uses root `runner` and `data/`; rebuild/copy the CLI after Swift changes. The dashboard status overview still reads `state.json`, unlike CLI SQLite status.

## Stack / Layout

| Component | Path / choice |
|---|---|
| CLI / persistence | `runner-swift`, Swift 6/ArgumentParser/GRDB SQLite |
| UI / local API | `dashboard`, React/TypeScript/Vite/Tailwind |
| Schedule / schemas | `launchd`, `schemas`; local runtime `data/` |

## Commands

Run from root on macOS 13+ with full Xcode/Swift 6, Bun, Node 22.12+ and SwiftLint. Set `DEVELOPER_DIR` per command when only Command Line Tools is selected. Dashboard tests use UTC; integration tests need the built Runner binary and run without parallelism.

```bash
bun install --frozen-lockfile
bun install --cwd dashboard --frozen-lockfile
swift build --package-path runner-swift
swift test --package-path runner-swift --no-parallel --skip IntegrationTests
swift test --package-path runner-swift --no-parallel --filter IntegrationTests
bun run --cwd dashboard typecheck
bun run --cwd dashboard lint
bun run --cwd dashboard test:coverage
bun run --cwd dashboard build
swiftlint --config runner-swift/.swiftlint.yml runner-swift
```

## Verification

6DQ = L1/L2/L3 + G1/G2 + D1 (test isolation). Status: `enforced`, `planned`, `manual`, or `N/A`; partial enforcement below does not certify the full required bar.
L1 requires statements, branches, functions and lines each ≥95%, with no skipped/focused tests; preserve any stricter package threshold. Native tools must identify unmeasured metrics as gaps.
G1 requires check-only strict analysis/formatting with zero errors/warnings. G2 requires dependency and secret scans, with missing required scanners failing.

| Dimension | Status | Required proof and current evidence/gap |
|---|---|---|
| L1 Swift | planned | Hooks/CI run Swift Testing without coverage. Require all four 95% or explicitly identify unavailable native metrics; current plain tests are not coverage proof. |
| L1 TypeScript | planned | Dashboard coverage config sets all four 95%, but hooks/CI run plain `test`, with broad UI/API exclusions. Wire the coverage command and full source scope. |
| L2 CLI / HTTP | planned | Integration tests execute real local shell/storage flows in unique temporary directories, but may omit binary-result assertions when Runner is missing. Vite HTTP route coverage is not automated at 100%. |
| L3 dashboard / CLI | manual | Exercise real local command execution, outputs/history and dashboard pages with disposable data. No full Playwright/system-workflow gate exists; CLI is applicable, not N/A. |
| G1 Swift / TS | planned | ESLint zero-warning gate and CI typecheck exist; pre-push SwiftLint is not strict and no formatter gate covers both languages. |
| G2 | planned | CI scans Bun lockfiles and secrets; hooks lack scanners and Swift Package.resolved dependency coverage is not configured. |
| D1 | planned | Swift suites use temporary UUID directories, but ordinary CLI/dashboard default to root data and no checked fixture marker/destructive cleanup guard exists. |

Pre-commit runs all Swift tests, dashboard tests and ESLint. Pre-push repeats tests/lint and runs SwiftLint. Neither hook enforces coverage, pushed-ref/index snapshots or G2; CI adds types and security. Ensure normal Husky wrappers are installed so both hooks execute.

Target hooks: pre-commit checks G1 + L1 against the index snapshot (`git checkout-index`) in <30s; pre-push checks L2 and G2 in parallel against every stdin push ref/commit in <3min, plus build where applicable. L3 runs in CI or an explicit manual lane.
Never bypass commit/push hooks, force-push, or use autofix in checks. Documentation changes do not authorize deploying or implementing new gates.

## Resources / Isolation

Dashboard dev is loopback 7008 and points at real root data. Tests must use unique temporary `--data-dir` paths, synthetic tasks and owned child processes; never point cleanup at daily data or kill an unrelated PID. Require fixture markers and canonical-path/ownership guards before future automated resets.

## Operations / Release

Follow README for build/copy and launchd setup; do not install the machine-specific plist unchanged. `cleanup` previews by default; `cleanup --force` mutates data and terminates processes, so keep it outside ordinary verification. Do not equate successful task launch with successful completion; inspect persisted final results.

## Retrospective

Move accident narratives to [Retrospective.md](Retrospective.md); keep at most about ten concise recurring project rules here. Put architecture and operational detail in linked docs.

- DOM tests must use throwing assertions in `waitFor` and account for the React/happy-dom controlled-input behavior.
- Keep Tailwind `@theme` tokens and utility names in matching kebab-case.
- Build the Runner executable before integration proof; do not report conditionally skipped result assertions as full success.
