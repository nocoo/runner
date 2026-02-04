import Testing
import Foundation
@testable import RunnerLib

// MARK: - MigrationService Tests

@Suite("MigrationService Tests")
struct MigrationServiceTests {
    
    /// Create a temp directory for testing
    private func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-migration-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// Clean up temp directory
    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
    
    @Test("Migration from empty JSON storage succeeds")
    func migrateEmptyStorage() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        
        let sqliteStorage = try SQLiteStorage(dataDir: tempDir)
        
        let result = try await MigrationService.migrate(from: jsonStorage, to: sqliteStorage)
        
        #expect(result.success)
        #expect(result.runsCount == 0)
        #expect(result.errors.isEmpty)
    }
    
    @Test("Migration preserves run data")
    func migratePreservesData() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        // Setup JSON storage with some runs
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        
        let run1 = RunSummary(
            id: "run-1",
            task: "heartbeat",
            trigger: "auto",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:05Z",
            pid: nil,
            startedAtEpoch: 1737795600
        )
        let run2 = RunSummary(
            id: "run-2",
            task: "backup",
            trigger: "manual",
            exitCode: 1,
            startedAt: "2026-01-25T09:00:00Z",
            finishedAt: "2026-01-25T09:00:30Z",
            pid: nil,
            startedAtEpoch: 1737799200
        )
        
        try await jsonStorage.addRun(run1)
        try await jsonStorage.addRun(run2)
        
        // Perform migration
        let sqliteStorage = try SQLiteStorage(dataDir: tempDir)
        let result = try await MigrationService.migrate(from: jsonStorage, to: sqliteStorage)
        
        #expect(result.success)
        #expect(result.runsCount == 2)
        
        // Verify data in SQLite
        let index = try await sqliteStorage.loadRunsIndex()
        #expect(index.runs.count == 2)
        
        // Check run1 (should be second due to descending order by epoch)
        let migratedRun1 = index.runs.first { $0.id == "run-1" }
        #expect(migratedRun1 != nil)
        #expect(migratedRun1?.task == "heartbeat")
        #expect(migratedRun1?.trigger == "auto")
        #expect(migratedRun1?.exitCode == 0)
        
        // Check run2
        let migratedRun2 = index.runs.first { $0.id == "run-2" }
        #expect(migratedRun2 != nil)
        #expect(migratedRun2?.task == "backup")
        #expect(migratedRun2?.trigger == "manual")
        #expect(migratedRun2?.exitCode == 1)
    }
    
    @Test("jsonIndexExists returns false for missing file")
    func jsonIndexExistsFalse() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        
        #expect(!MigrationService.jsonIndexExists(in: tempDir))
    }
    
    @Test("jsonIndexExists returns true for existing file")
    func jsonIndexExistsTrue() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let runsDir = tempDir.appendingPathComponent("runs")
        try FileManager.default.createDirectory(at: runsDir, withIntermediateDirectories: true)
        try "{}".write(to: runsDir.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
        
        #expect(MigrationService.jsonIndexExists(in: tempDir))
    }
    
    @Test("sqliteExists returns false for missing file")
    func sqliteExistsFalse() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        
        #expect(!MigrationService.sqliteExists(in: tempDir))
    }
    
    @Test("sqliteExists returns true after SQLiteStorage init")
    func sqliteExistsTrue() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        _ = try SQLiteStorage(dataDir: tempDir)
        
        #expect(MigrationService.sqliteExists(in: tempDir))
    }
}

// MARK: - Migrate Command Tests

@Suite("Migrate Command Tests")
struct MigrateCommandTests {
    
    private func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-migrate-cmd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
    
    @Test("Migrate command reports no data when JSON missing")
    func migrateNoData() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        var options = CommonOptions()
        options.dataDir = tempDir
        
        let result = try await migrateCommand(options: options, force: false)
        
        #expect(result.success)
        #expect(result.lines.contains { $0.contains("No JSON data found") })
    }
    
    @Test("Migrate command refuses without force when db exists")
    func migrateRefusesWithoutForce() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        // Create both JSON and SQLite
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        try await jsonStorage.addRun(RunSummary(
            id: "test-1",
            task: "test",
            trigger: "auto",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: 1737795600
        ))
        
        _ = try SQLiteStorage(dataDir: tempDir)
        
        var options = CommonOptions()
        options.dataDir = tempDir
        
        let result = try await migrateCommand(options: options, force: false)
        
        #expect(!result.success)
        #expect(result.lines.contains { $0.contains("already exists") })
    }
    
    @Test("Migrate command succeeds with data")
    func migrateSucceeds() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        // Setup JSON data
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        try await jsonStorage.addRun(RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: "auto",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: 1737795600
        ))
        
        var options = CommonOptions()
        options.dataDir = tempDir
        
        let result = try await migrateCommand(options: options, force: false)
        
        #expect(result.success)
        #expect(result.lines.contains { $0.contains("Migrated 1 runs") })
        #expect(result.lines.contains { $0.contains("successfully") })
    }
    
    @Test("Migrate --config reports no data when config files missing")
    func migrateConfigNoData() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        var options = CommonOptions()
        options.dataDir = tempDir
        
        let result = try await migrateCommand(options: options, force: false, config: true)
        
        #expect(result.success)
        #expect(result.lines.contains { $0.contains("No config files found") })
    }
    
    @Test("Migrate --config succeeds with data")
    func migrateConfigSucceeds() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        // Write tasks.json
        let tasks = [
            Task(
                id: "test-task",
                executor: .shell,
                description: "Test task",
                command: "echo test"
            )
        ]
        let encoder = JSONEncoder()
        let tasksData = try encoder.encode(tasks)
        try tasksData.write(to: tempDir.appendingPathComponent("tasks.json"))
        
        var options = CommonOptions()
        options.dataDir = tempDir
        
        let result = try await migrateCommand(options: options, force: false, config: true)
        
        #expect(result.success)
        #expect(result.lines.contains { $0.contains("Migrated 1 tasks") })
        #expect(result.lines.contains { $0.contains("successfully") })
    }
}

