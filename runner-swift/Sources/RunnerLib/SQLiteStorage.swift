import Foundation
import GRDB

// MARK: - Database Record Types

/// Database record for runs table
struct RunRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "runs"
    
    var id: String
    var task: String
    var trigger: String
    var startedAt: String
    var finishedAt: String?
    var durationSeconds: Int?
    var exitCode: Int?
    var pid: Int?
    var startedAtEpoch: Int64
    var createdAt: String?
    
    // Map Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id, task, trigger, pid
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationSeconds = "duration_seconds"
        case exitCode = "exit_code"
        case startedAtEpoch = "started_at_epoch"
        case createdAt = "created_at"
    }
    
    // Convert from RunSummary
    init(from summary: RunSummary) {
        self.id = summary.id
        self.task = summary.task
        self.trigger = summary.trigger ?? "manual"
        self.startedAt = summary.startedAt
        self.finishedAt = summary.finishedAt
        self.durationSeconds = nil
        self.exitCode = summary.exitCode
        self.pid = summary.pid
        self.startedAtEpoch = summary.startedAtEpoch ?? Int64(Date().timeIntervalSince1970)
        self.createdAt = nil
    }
    
    // Convert to RunSummary
    func toSummary() -> RunSummary {
        RunSummary(
            id: id,
            task: task,
            trigger: trigger,
            exitCode: exitCode,
            startedAt: startedAt,
            finishedAt: finishedAt,
            pid: pid,
            startedAtEpoch: startedAtEpoch
        )
    }
    
    // Convert to RunDetail
    func toDetail() -> RunDetail {
        RunDetail(
            id: id,
            task: task,
            trigger: trigger,
            startedAt: startedAt,
            finishedAt: finishedAt,
            durationSeconds: durationSeconds,
            exitCode: exitCode ?? -1
        )
    }
}

// MARK: - TaskRecord

/// Database record for tasks table
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
    
    enum CodingKeys: String, CodingKey {
        case id, executor, description, timeout, command, prompt, workdir, url, method, headers, body, enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from task: Task, enabled: Bool = true) {
        self.id = task.id
        self.executor = task.executor.rawValue
        self.description = task.description
        self.timeout = task.timeout
        self.command = task.command
        self.prompt = task.prompt
        self.workdir = task.workdir
        self.url = task.url
        self.method = task.method
        self.body = task.body
        self.enabled = enabled
        self.createdAt = nil
        self.updatedAt = nil
        
        // Encode headers as JSON
        if let headers = task.headers {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            if let data = try? encoder.encode(headers) {
                self.headers = String(data: data, encoding: .utf8)
            } else {
                self.headers = nil
            }
        } else {
            self.headers = nil
        }
    }
    
    func toModel() -> Task {
        var decodedHeaders: [String: String]?
        if let headersJson = headers, let data = headersJson.data(using: .utf8) {
            decodedHeaders = try? JSONDecoder().decode([String: String].self, from: data)
        }
        
        return Task(
            id: id,
            executor: TaskExecutor(rawValue: executor) ?? .shell,
            description: description,
            timeout: timeout,
            command: command,
            prompt: prompt,
            workdir: workdir,
            url: url,
            method: method,
            headers: decodedHeaders,
            body: body
        )
    }
}

// MARK: - ScheduleRecord

