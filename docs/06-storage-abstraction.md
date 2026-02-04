# 06 存储层抽象与 SQLite 迁移

本文档描述存储层抽象计划，目标是从 JSON 文件迁移到 SQLite，同时保持行为兼容性。

## 背景

当前存储实现使用 JSON 文件（`data/runs/index.json`、`data/runs/*.json` 等），在并发访问时容易损坏。为了提高可靠性并支持数据量增长，我们计划迁移到 SQLite。

### 问题分析

#### 当前写入流程

```
Swift (launchd 触发)                 Bash (后台运行)
────────────────────                 ─────────────────
READ index.json (Monitor)
WRITE index.json (addRun) ← flock
启动 nohup bash &
退出 ✅
                                     执行命令...
                                     等待完成...
                                     WRITE index.json ← 无锁！💥
```

#### 冲突原因

1. **两个写入者**：Swift 使用 `flock`，Bash 使用原生 `jq`
2. **竞态条件**：Bash 读取旧数据 → Swift 写入 → Bash 用旧数据覆盖
3. **文件损坏**：部分写入可能产生无效 JSON

#### 为什么选择 SQLite

| 优势 | 说明 |
|------|------|
| 原子事务 | 单条 SQL 语句天然原子，无需手动加锁 |
| 并发安全 | WAL 模式支持并发读写 |
| 查询能力 | 支持复杂过滤、排序、分页、聚合 |
| 原生索引 | 按 task、时间、状态查询 O(log n) |
| 扩展性 | 轻松处理 10 万+ 记录（JSON 会很慢） |
| 数据完整性 | 外键约束、NOT NULL 等 |

## 当前架构（Phase 1 完成后）

```
┌─────────────────────────────────────────────────────┐
│  CLI 命令 / 服务层                                    │
│  (AutoService, LogService, ApiService 等)           │
├─────────────────────────────────────────────────────┤
│  业务逻辑层                                           │
│  (Executor, Monitor, Scheduler, CleanupPlanner)     │
├─────────────────────────────────────────────────────┤
│  协议层                                               │
│  - RunRepository (统一的 run 操作)                   │
│  - ConfigRepository (tasks, schedules)              │
├─────────────────────────────────────────────────────┤
│  Storage (actor, 实现协议)                           │
│  - JSON 文件操作 + flock                             │
├─────────────────────────────────────────────────────┤
│  ScriptBuilder                                       │
│  - 生成带 jq 命令的 bash 脚本                         │
│  - 直接写入 JSON 文件（绕过 Storage）                 │ ← 问题所在！
└─────────────────────────────────────────────────────┘
```

## 目标架构

```
┌─────────────────────────────────────────────────────┐
│  CLI 命令 / 服务层                                    │
│  (AutoService, LogService, ApiService 等)           │
│  + CompleteCommand (新增)                            │
├─────────────────────────────────────────────────────┤
│  业务逻辑层                                           │
│  (Executor, Monitor, Scheduler, CleanupPlanner)     │
├─────────────────────────────────────────────────────┤
│  协议层                                               │
│  - RunRepository                                    │
│  - ConfigRepository                                 │
├─────────────────────────────────────────────────────┤
│  SQLiteStorage (actor, 实现协议)                     │
│  - 所有数据库操作集中在这里                            │
├─────────────────────────────────────────────────────┤
│  ScriptBuilder                                       │
│  - 生成 bash 脚本                                    │
│  - 调用 `./runner complete` 而非 jq                  │ ← 单一写入点！
└─────────────────────────────────────────────────────┘
```

### 核心设计：单一写入点

