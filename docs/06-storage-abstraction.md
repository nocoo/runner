# 06 Storage Abstraction

This document outlines the plan to abstract the storage layer, enabling migration from JSON files to SQLite while maintaining behavioral compatibility.

## Background

The current storage implementation uses JSON files (`data/runs/index.json`, `data/runs/*.json`, etc.) which are prone to corruption under concurrent access. To improve reliability and support growing data volumes, we plan to migrate to SQLite.

### Problem Analysis

#### Current Write Flow

```
Swift (launchd trigger)              Bash (background)
────────────────────────             ─────────────────
READ index.json (Monitor)
WRITE index.json (addRun) ← flock
Launch nohup bash &
Exit ✅
                                     Execute command...
                                     Wait for completion...
                                     WRITE index.json ← NO LOCK! 💥
```

#### Why Conflict Occurs

1. **Two writers**: Swift uses `flock`, Bash uses raw `jq`
2. **Race condition**: Bash reads old data → Swift writes → Bash overwrites with stale data
3. **File corruption**: Partial writes can produce invalid JSON

#### Why SQLite

| Benefit | Description |
|---------|-------------|
| Atomic transactions | Single SQL statement is atomic, no manual locking |
| Concurrent safety | WAL mode supports concurrent reads/writes |
| Query power | Complex filtering, sorting, pagination, aggregation |
| Native indexing | O(log n) queries by task, time, status |
| Scalability | Handles 100k+ records easily (JSON struggles) |
| Data integrity | Foreign keys, NOT NULL, constraints |

## Current Architecture (After Phase 1)

```
┌─────────────────────────────────────────────────────┐
│  CLI Commands / Services                            │
│  (AutoService, LogService, ApiService, etc.)        │
├─────────────────────────────────────────────────────┤
│  Business Logic                                      │
│  (Executor, Monitor, Scheduler, CleanupPlanner)     │
├─────────────────────────────────────────────────────┤
│  Protocols                                           │
│  - RunRepository (unified run operations)           │
│  - ConfigRepository (tasks, schedules)              │
├─────────────────────────────────────────────────────┤
│  Storage (actor, implements protocols)              │
│  - JSON file operations with flock                  │
├─────────────────────────────────────────────────────┤
│  ScriptBuilder                                       │
│  - Generates bash scripts with jq commands          │
│  - Directly writes to JSON files (bypasses Storage) │ ← Problem!
└─────────────────────────────────────────────────────┘
```

## Target Architecture

```
┌─────────────────────────────────────────────────────┐
│  CLI Commands / Services                            │
│  (AutoService, LogService, ApiService, etc.)        │
│  + CompleteCommand (new)                            │
├─────────────────────────────────────────────────────┤
│  Business Logic                                      │
│  (Executor, Monitor, Scheduler, CleanupPlanner)     │
├─────────────────────────────────────────────────────┤
│  Protocols                                           │
│  - RunRepository                                    │
│  - ConfigRepository                                 │
├─────────────────────────────────────────────────────┤
│  SQLiteStorage (actor, implements protocols)        │
│  - All database operations in one place             │
├─────────────────────────────────────────────────────┤
│  ScriptBuilder                                       │
│  - Generates bash scripts                           │
│  - Calls `./runner complete` instead of jq          │ ← Single write point!
└─────────────────────────────────────────────────────┘
```

### Key Design: Single Write Point

