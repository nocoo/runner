# 06 Storage Abstraction

This document outlines the plan to abstract the storage layer, enabling future migration from JSON files to SQLite while maintaining behavioral compatibility.

## Background

The current storage implementation uses JSON files (`data/runs/index.json`, `data/runs/*.json`, etc.) which are prone to corruption under concurrent access. To improve reliability and support growing data volumes, we plan to migrate to SQLite. This requires proper abstraction first.

## Current Architecture

```
┌─────────────────────────────────────────────────────┐
│  CLI Commands / Services                            │
│  (AutoService, LogService, ApiService, etc.)        │
├─────────────────────────────────────────────────────┤
│  Business Logic                                      │
│  (Executor, Monitor, Scheduler, CleanupPlanner)     │
├─────────────────────────────────────────────────────┤
│  Storage (actor)                                     │
│  - loadTasks, loadSchedules, loadRunsIndex          │
│  - addRun, updateRun, markInterrupted               │
│  - writeOutput, writeRunDetail, loadRunDetail       │
├─────────────────────────────────────────────────────┤
│  FileIO (protocol)                                   │
│  - readData, writeData, fileExists, flock...        │
├─────────────────────────────────────────────────────┤
│  ScriptBuilder                                       │
│  - Generates bash scripts with jq commands          │
│  - Directly writes to JSON files (bypasses Storage) │
└─────────────────────────────────────────────────────┘
```

### Existing Protocol Abstractions

| Protocol | Methods | Consumer |
|----------|---------|----------|
| `TaskLoading` | loadTasks, loadSchedules | AutoService |
| `TasksLoading` | loadTasks | ApiService |
| `SchedulesLoading` | loadSchedules | ApiService |
| `RunsIndexLoading` | loadRunsIndex | LogService |
| `RunDetailLoading` | loadRunDetail | CleanupPlanner |
| `Initializing` | initialize | ApiService |
| `FileIO` | Low-level file operations | Storage |

### Current Issues

1. **Fragmented Protocols** - Multiple small protocols without a unified `RunRepository`
2. **ScriptBuilder Bypasses Abstraction** - Bash scripts use `jq` to modify JSON directly
3. **Direct Storage Dependency** - `Executor`, `Monitor` depend on concrete `Storage` type
4. **Missing Write Protocols** - `addRun`, `updateRun`, `writeOutput` have no protocol

## Refactoring Plan

### Phase 1: Repository Protocol Abstraction

**Goal**: Unify all Run-related read/write operations into protocols.

#### 1.1 Create `RunRepository` Protocol

```swift
/// Core repository protocol for run operations
public protocol RunRepository: Sendable {
    // Index operations
    func loadRunsIndex() async throws -> RunsIndex
    func addRun(_ run: RunSummary) async throws
    func updateRun(id: String, exitCode: Int?, finishedAt: String?) async throws
    func markInterrupted(id: String) async throws
    func getRunningTasks() async throws -> [RunSummary]
    
    // Detail operations
    func writeRunDetail(_ detail: RunDetail) async throws
    func loadRunDetail(id: String) async throws -> RunDetail?
    
    // Output operations
    func writeOutput(id: String, content: String) async throws
    func appendOutput(id: String, content: String) async throws
}
```

#### 1.2 Create `ConfigRepository` Protocol

```swift
/// Repository protocol for configuration (read-only at runtime)
public protocol ConfigRepository: Sendable {
    func loadTasks() async throws -> [Task]
    func loadSchedules() async throws -> [Schedule]
    func initialize() async throws
}
```

#### 1.3 Update Storage Implementation

- `Storage` implements both `RunRepository` and `ConfigRepository`
- Existing behavior remains unchanged

#### 1.4 Update Business Logic Dependencies

- `Executor` depends on `RunRepository` (protocol) instead of `Storage` (concrete)
- `Monitor` depends on `RunRepository` instead of `Storage`
- Other services updated accordingly

### Phase 2: ScriptBuilder Abstraction