```
┌─────────────────────────────────────────────────────────────────┐
│ Swift（唯一写入者）                                               │
│                                                                  │
│   ./runner auto     → INSERT INTO runs (id, task, started_at)   │
│   ./runner complete → UPDATE runs SET exit_code, finished_at    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                          ▲
                          │ 回调
┌─────────────────────────┴───────────────────────────────────────┐
│ Bash（只执行命令，不访问数据库）                                   │
│                                                                  │
│   eval '$COMMAND'                                                │
│   EXIT_CODE=$?                                                   │
│   DURATION=$((END_TIME - START_TIME))                           │
│   ./runner complete "$RUN_ID" --exit-code $EXIT_CODE \          │
│                     --duration $DURATION                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**优势**：
- 所有写入都经过 Swift → 统一的锁/事务机制
- Bash 脚本更简单（不需要 jq 或 sqlite3）
- 未来更换存储后端只需改 Swift 代码

## 重构计划

### Phase 1: Repository 协议抽象 ✅ 已完成

**目标**：将所有 Run 相关的读写操作统一到协议中。

- [x] 1.1 创建 `RunRepository` 协议
- [x] 1.2 创建 `ConfigRepository` 协议
- [x] 1.3 Storage 实现这两个协议
- [x] 1.4 Executor 依赖 `RunRepository` 协议
- [x] 1.5 Monitor 依赖 `RunRepository` 协议

### Phase 2: Complete 命令与脚本重构

**目标**：消除 Bash 直接写入存储。所有写入都经过 Swift。

#### 2.1 添加 `runner complete` 命令

```swift
public struct Complete: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "标记任务完成（由后台脚本调用）"
    )
    
    @Argument(help: "Run ID")
    var id: String
    
    @Option(name: .long, help: "退出码")
    var exitCode: Int
    
    @Option(name: .long, help: "运行时长（秒）")
    var duration: Int
    
    @OptionGroup var options: CommonOptions
    
    public func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let finishedAt = ISO8601DateFormatter().string(from: Date())
        
        // 更新存储中的 run 记录
        try await storage.completeRun(id: id, exitCode: exitCode, duration: duration)
    }
}
```

#### 2.2 修改 ScriptBuilder

移除 jq 命令，替换为 `./runner complete`：

```swift
public func build(...) -> String {
    return """
    #!/bin/bash
    
    # ... 执行逻辑不变 ...
    
    # 获取退出码
    wait $CMD_PID
    EXIT_CODE=$?
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # 回调 Swift（单一写入点）
    '\(runnerPath)' complete '\(runId)' \\
        --exit-code $EXIT_CODE \\
        --duration $DURATION \\
        --data-dir '\(dataDir.path)'
    
    # 清理脚本
    rm -f "$0"
    """
}
```

#### 2.3 扩展 RunRepository 协议

添加支持 complete 命令的方法：

```swift
public protocol RunRepository: Sendable {
    // ... 现有方法 ...
    
    /// 完成一个 run（供 complete 命令使用）
    func completeRun(id: String, exitCode: Int, duration: Int) async throws
}
```

### Phase 3: SQLite 迁移

**目标**：将 JSON 存储替换为 SQLite。

#### 3.1 添加 GRDB 依赖

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
]
```

#### 3.2 数据库 Schema

```sql
-- runs 表（替代 index.json + detail 文件）
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

-- 常用查询的索引
CREATE INDEX idx_runs_task ON runs(task);
CREATE INDEX idx_runs_started_at ON runs(started_at DESC);
CREATE INDEX idx_runs_exit_code ON runs(exit_code);
CREATE INDEX idx_runs_running ON runs(pid) WHERE exit_code IS NULL;
```

#### 3.3 实现 SQLiteStorage

```swift
public actor SQLiteStorage: RunRepository, ConfigRepository {
    private let dbQueue: DatabaseQueue
    private let configDir: URL  // 仍然从 JSON 读取 tasks.json, schedules.json
    
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
    
    public func completeRun(id: String, exitCode: Int, duration: Int) async throws {
        let finishedAt = ISO8601DateFormatter().string(from: Date())
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE runs 
                    SET exit_code = ?, finished_at = ?, duration_seconds = ?, pid = NULL 
                    WHERE id = ?
                    """,
                arguments: [exitCode, finishedAt, duration, id]
            )
        }
    }
    
    public func loadRunsIndex() async throws -> RunsIndex {
        try await dbQueue.read { db in
            let runs = try RunRecord.order(Column("started_at").desc).fetchAll(db)
            return RunsIndex(
                runs: runs.map { $0.toSummary() },
                total: runs.count,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        }
    }
    
    // ... 其他方法
}
```

#### 3.4 数据迁移

```swift
public struct MigrationService {
    public func migrateJSONToSQLite(dataDir: URL) async throws {
        let jsonStorage = Storage(dataDir: dataDir)
        let sqliteStorage = try SQLiteStorage(dataDir: dataDir)
        
        // 迁移 runs
        let index = try await jsonStorage.loadRunsIndex()
        for run in index.runs {
            try await sqliteStorage.addRun(run)
            
            // 如果有 detail 文件也迁移
            if let detail = try await jsonStorage.loadRunDetail(id: run.id) {
                try await sqliteStorage.writeRunDetail(detail)
            }
        }
        
        print("迁移完成：\(index.runs.count) 条记录")
    }
}
```

