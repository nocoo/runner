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

## 任务分解

| ID | 任务 | 状态 | 文件 |
|----|------|------|------|
| 1.1 | 创建 `RunRepository` 协议 | ✅ | `Repositories.swift` |
| 1.2 | 创建 `ConfigRepository` 协议 | ✅ | `Repositories.swift` |
| 1.3 | Storage 实现协议 | ✅ | `Storage.swift` |
| 1.4 | Executor 依赖协议 | ✅ | `Executor.swift` |
| 1.5 | Monitor 依赖协议 | ✅ | `Monitor.swift` |
| 2.1 | 添加 `runner complete` 命令 | ⏳ | `CLICommands.swift` |
| 2.2 | 修改 ScriptBuilder 使用回调 | ⏳ | `ScriptBuilder.swift` |
| 2.3 | 添加 `completeRun` 到 RunRepository | ⏳ | `Repositories.swift` |
| 2.4 | 更新测试 | ⏳ | `*Tests.swift` |
| 3.1 | 添加 GRDB 依赖 | ⏳ | `Package.swift` |
| 3.2 | 创建数据库 schema | ⏳ | `SQLiteStorage.swift` |
| 3.3 | 实现 SQLiteStorage | ⏳ | `SQLiteStorage.swift` |
| 3.4 | 数据迁移脚本 | ⏳ | `MigrationService.swift` |
| 3.5 | 集成测试 | ⏳ | `SQLiteStorageTests.swift` |
| 4.1 | 移除遗留 JSON 代码 | ⏳ | 多个文件 |
| 4.2 | 更新文档 | ⏳ | `docs/` |

## 验收标准

1. ✅ 每个阶段完成后所有现有测试通过
2. ✅ 上层行为不变（Dashboard、CLI）
3. ⏳ 单一写入点：只有 Swift 写入存储
4. ⏳ SQLite 迁移完成，数据无丢失
5. ⏳ 并发访问不再导致损坏
6. ⏳ 大数据量查询性能提升

## 参考

- 当前 Storage: `Sources/RunnerLib/Storage.swift`
- 当前 ScriptBuilder: `Sources/RunnerLib/ScriptBuilder.swift`
- Repository 协议: `Sources/RunnerLib/Repositories.swift`
- GRDB 文档: https://github.com/groue/GRDB.swift