/// Database record for schedules table
struct ScheduleRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "schedules"
    
    var id: Int64?
    var task: String
    var hour: String
    var minute: String
    var weekday: String
    var enabled: Bool
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, task, hour, minute, weekday, enabled
        case createdAt = "created_at"
    }
    
    init(from schedule: Schedule, enabled: Bool = true) {
        self.id = nil
        self.task = schedule.task
        self.hour = Self.encodeValue(schedule.hour)
        self.minute = Self.encodeValue(schedule.minute)
        self.weekday = Self.encodeValue(schedule.weekday)
        self.enabled = enabled
        self.createdAt = nil
    }
    
    private static func encodeValue(_ value: AnyCodable) -> String {
        if let intValue = value.value as? Int {
            return String(intValue)
        } else if let strValue = value.value as? String {
            return strValue
        }
        return "*"
    }
    
    func toModel() -> Schedule {
        Schedule(
            task: task,
            hour: Self.decodeValue(hour),
            minute: Self.decodeValue(minute),
            weekday: Self.decodeValue(weekday)
        )
    }
    
    private static func decodeValue(_ str: String) -> AnyCodable {
        if str == "*" {
            return AnyCodable("*")
        } else if let intValue = Int(str) {
            return AnyCodable(intValue)
        }
        return AnyCodable(str)
    }
}

// MARK: - StateRecord

/// Database record for state table (key-value store)
struct StateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "state"
    
    var key: String
    var value: String
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case key, value
        case updatedAt = "updated_at"
    }
}

// MARK: - Database Migrator

extension DatabaseMigrator {
    /// Configure database migrations
    static func runnerMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Version 1: Initial schema
        migrator.registerMigration("v1_create_runs") { db in
            try db.create(table: "runs") { t in
                t.column("id", .text).primaryKey()
                t.column("task", .text).notNull()
                t.column("trigger", .text).notNull()
                t.column("started_at", .text).notNull()
                t.column("finished_at", .text)
                t.column("duration_seconds", .integer)
                t.column("exit_code", .integer)
                t.column("pid", .integer)
                t.column("started_at_epoch", .integer).notNull()
                t.column("created_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
            }
            
            // Indexes for common queries
            try db.create(index: "idx_runs_task", on: "runs", columns: ["task"])
            try db.create(index: "idx_runs_started_at", on: "runs", columns: ["started_at"])
            try db.create(index: "idx_runs_exit_code", on: "runs", columns: ["exit_code"])
        }
        
        // Version 2: Tasks and schedules tables
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
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("created_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updated_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
            }
            
            try db.create(table: "schedules") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("task", .text).notNull()
                t.column("hour", .text).notNull()
                t.column("minute", .text).notNull()
                t.column("weekday", .text).notNull()
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("created_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
            }
            
            try db.create(index: "idx_schedules_task", on: "schedules", columns: ["task"])
        }
        
        // Version 3: State table (key-value store)
        migrator.registerMigration("v3_create_state") { db in
            try db.create(table: "state") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
                t.column("updated_at", .text).defaults(sql: "CURRENT_TIMESTAMP")
            }
        }
        
        return migrator
    }
}

// MARK: - SQLite Storage Actor

/// SQLite-based storage implementation
public actor SQLiteStorage {
    private let dbQueue: DatabaseQueue
    public let dataDir: URL
    
    /// Initialize SQLite storage
    /// - Parameter dataDir: Directory for data files (database + output files)
    public init(dataDir: URL) throws {
        self.dataDir = dataDir
        
        // Ensure data directory exists
        let runsDir = dataDir.appendingPathComponent("runs")
        try FileManager.default.createDirectory(at: runsDir, withIntermediateDirectories: true)
        
        // Open database
        let dbPath = dataDir.appendingPathComponent("runner.db").path
        self.dbQueue = try DatabaseQueue(path: dbPath)
        
        // Run migrations
        try DatabaseMigrator.runnerMigrator().migrate(dbQueue)
    }
    
    /// Initialize with in-memory database (for testing)
    public init(inMemory: Bool = true) throws {
        guard inMemory else {
            fatalError("Use init(dataDir:) for persistent storage")
        }
        self.dataDir = FileManager.default.temporaryDirectory
        self.dbQueue = try DatabaseQueue()
        try DatabaseMigrator.runnerMigrator().migrate(dbQueue)
    }
    
    // MARK: - Private Helpers
    
    private func outputPath(for id: String) -> URL {
        dataDir.appendingPathComponent("runs/\(id).output")
    }
}