#### 3.5 Dashboard 适配

Dashboard 继续使用 `runner api runs`，无需修改。Swift 端输出 JSON 格式不变。

### Phase 4: 清理

#### 4.1 Output 文件处理

保持 `.output` 文件在文件系统（不放入 SQLite）：
- 大文本内容不适合存数据库
- 便于用标准工具 tail/stream
- SQLite 只存元数据

#### 4.2 移除遗留代码

迁移完成后：
- 删除 Storage 中的 `withFileLock`
- 删除 ScriptBuilder 中的 jq 相关代码
- 删除 JSON index 文件处理逻辑

## 已完成阶段

### Phase 1-4: Runs 迁移 ✅

| ID | 任务 | 状态 | 文件 |
|----|------|------|------|
| 1.1 | 创建 `RunRepository` 协议 | ✅ | `Repositories.swift` |
| 1.2 | 创建 `ConfigRepository` 协议 | ✅ | `Repositories.swift` |
| 1.3 | Storage 实现协议 | ✅ | `Storage.swift` |
| 1.4 | Executor 依赖协议 | ✅ | `Executor.swift` |
| 1.5 | Monitor 依赖协议 | ✅ | `Monitor.swift` |
| 2.1 | 添加 `runner complete` 命令 | ✅ | `CLICommands.swift` |
| 2.2 | 修改 ScriptBuilder 使用回调 | ✅ | `ScriptBuilder.swift` |
| 2.3 | 添加 `completeRun` 到 RunRepository | ✅ | `Repositories.swift` |
| 2.4 | 更新测试 | ✅ | `*Tests.swift` |
| 3.1 | 添加 GRDB 依赖 | ✅ | `Package.swift` |
| 3.2 | 创建数据库 schema | ✅ | `SQLiteStorage.swift` |
| 3.3 | 实现 SQLiteStorage | ✅ | `SQLiteStorage.swift` |
| 3.4 | 数据迁移脚本 | ✅ | `MigrationService.swift` |
| 3.5 | 集成测试 | ✅ | `SQLiteStorageTests.swift` |
| 4.1 | 切换系统到 SQLiteStorage | ✅ | `CommandWiring.swift` |

---

## 后续阶段：完整 SQLite 迁移

### 当前数据存储分布

迁移完成后的数据分布：

| 数据类型 | 当前存储 | 目标存储 | 状态 |
|---------|---------|---------|------|
| **Runs** | `runner.db` (runs 表) | SQLite | ✅ 已完成 |
| **Tasks** | `tasks.json` | SQLite (tasks 表) | ⏳ Phase 5 |
| **Schedules** | `schedules.json` | SQLite (schedules 表) | ⏳ Phase 5 |
| **State** | `state.json` | SQLite (state 表) | ⏳ Phase 6 |
| **Output logs** | `runs/{id}.output` | 文件系统 | ✅ 保持不变 |

### 完整数据库 Schema 设计

```sql
-- ============================================
-- 已完成: runs 表 (Phase 3)
-- ============================================
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

CREATE INDEX idx_runs_task ON runs(task);
CREATE INDEX idx_runs_started_at ON runs(started_at DESC);
CREATE INDEX idx_runs_exit_code ON runs(exit_code);

-- ============================================
-- Phase 5: tasks 表
-- ============================================
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    executor TEXT NOT NULL CHECK (executor IN ('shell', 'opencode', 'http')),
    description TEXT NOT NULL,
    timeout INTEGER,
    -- Shell executor
    command TEXT,
    -- Opencode executor
    prompt TEXT,
    workdir TEXT,
    -- HTTP executor
    url TEXT,
    method TEXT,
    headers TEXT,  -- JSON string for headers map
    body TEXT,
    -- Metadata
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- Phase 5: schedules 表
-- ============================================
CREATE TABLE schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    hour TEXT NOT NULL,      -- "*" or "0-23"
    minute TEXT NOT NULL,    -- "*" or "0-59"
    weekday TEXT NOT NULL,   -- "*" or "0-6" (0=Sunday)
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_schedules_task ON schedules(task);
CREATE INDEX idx_schedules_enabled ON schedules(enabled) WHERE enabled = 1;

-- ============================================
-- Phase 6: state 表 (key-value store)
-- ============================================
CREATE TABLE state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Predefined keys:
-- 'version'          -> "1.0.0"
-- 'last_run'         -> JSON: {"id": "...", "task": "...", "exit_code": 0, "finished_at": "..."}
-- 'total_runs_today' -> "15"
-- 'success_rate_today' -> "1.00"
```

