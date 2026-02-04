import Foundation

/// Service for migrating data from JSON storage to SQLite
public struct MigrationService: Sendable {
    
    /// Migration result
    public struct MigrationResult: Sendable {
        public let runsCount: Int
        public let errors: [String]
        
        public var success: Bool {
            errors.isEmpty
        }
    }
    
    /// Migrate data from JSON storage to SQLite storage
    /// - Parameters:
    ///   - jsonStorage: Source JSON storage
    ///   - sqliteStorage: Target SQLite storage
    /// - Returns: Migration result with counts and any errors
    public static func migrate(
        from jsonStorage: Storage,
        to sqliteStorage: SQLiteStorage
    ) async throws -> MigrationResult {
        var errors: [String] = []
        var runsCount = 0
        
        // Load existing runs from JSON
        let index: RunsIndex
        do {
            index = try await jsonStorage.loadRunsIndex()
        } catch {
            // If index doesn't exist, nothing to migrate
            return MigrationResult(runsCount: 0, errors: [])
        }
        
        // Migrate each run
        for run in index.runs {
            do {
                try await sqliteStorage.addRun(run)
                runsCount += 1
                
                // Try to load and migrate detail if exists
                if let detail = try await jsonStorage.loadRunDetail(id: run.id) {
                    try await sqliteStorage.writeRunDetail(detail)
                }
            } catch {
                errors.append("Failed to migrate run \(run.id): \(error.localizedDescription)")
            }
        }
        
        return MigrationResult(runsCount: runsCount, errors: errors)
    }
    
    /// Check if SQLite database exists
    public static func sqliteExists(in dataDir: URL) -> Bool {
        let dbPath = dataDir.appendingPathComponent("runner.db")
        return FileManager.default.fileExists(atPath: dbPath.path)
    }
    
    /// Check if JSON index exists
    public static func jsonIndexExists(in dataDir: URL) -> Bool {
        let indexPath = dataDir.appendingPathComponent("runs/index.json")
        return FileManager.default.fileExists(atPath: indexPath.path)
    }
    
    /// Config migration result
    public struct ConfigMigrationResult: Sendable {
        public let tasksCount: Int
        public let schedulesCount: Int
        public let errors: [String]
        
        public var success: Bool {
            errors.isEmpty
        }
    }
    
    /// Migrate tasks and schedules from JSON to SQLite
    /// - Parameters:
    ///   - jsonStorage: Source JSON storage (for tasks.json and schedules.json)
    ///   - sqliteStorage: Target SQLite storage
    /// - Returns: Migration result with counts and any errors
    public static func migrateConfigToSQLite(
        from jsonStorage: Storage,
        to sqliteStorage: SQLiteStorage
    ) async throws -> ConfigMigrationResult {
        var errors: [String] = []
        var tasksCount = 0
        var schedulesCount = 0
        
        // Load existing tasks from JSON
        let tasks: [Task]
        do {
            tasks = try await jsonStorage.loadTasks()
        } catch {
            tasks = []
        }
        
        // Migrate each task
        for task in tasks {
            do {
                try await sqliteStorage.saveTask(task)
                tasksCount += 1
            } catch {
                errors.append("Failed to migrate task \(task.id): \(error.localizedDescription)")
            }
        }
        
        // Load existing schedules from JSON
        let schedules: [Schedule]
        do {
            schedules = try await jsonStorage.loadSchedules()
        } catch {
            schedules = []
        }
        
        // Migrate each schedule
        for schedule in schedules {
            do {
                try await sqliteStorage.addSchedule(schedule)
                schedulesCount += 1
            } catch {
                errors.append("Failed to migrate schedule for task \(schedule.task): \(error.localizedDescription)")
            }
        }
        
        return ConfigMigrationResult(
            tasksCount: tasksCount,
            schedulesCount: schedulesCount,
            errors: errors
        )
    }
    
    /// Check if tasks.json exists
    public static func tasksJsonExists(in configDir: URL) -> Bool {
        let tasksPath = configDir.appendingPathComponent("tasks.json")
        return FileManager.default.fileExists(atPath: tasksPath.path)
    }
    
    /// Check if schedules.json exists
    public static func schedulesJsonExists(in configDir: URL) -> Bool {
        let schedulesPath = configDir.appendingPathComponent("schedules.json")
        return FileManager.default.fileExists(atPath: schedulesPath.path)
    }
    
    /// State migration result
    public struct StateMigrationResult: Sendable {
        public let migrated: Bool
        public let errors: [String]
        
        public var success: Bool {
            errors.isEmpty
        }
    }
    
    /// Migrate state.json to SQLite
    /// - Parameters:
    ///   - dataDir: Directory containing state.json
    ///   - sqliteStorage: Target SQLite storage
    /// - Returns: Migration result
    public static func migrateStateToSQLite(
        from dataDir: URL,
        to sqliteStorage: SQLiteStorage
    ) async throws -> StateMigrationResult {
        var errors: [String] = []
        
        let statePath = dataDir.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: statePath.path) else {
            return StateMigrationResult(migrated: false, errors: ["state.json not found"])
        }
        
        // Read and parse state.json
        let data: Data
        let state: SystemState
        do {
            data = try Data(contentsOf: statePath)
            state = try JSONDecoder().decode(SystemState.self, from: data)
        } catch {
            return StateMigrationResult(migrated: false, errors: ["Failed to read state.json: \(error.localizedDescription)"])
        }
        
        // Save to SQLite
        do {
            try await sqliteStorage.saveState(state)
        } catch {
            errors.append("Failed to save state to SQLite: \(error.localizedDescription)")
        }
        
        return StateMigrationResult(migrated: errors.isEmpty, errors: errors)
    }
    
    /// Check if state.json exists
    public static func stateJsonExists(in dataDir: URL) -> Bool {
        let statePath = dataDir.appendingPathComponent("state.json")
        return FileManager.default.fileExists(atPath: statePath.path)
    }
}