// MARK: - RunRepository Implementation

extension SQLiteStorage: RunRepository {
    
    public func loadRunsIndex() async throws -> RunsIndex {
        try await dbQueue.read { db in
            let runs = try RunRecord
                .order(Column("started_at_epoch").desc)
                .fetchAll(db)
            
            return RunsIndex(
                runs: runs.map { $0.toSummary() },
                total: runs.count,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        }
    }
    
    public func addRun(_ run: RunSummary) async throws {
        try await dbQueue.write { db in
            try RunRecord(from: run).insert(db)
        }
    }
    
    public func updateRun(id: String, exitCode: Int?, finishedAt: String?) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE runs 
                    SET exit_code = ?, finished_at = ?, pid = NULL 
                    WHERE id = ?
                    """,
                arguments: [exitCode, finishedAt, id]
            )
        }
    }
    
    public func markInterrupted(id: String) async throws {
        let finishedAt = ISO8601DateFormatter().string(from: Date())
        try await updateRun(id: id, exitCode: -1, finishedAt: finishedAt)
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
    
    public func getRunningTasks() async throws -> [RunSummary] {
        try await dbQueue.read { db in
            let runs = try RunRecord
                .filter(Column("exit_code") == nil && Column("pid") != nil)
                .fetchAll(db)
            return runs.map { $0.toSummary() }
        }
    }
    
    public func writeRunDetail(_ detail: RunDetail) async throws {
        // In SQLite, detail is part of the runs table
        // Just update the relevant fields
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE runs 
                    SET finished_at = ?, duration_seconds = ?, exit_code = ?
                    WHERE id = ?
                    """,
                arguments: [detail.finishedAt, detail.durationSeconds, detail.exitCode, detail.id]
            )
        }
    }
    
    public func loadRunDetail(id: String) async throws -> RunDetail? {
        try await dbQueue.read { db in
            guard let record = try RunRecord.fetchOne(db, key: id) else {
                return nil
            }
            // Only return detail if the run has completed (exitCode is set)
            guard record.exitCode != nil else {
                return nil
            }
            return record.toDetail()
        }
    }
    
    public func writeOutput(id: String, content: String) async throws {
        let path = outputPath(for: id)
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
    
    public func appendOutput(id: String, content: String) async throws {
        let path = outputPath(for: id)
        
        if FileManager.default.fileExists(atPath: path.path) {
            let handle = try FileHandle(forWritingTo: path)
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = content.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } else {
            try content.write(to: path, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - ConfigRepository Implementation

extension SQLiteStorage: ConfigRepository {
    
    public func initialize() async throws {
        // Create config directory if needed
        let configDir = dataDir
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        // Create default tasks.json if not exists
        let tasksPath = configDir.appendingPathComponent("tasks.json")
        if !FileManager.default.fileExists(atPath: tasksPath.path) {
            let defaultTasks: [[String: Any]] = [
                [
                    "id": "sample",
                    "executor": "shell",
                    "description": "Sample task",
                    "command": "echo 'Hello from runner!'"
                ]
            ]
            let data = try JSONSerialization.data(withJSONObject: defaultTasks, options: .prettyPrinted)
            try data.write(to: tasksPath)
        }
        
        // Create default schedules.json if not exists
        let schedulesPath = configDir.appendingPathComponent("schedules.json")
        if !FileManager.default.fileExists(atPath: schedulesPath.path) {
            let defaultSchedules: [[String: Any]] = []
            let data = try JSONSerialization.data(withJSONObject: defaultSchedules, options: .prettyPrinted)
            try data.write(to: schedulesPath)
        }
    }
    
    public func loadTasks() async throws -> [Task] {
        // First try SQLite
        let sqliteTasks = try await loadTasksFromSQLite()
        if !sqliteTasks.isEmpty {
            return sqliteTasks
        }
        
        // Fall back to JSON file
        let path = dataDir.appendingPathComponent("tasks.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([Task].self, from: data)
    }
    
    public func loadSchedules() async throws -> [Schedule] {
        // First try SQLite
        let sqliteSchedules = try await loadSchedulesFromSQLite()
        if !sqliteSchedules.isEmpty {
            return sqliteSchedules
        }
        
        // Fall back to JSON file
        let path = dataDir.appendingPathComponent("schedules.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([Schedule].self, from: data)
    }
}

// MARK: - Tasks SQLite Operations

extension SQLiteStorage {
    
    /// Load all enabled tasks from SQLite
    func loadTasksFromSQLite() async throws -> [Task] {
        try await dbQueue.read { db in
            let records = try TaskRecord
                .filter(Column("enabled") == true)
                .order(Column("id"))
                .fetchAll(db)
            return records.map { $0.toModel() }
        }
    }
    
    /// Save a task (insert or update)
    public func saveTask(_ task: Task) async throws {
        let record = TaskRecord(from: task)
        try await dbQueue.write { db in
            try record.save(db)
        }
    }
    
    /// Load a single task by ID
    public func loadTask(id: String) async throws -> Task? {
        try await dbQueue.read { db in
            guard let record = try TaskRecord.fetchOne(db, key: id) else {
                return nil
            }
            return record.toModel()
        }
    }
    
    /// Delete a task by ID
    public func deleteTask(id: String) async throws {
        try await dbQueue.write { db in
            try TaskRecord.deleteOne(db, key: id)
        }
    }
    
    /// Check if tasks are stored in SQLite
    public func hasTasksInSQLite() async throws -> Bool {
        try await dbQueue.read { db in
            let count = try TaskRecord.fetchCount(db)
            return count > 0
        }
    }
}

// MARK: - Schedules SQLite Operations

extension SQLiteStorage {
    
    /// Load all enabled schedules from SQLite
    func loadSchedulesFromSQLite() async throws -> [Schedule] {
        try await dbQueue.read { db in
            let records = try ScheduleRecord
                .filter(Column("enabled") == true)
                .order(Column("task"), Column("hour"), Column("minute"))
                .fetchAll(db)
            return records.map { $0.toModel() }
        }
    }
    
    /// Add a schedule
    public func addSchedule(_ schedule: Schedule) async throws {
        let record = ScheduleRecord(from: schedule)
        try await dbQueue.write { db in
            try record.insert(db)
        }
    }
    
    /// Delete all schedules for a task
    public func deleteSchedulesForTask(id: String) async throws {
        try await dbQueue.write { db in
            try ScheduleRecord
                .filter(Column("task") == id)
                .deleteAll(db)
        }
    }
    
    /// Check if schedules are stored in SQLite
    public func hasSchedulesInSQLite() async throws -> Bool {
        try await dbQueue.read { db in
            let count = try ScheduleRecord.fetchCount(db)
            return count > 0
        }
    }
}

// MARK: - State SQLite Operations

extension SQLiteStorage {
    
    /// State keys used in the key-value store
    public enum StateKey: String, Sendable {
        case version = "version"
        case lastRunId = "last_run_id"
        case lastRunTask = "last_run_task"
        case lastRunExitCode = "last_run_exit_code"
        case lastRunFinishedAt = "last_run_finished_at"
        case totalRunsToday = "total_runs_today"
        case successRateToday = "success_rate_today"
    }
    
    /// Get a state value by key
    public func getStateValue(key: StateKey) async throws -> String? {
        let keyString = key.rawValue
        return try await dbQueue.read { db in
            try StateRecord.fetchOne(db, key: keyString)?.value
        }
    }
    
    /// Set a state value
    public func setStateValue(key: StateKey, value: String) async throws {
        let keyString = key.rawValue
        try await dbQueue.write { db in
            let record = StateRecord(key: keyString, value: value, updatedAt: nil)
            try record.save(db)
        }
    }
    
    /// Load SystemState from SQLite
    public func loadState() async throws -> SystemState {
        try await dbQueue.read { db in
            let version = try StateRecord.fetchOne(db, key: StateKey.version.rawValue)?.value ?? "1.0.0"
            let totalRunsToday = try StateRecord.fetchOne(db, key: StateKey.totalRunsToday.rawValue)?.value ?? "0"
            let successRateToday = try StateRecord.fetchOne(db, key: StateKey.successRateToday.rawValue)?.value ?? "0.0"
            
            // Reconstruct LastRun if all parts exist
            var lastRun: LastRun? = nil
            if let lastRunId = try StateRecord.fetchOne(db, key: StateKey.lastRunId.rawValue)?.value,
               let lastRunTask = try StateRecord.fetchOne(db, key: StateKey.lastRunTask.rawValue)?.value,
               let lastRunExitCode = try StateRecord.fetchOne(db, key: StateKey.lastRunExitCode.rawValue)?.value,
               let lastRunFinishedAt = try StateRecord.fetchOne(db, key: StateKey.lastRunFinishedAt.rawValue)?.value,
               let exitCode = Int(lastRunExitCode) {
                lastRun = LastRun(id: lastRunId, task: lastRunTask, exitCode: exitCode, finishedAt: lastRunFinishedAt)
            }
            
            return SystemState(
                version: version,
                lastRun: lastRun,
                totalRunsToday: Int(totalRunsToday) ?? 0,
                successRateToday: Double(successRateToday) ?? 0.0
            )
        }
    }
    
    /// Save SystemState to SQLite
    public func saveState(_ state: SystemState) async throws {
        try await dbQueue.write { db in
            try StateRecord(key: StateKey.version.rawValue, value: state.version, updatedAt: nil).save(db)
            try StateRecord(key: StateKey.totalRunsToday.rawValue, value: String(state.totalRunsToday), updatedAt: nil).save(db)
            try StateRecord(key: StateKey.successRateToday.rawValue, value: String(state.successRateToday), updatedAt: nil).save(db)
            
            if let lastRun = state.lastRun {
                try StateRecord(key: StateKey.lastRunId.rawValue, value: lastRun.id, updatedAt: nil).save(db)
                try StateRecord(key: StateKey.lastRunTask.rawValue, value: lastRun.task, updatedAt: nil).save(db)
                try StateRecord(key: StateKey.lastRunExitCode.rawValue, value: String(lastRun.exitCode), updatedAt: nil).save(db)
                try StateRecord(key: StateKey.lastRunFinishedAt.rawValue, value: lastRun.finishedAt, updatedAt: nil).save(db)
            }
        }
    }
    
    /// Check if state is stored in SQLite
    public func hasStateInSQLite() async throws -> Bool {
        try await dbQueue.read { db in
            let count = try StateRecord.fetchCount(db)
            return count > 0
        }
    }
}

// MARK: - Additional Protocol Conformances

// SQLiteStorage already has loadTasks() and loadSchedules() from ConfigRepository,
// so we just declare conformance to the service-specific protocols
extension SQLiteStorage: TaskLoading {}
extension SQLiteStorage: TasksLoading {}
extension SQLiteStorage: SchedulesLoading {}
extension SQLiteStorage: Initializing {}
extension SQLiteStorage: RunsIndexLoading {}
extension SQLiteStorage: RunDetailLoading {}

// MARK: - SQLiteStateLoader

/// StateLoading implementation that reads from SQLite
public struct SQLiteStateLoader: StateLoading {
    private let storage: SQLiteStorage
    private let encoder: JSONEncoder
    
    public init(storage: SQLiteStorage) {
        self.storage = storage
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }
    
    /// Read state data from SQLite and return as JSON Data
    public func readStateData() async throws -> Data {
        let state = try await storage.loadState()
        return try encoder.encode(state)
    }
}