```
┌─────────────────────────────────────────────────────────────────┐
│ Swift (sole writer to database)                                 │
│                                                                  │
│   ./runner auto     → INSERT INTO runs (id, task, started_at)   │
│   ./runner complete → UPDATE runs SET exit_code, finished_at    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                          ▲
                          │ callback
┌─────────────────────────┴───────────────────────────────────────┐
│ Bash (execute only, no database access)                         │
│                                                                  │
│   eval '$COMMAND'                                                │
│   EXIT_CODE=$?                                                   │
│   DURATION=$((END_TIME - START_TIME))                           │
│   ./runner complete "$RUN_ID" --exit-code $EXIT_CODE \          │
│                     --duration $DURATION                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Benefits**:
- All writes go through Swift → unified locking/transactions
- Bash becomes simpler (no jq, no sqlite3)
- Future storage changes only affect Swift code

## Refactoring Plan

### Phase 1: Repository Protocol Abstraction ✅ COMPLETED

**Goal**: Unify all Run-related read/write operations into protocols.

- [x] 1.1 Create `RunRepository` protocol
- [x] 1.2 Create `ConfigRepository` protocol  
- [x] 1.3 Storage implements both protocols
- [x] 1.4 Executor depends on `RunRepository` protocol
- [x] 1.5 Monitor depends on `RunRepository` protocol

### Phase 2: Complete Command & Script Refactor

**Goal**: Eliminate Bash writing to storage. All writes go through Swift.

#### 2.1 Add `runner complete` Command

```swift
public struct Complete: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Mark a run as completed (called by background scripts)"
    )
    
    @Argument(help: "Run ID")
    var id: String
    
    @Option(name: .long, help: "Exit code")
    var exitCode: Int
    
    @Option(name: .long, help: "Duration in seconds")
    var duration: Int
    
    @OptionGroup var options: CommonOptions
    
    public func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let finishedAt = ISO8601DateFormatter().string(from: Date())
        
        // Update run in storage
        try await storage.updateRun(id: id, exitCode: exitCode, finishedAt: finishedAt)
        
        // Write detail file
        let detail = RunDetail(
            id: id,
            task: "", // Will be looked up or passed
            trigger: "",
            startedAt: "",
            finishedAt: finishedAt,
            durationSeconds: duration,
            exitCode: exitCode
        )
        try await storage.writeRunDetail(detail)
    }
}
```

#### 2.2 Modify ScriptBuilder

Remove jq commands, replace with `./runner complete`:

```swift
public func build(...) -> String {
    return """
    #!/bin/bash
    
    # ... execution logic unchanged ...
    
    # Get exit code
    wait $CMD_PID
    EXIT_CODE=$?
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Callback to Swift (single write point)
    '\(runnerPath)' complete '\(runId)' \\
        --exit-code $EXIT_CODE \\
        --duration $DURATION \\
        --data-dir '\(dataDir.path)'
    
    # Cleanup script
    rm -f "$0"
    """
}
```

#### 2.3 Update RunRepository Protocol

Add method to support complete command needs:

```swift
public protocol RunRepository: Sendable {
    // ... existing methods ...
    
    /// Complete a run with full details (for complete command)
    func completeRun(id: String, exitCode: Int, duration: Int) async throws
}
```

### Phase 3: SQLite Migration

**Goal**: Replace JSON storage with SQLite.

#### 3.1 Add GRDB Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
]
```

#### 3.2 Database Schema

```sql
-- runs table (replaces index.json + detail files)
CREATE TABLE runs (
    id TEXT PRIMARY KEY,
    task TEXT NOT NULL,
    trigger TEXT NOT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    duration_seconds INTEGER,
    exit_code INTEGER,
    pid INTEGER,
    started_at_epoch INTEGER NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX idx_runs_task ON runs(task);
CREATE INDEX idx_runs_started_at ON runs(started_at DESC);
CREATE INDEX idx_runs_exit_code ON runs(exit_code);
CREATE INDEX idx_runs_running ON runs(pid) WHERE exit_code IS NULL;

-- tasks table (replaces tasks.json, optional - can keep JSON for config)
-- schedules table (replaces schedules.json, optional)
```

#### 3.3 Implement SQLiteStorage

```swift
public actor SQLiteStorage: RunRepository, ConfigRepository {
    private let dbQueue: DatabaseQueue
    private let configDir: URL  // Still read tasks.json, schedules.json
    
    public init(dataDir: URL) throws {
        let dbPath = dataDir.appendingPathComponent("runner.db")
        self.dbQueue = try DatabaseQueue(path: dbPath.path)
        self.configDir = dataDir
        try migrator.migrate(dbQueue)
    }
    
    // MARK: - RunRepository
    
    public func addRun(_ run: RunSummary) async throws {
        try await dbQueue.write { db in
            try RunRecord(from: run).insert(db)
        }
    }
    
    public func updateRun(id: String, exitCode: Int?, finishedAt: String?) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE runs SET exit_code = ?, finished_at = ?, pid = NULL WHERE id = ?",
                arguments: [exitCode, finishedAt, id]
            )
        }
    }
    
    public func loadRunsIndex() async throws -> RunsIndex {
        try await dbQueue.read { db in
            let runs = try RunRecord.fetchAll(db)
            return RunsIndex(
                runs: runs.map { $0.toSummary() },
                total: runs.count,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        }
    }
    
    // ... other methods
}
```

#### 3.4 Data Migration Script