### Phase 5: Tasks 与 Schedules 迁移

**目标**：将 `tasks.json` 和 `schedules.json` 迁移到 SQLite。

#### 5.1 添加数据库 migration

```swift
// SQLiteStorage.swift - 新增 migration
migrator.registerMigration("v2_create_tasks_schedules") { db in
    try db.create(table: "tasks") { t in
        t.column("id", .text).primaryKey()
        t.column("executor", .text).notNull()
        t.column("description", .text).notNull()
        t.column("timeout", .integer)
        t.column("command", .text)
        t.column("prompt", .text)
        t.column("workdir", .text)
        t.column("url", .text)
        t.column("method", .text)
        t.column("headers", .text)
        t.column("body", .text)
        t.column("enabled", .integer).notNull().defaults(to: 1)
        t.column("created_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
        t.column("updated_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
    }
    
    try db.create(table: "schedules") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("task", .text).notNull().references("tasks", onDelete: .cascade)
        t.column("hour", .text).notNull()
        t.column("minute", .text).notNull()
        t.column("weekday", .text).notNull()
        t.column("enabled", .integer).notNull().defaults(to: 1)
        t.column("created_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
    }
    
    try db.create(index: "idx_schedules_task", on: "schedules", columns: ["task"])
}
```

#### 5.2 添加 TaskRecord 和 ScheduleRecord

```swift
struct TaskRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tasks"
    
    var id: String
    var executor: String
    var description: String
    var timeout: Int?
    var command: String?
    var prompt: String?
    var workdir: String?
    var url: String?
    var method: String?
    var headers: String?  // JSON encoded
    var body: String?
    var enabled: Bool
    var createdAt: String?
    var updatedAt: String?
}

struct ScheduleRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "schedules"
    
    var id: Int64?
    var task: String
    var hour: String
    var minute: String
    var weekday: String
    var enabled: Bool
    var createdAt: String?
}
```

#### 5.3 实现 ConfigRepository 的 SQLite 版本

修改 `SQLiteStorage` 从 SQLite 读取 tasks 和 schedules：

```swift
extension SQLiteStorage: ConfigRepository {
    public func loadTasks() async throws -> [Task] {
        try await dbQueue.read { db in
            let records = try TaskRecord.filter(Column("enabled") == true).fetchAll(db)
            return records.map { $0.toModel() }
        }
    }
    
    public func loadSchedules() async throws -> [Schedule] {
        try await dbQueue.read { db in
            let records = try ScheduleRecord.filter(Column("enabled") == true).fetchAll(db)
            return records.map { $0.toModel() }
        }
    }
}
```

#### 5.4 数据迁移

```swift
// MigrationService.swift - 新增方法
public func migrateConfigToSQLite() async throws {
    let jsonStorage = Storage(dataDir: dataDir)
    
    // Migrate tasks
    let tasks = try await jsonStorage.loadTasks()
    for task in tasks {
        try await sqliteStorage.saveTask(task)
    }
    
    // Migrate schedules
    let schedules = try await jsonStorage.loadSchedules()
    for schedule in schedules {
        try await sqliteStorage.addSchedule(schedule)
    }
    
    print("Config migration complete: \(tasks.count) tasks, \(schedules.count) schedules")
}
```

#### 5.5 添加 CLI 命令

```bash
# 迁移配置
./runner migrate --config

# 管理 tasks (未来功能)
./runner task add <id> --executor shell --command "..."
./runner task list
./runner task disable <id>

# 管理 schedules (未来功能)
./runner schedule add <task> --hour 9 --minute 0
./runner schedule list
./runner schedule remove <id>
```

### Phase 6: State 迁移

**目标**：将 `state.json` 迁移到 SQLite key-value store。

#### 6.1 添加 state 表 migration

```swift
migrator.registerMigration("v3_create_state") { db in
    try db.create(table: "state") { t in
        t.column("key", .text).primaryKey()
        t.column("value", .text).notNull()
        t.column("updated_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
    }
}
```

#### 6.2 StateRepository 协议

```swift
public protocol StateRepository: Sendable {
    func getValue(key: String) async throws -> String?
    func setValue(key: String, value: String) async throws
    func getState() async throws -> SystemState
    func updateLastRun(_ run: LastRun) async throws
}
```