// MARK: - Config Migration Tests

@Suite("Config Migration Tests")
struct ConfigMigrationTests {
    
    private func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-config-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
    
    @Test("Config migration from empty storage succeeds")
    func migrateEmptyConfig() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        
        let sqliteStorage = try SQLiteStorage(dataDir: tempDir)
        
        let result = try await MigrationService.migrateConfigToSQLite(from: jsonStorage, to: sqliteStorage)
        
        #expect(result.success)
        #expect(result.tasksCount == 0)
        #expect(result.schedulesCount == 0)
        #expect(result.errors.isEmpty)
    }
    
    @Test("Config migration preserves task data")
    func migratePreservesTaskData() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        // Setup JSON storage with tasks by writing JSON file directly
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        
        let tasks = [
            Task(
                id: "heartbeat",
                executor: .shell,
                description: "Heartbeat check",
                timeout: 30,
                command: "echo 'alive'"
            ),
            Task(
                id: "backup",
                executor: .opencode,
                description: "Run backup",
                prompt: "Backup the database"
            )
        ]
        
        // Write tasks.json directly
        let tasksPath = tempDir.appendingPathComponent("tasks.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let tasksData = try encoder.encode(tasks)
        try tasksData.write(to: tasksPath)
        
        // Perform migration
        let sqliteStorage = try SQLiteStorage(dataDir: tempDir)
        let result = try await MigrationService.migrateConfigToSQLite(from: jsonStorage, to: sqliteStorage)
        
        #expect(result.success)
        #expect(result.tasksCount == 2)
        
        // Verify data in SQLite
        let migratedTask1 = try await sqliteStorage.loadTask(id: "heartbeat")
        #expect(migratedTask1 != nil)
        #expect(migratedTask1?.executor == .shell)
        #expect(migratedTask1?.description == "Heartbeat check")
        #expect(migratedTask1?.command == "echo 'alive'")
        
        let migratedTask2 = try await sqliteStorage.loadTask(id: "backup")
        #expect(migratedTask2 != nil)
        #expect(migratedTask2?.executor == .opencode)
        #expect(migratedTask2?.prompt == "Backup the database")
    }
    
    @Test("Config migration preserves schedule data")
    func migratePreservesScheduleData() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }
        
        // Setup JSON storage
        let jsonStorage = Storage(dataDir: tempDir)
        try await jsonStorage.initialize()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        // Write tasks.json directly
        let tasks = [
            Task(
                id: "heartbeat",
                executor: .shell,
                description: "Heartbeat check",
                command: "echo 'alive'"
            )
        ]
        let tasksPath = tempDir.appendingPathComponent("tasks.json")
        let tasksData = try encoder.encode(tasks)
        try tasksData.write(to: tasksPath)
        
        // Write schedules.json directly
        let schedules = [
            Schedule(task: "heartbeat", hour: AnyCodable("*"), minute: AnyCodable("0"), weekday: AnyCodable("*")),
            Schedule(task: "heartbeat", hour: AnyCodable("9"), minute: AnyCodable("30"), weekday: AnyCodable("1"))
        ]
        let schedulesPath = tempDir.appendingPathComponent("schedules.json")
        let schedulesData = try encoder.encode(schedules)
        try schedulesData.write(to: schedulesPath)
        
        // Perform migration
        let sqliteStorage = try SQLiteStorage(dataDir: tempDir)
        let result = try await MigrationService.migrateConfigToSQLite(from: jsonStorage, to: sqliteStorage)
        
        #expect(result.success)
        #expect(result.tasksCount == 1)
        #expect(result.schedulesCount == 2)
        
        // Verify schedules in SQLite
        let migratedSchedules = try await sqliteStorage.loadSchedulesFromSQLite()
        #expect(migratedSchedules.count == 2)
        
        // Check that we have both schedules (hour values)
        let hourValues = migratedSchedules.map { "\($0.hour.value)" }
        #expect(hourValues.contains("*"))
        #expect(hourValues.contains("9"))
    }
    
    @Test("tasksJsonExists returns false for missing file")
    func tasksJsonExistsFalse() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        
        #expect(!MigrationService.tasksJsonExists(in: tempDir))
    }
    
    @Test("schedulesJsonExists returns false for missing file")
    func schedulesJsonExistsFalse() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        
        #expect(!MigrationService.schedulesJsonExists(in: tempDir))
    }
}