```swift
public struct MigrationService {
    public func migrateJSONToSQLite(dataDir: URL) async throws {
        let jsonStorage = Storage(dataDir: dataDir)
        let sqliteStorage = try SQLiteStorage(dataDir: dataDir)
        
        // Migrate runs
        let index = try await jsonStorage.loadRunsIndex()
        for run in index.runs {
            try await sqliteStorage.addRun(run)
            
            // Migrate detail if exists
            if let detail = try await jsonStorage.loadRunDetail(id: run.id) {
                try await sqliteStorage.writeRunDetail(detail)
            }
        }
        
        // Backup old files
        let backupDir = dataDir.appendingPathComponent("backup-json")
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(
            at: dataDir.appendingPathComponent("runs"),
            to: backupDir.appendingPathComponent("runs")
        )
    }
}
```

#### 3.5 Dashboard Adaptation

Options:
1. **Swift API**: Dashboard calls `runner api runs` (already exists)
2. **Direct SQLite**: Dashboard reads `runner.db` with sql.js
3. **JSON export**: `runner api runs` outputs JSON for backward compatibility

Recommended: Keep using `runner api runs`, no Dashboard changes needed.

### Phase 4: Cleanup & Polish

#### 4.1 Output File Handling

Keep `.output` files on filesystem (not in SQLite):
- Large text content doesn't belong in database
- Easy to tail/stream with standard tools
- SQLite stores only metadata

#### 4.2 Configuration

```swift
public enum StorageBackend {
    case json   // Legacy, for migration period
    case sqlite // Default for new installations
}

public func createStorage(dataDir: URL, backend: StorageBackend) -> any RunRepository {
    switch backend {
    case .json:
        return Storage(dataDir: dataDir)
    case .sqlite:
        return try! SQLiteStorage(dataDir: dataDir)
    }
}
```

#### 4.3 Remove Legacy Code

After migration verified:
- Remove `withFileLock` from Storage
- Remove jq-related code from ScriptBuilder
- Remove JSON index file handling

## Task Breakdown

| ID | Task | Status | Files |
|----|------|--------|-------|
| 1.1 | Create `RunRepository` protocol | ✅ | `Repositories.swift` |
| 1.2 | Create `ConfigRepository` protocol | ✅ | `Repositories.swift` |
| 1.3 | Storage implements protocols | ✅ | `Storage.swift` |
| 1.4 | Executor depends on protocol | ✅ | `Executor.swift` |
| 1.5 | Monitor depends on protocol | ✅ | `Monitor.swift` |
| 2.1 | Add `runner complete` command | ⏳ | `CLICommands.swift` |
| 2.2 | Modify ScriptBuilder to use callback | ⏳ | `ScriptBuilder.swift` |
| 2.3 | Add `completeRun` to RunRepository | ⏳ | `Repositories.swift` |
| 2.4 | Update tests for new flow | ⏳ | `*Tests.swift` |
| 3.1 | Add GRDB dependency | ⏳ | `Package.swift` |
| 3.2 | Create database schema | ⏳ | `SQLiteStorage.swift` |
| 3.3 | Implement SQLiteStorage | ⏳ | `SQLiteStorage.swift` |
| 3.4 | Data migration script | ⏳ | `MigrationService.swift` |
| 3.5 | Integration tests | ⏳ | `SQLiteStorageTests.swift` |
| 4.1 | Configuration switch | ⏳ | `CommandWiring.swift` |
| 4.2 | Remove legacy JSON code | ⏳ | Various |
| 4.3 | Update documentation | ⏳ | `docs/` |

## Success Criteria

1. ✅ All existing tests pass after each phase
2. ✅ No behavioral changes to upper layers (Dashboard, CLI)
3. ⏳ Single write point: only Swift writes to storage
4. ⏳ SQLite migration completes without data loss
5. ⏳ Concurrent access no longer causes corruption
6. ⏳ Query performance improved for large datasets

## Rollback Plan

If issues arise after SQLite migration:

1. JSON backup preserved in `data/backup-json/`
2. Set `RUNNER_STORAGE=json` environment variable
3. Restore JSON files from backup
4. File issue for investigation

## References

- Current Storage: `Sources/RunnerLib/Storage.swift`
- Current ScriptBuilder: `Sources/RunnerLib/ScriptBuilder.swift`
- Repository Protocols: `Sources/RunnerLib/Repositories.swift`
- GRDB Documentation: https://github.com/groue/GRDB.swift