#### 6.3 计算型状态

`total_runs_today` 和 `success_rate_today` 可以直接从 runs 表计算，不需要单独存储：

```swift
public func getStats() async throws -> (totalToday: Int, successRate: Double) {
    try await dbQueue.read { db in
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        
        let total = try Run
            .filter(Column("started_at") >= today)
            .fetchCount(db)
        
        let success = try Run
            .filter(Column("started_at") >= today)
            .filter(Column("exit_code") == 0)
            .fetchCount(db)
        
        let rate = total > 0 ? Double(success) / Double(total) : 1.0
        return (total, rate)
    }
}
```

### Phase 7: Dashboard 适配

**目标**：Dashboard 通过 runner CLI 读取所有数据。

#### 7.1 添加 `runner api run <id>` 命令

```swift
// ApiService.swift
public enum ApiQuery: Sendable {
    case tasks
    case schedules
    case runs
    case run(id: String)  // 新增
    case status
    case state
    case initialize
}
```

#### 7.2 修改 Dashboard vite-plugin-api.ts

```typescript
// GET /api/runs - 使用 runner CLI
if (url === "/api/runs" && req.method === "GET") {
    const { stdout } = await execPromise(`${RUNNER_BINARY} api runs`);
    res.end(stdout);
    return;
}

// GET /api/runs/:id - 使用 runner CLI
const runMatch = url.match(/^\/api\/runs\/([a-fA-F0-9-]{36})$/i);
if (runMatch && req.method === "GET") {
    const id = runMatch[1];
    const { stdout } = await execPromise(`${RUNNER_BINARY} api run ${id}`);
    res.end(stdout);
    return;
}
```

### Phase 8: 清理

#### 8.1 移除遗留文件

- 删除 `data/runs/index.json`
- 删除 `data/runs/*.json` (保留 `*.output`)
- 可选：备份后删除 `tasks.json`, `schedules.json`, `state.json`

#### 8.2 移除遗留代码

- 删除 `Storage.swift` 中的 JSON 相关方法
- 删除 `withFileLock` 等锁机制
- 简化 `CommandWiring.swift`

---

## 执行优先级

| 阶段 | 优先级 | 复杂度 | 依赖 | 说明 |
|------|--------|--------|------|------|
| Phase 5 | 中 | 中 | - | Tasks/Schedules 迁移，为未来 CRUD 打基础 |
| Phase 6 | 低 | 低 | Phase 5 | State 可以从 runs 表计算，不急 |
| Phase 7 | **高** | 低 | - | Dashboard 还在读 JSON！需要先修复 |
| Phase 8 | 低 | 低 | Phase 5-7 | 最后清理 |

**建议执行顺序**：Phase 7 → Phase 5 → Phase 6 → Phase 8

Phase 7 是最紧急的，因为 Dashboard 目前还在读取过时的 JSON 文件。

---

## 最终数据存储分布

迁移全部完成后：

```
data/
├── runner.db           # SQLite 数据库
│   ├── runs            # 运行记录
│   ├── tasks           # 任务定义
│   ├── schedules       # 调度规则
│   └── state           # 系统状态 (key-value)
│
└── runs/
    └── {id}.output     # 执行日志 (保持文件系统)
```

**设计决策**：
- **Log 文件保持在文件系统**：便于 tail/grep，不适合存数据库
- **配置数据进入 SQLite**：支持事务、约束、未来 CRUD 操作
- **单一真相来源**：所有结构化数据都在 `runner.db`

---

## 验收标准

1. ✅ 每个阶段完成后所有现有测试通过
2. ✅ 上层行为不变（Dashboard、CLI）
3. ✅ 单一写入点：只有 Swift 写入存储
4. ✅ SQLite 迁移完成，数据无丢失
5. ✅ 并发访问不再导致损坏
6. ✅ 大数据量查询性能提升
7. ⏳ Dashboard 从 SQLite 读取数据
8. ⏳ Tasks/Schedules 支持 CRUD 操作

## 参考

- 当前 Storage: `Sources/RunnerLib/Storage.swift`
- 当前 ScriptBuilder: `Sources/RunnerLib/ScriptBuilder.swift`
- Repository 协议: `Sources/RunnerLib/Repositories.swift`
- SQLite 存储: `Sources/RunnerLib/SQLiteStorage.swift`
- GRDB 文档: https://github.com/groue/GRDB.swift
