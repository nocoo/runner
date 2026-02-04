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
}