**Goal**: Abstract the storage operations in generated bash scripts.

#### 2.1 Create `ScriptStorageBuilder` Protocol

```swift
/// Protocol for generating storage operation scripts
public protocol ScriptStorageBuilder {
    /// Generate script fragment to write RunDetail
    func buildWriteDetailScript(
        runId: String,
        taskId: String,
        trigger: String,
        startedAt: String,
        detailPath: String
    ) -> String
    
    /// Generate script fragment to update run completion status
    func buildUpdateIndexScript(
        runId: String,
        indexPath: String
    ) -> String
}
```

#### 2.2 Implement `JsonScriptStorageBuilder`

Current jq-based implementation extracted into this class.

#### 2.3 Inject Dependency into ScriptBuilder

```swift
public struct ScriptBuilder {
    private let dataDir: URL
    private let storageBuilder: ScriptStorageBuilder
    
    public init(dataDir: URL, storageBuilder: ScriptStorageBuilder = JsonScriptStorageBuilder()) {
        self.dataDir = dataDir
        self.storageBuilder = storageBuilder
    }
}
```

### Phase 3: Unit Test Coverage

**Goal**: Ensure 90% coverage on all repository operations before migration.

| Target | Coverage Requirement |
|--------|---------------------|
| `RunRepository` methods | All methods with success/failure cases |
| `ConfigRepository` methods | All methods |
| `ScriptStorageBuilder` | Script generation validation |
| Mock-based service tests | Executor, Monitor with mock repositories |

### Phase 4: SQLite Migration

**Goal**: Implement SQLite storage without changing upper layers.

#### 4.1 Implement `SQLiteStorage`

- Implements `RunRepository` and `ConfigRepository`
- Uses GRDB.swift or SQLite.swift library
- Maintains same API contract

#### 4.2 Implement `SQLiteScriptStorageBuilder`

- Generates `sqlite3` commands instead of `jq`
- Same script interface, different implementation

#### 4.3 Data Migration

- One-time migration script: JSON to SQLite
- Backup original JSON files

#### 4.4 Configuration Switch

- Support selecting storage backend via configuration
- Default to SQLite for new installations

## Task Breakdown

| ID | Task | Files | New Tests |
|----|------|-------|-----------|
| 1.1 | Create `RunRepository` protocol | `Sources/RunnerLib/Protocols.swift` | - |
| 1.2 | Create `ConfigRepository` protocol | `Sources/RunnerLib/Protocols.swift` | - |
| 1.3 | Storage implements new protocols | `Sources/RunnerLib/Storage.swift` | - |
| 1.4 | Executor depends on protocol | `Sources/RunnerLib/Executor.swift` | Mock tests |
| 1.5 | Monitor depends on protocol | `Sources/RunnerLib/Monitor.swift` | Mock tests |
| 2.1 | Create `ScriptStorageBuilder` protocol | `Sources/RunnerLib/Protocols.swift` | - |
| 2.2 | Extract `JsonScriptStorageBuilder` | `Sources/RunnerLib/JsonScriptStorageBuilder.swift` | Script tests |
| 2.3 | ScriptBuilder uses dependency injection | `Sources/RunnerLib/ScriptBuilder.swift` | - |
| 3.1 | Add Repository interface tests | `Tests/RunnerTests/RepositoryTests.swift` | Full coverage |
| 3.2 | Add mock-based service tests | Various test files | Protocol mocks |

## Success Criteria

1. All existing tests pass after each phase
2. No behavioral changes to upper layers
3. 90% test coverage on repository interfaces
4. SQLite migration completes without data loss
5. Dashboard works identically with both backends

## References

- Current Storage: `Sources/RunnerLib/Storage.swift`
- Current FileIO: `Sources/RunnerLib/FileIO.swift`
- Current ScriptBuilder: `Sources/RunnerLib/ScriptBuilder.swift`
- Storage Tests: `Tests/RunnerTests/StorageTests.swift`
