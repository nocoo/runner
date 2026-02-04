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
        
        return migrator
    }
}

// MARK: - SQLite Storage Actor

/// SQLite-based storage implementation
public actor SQLiteStorage {
    private let dbQueue: DatabaseQueue
    private let dataDir: URL
    
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
        let path = dataDir.appendingPathComponent("tasks.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([Task].self, from: data)
    }
    
    public func loadSchedules() async throws -> [Schedule] {
        let path = dataDir.appendingPathComponent("schedules.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([Schedule].self, from: data)
    }
}
