import Foundation

// MARK: - Run Repository Protocol

/// Repository protocol for run-related operations.
/// Abstracts storage backend (JSON files, SQLite, etc.)
public protocol RunRepository: Sendable {
    // MARK: Index Operations
    
    /// Load the runs index
    func loadRunsIndex() async throws -> RunsIndex
    
    /// Add a new run to the index
    func addRun(_ run: RunSummary) async throws
    
    /// Update an existing run's completion status
    func updateRun(id: String, exitCode: Int?, finishedAt: String?) async throws
    
    /// Mark a run as interrupted (exit_code = -1)
    func markInterrupted(id: String) async throws
    
    /// Complete a run with exit code and duration (called by complete command)
    func completeRun(id: String, exitCode: Int, duration: Int) async throws
    
    /// Get all currently running tasks (exitCode == nil && pid != nil)
    func getRunningTasks() async throws -> [RunSummary]
    
    // MARK: Detail Operations
    
    /// Write run detail to storage
    func writeRunDetail(_ detail: RunDetail) async throws
    
    /// Load run detail by ID
    func loadRunDetail(id: String) async throws -> RunDetail?
    
    // MARK: Output Operations
    
    /// Write output content (overwrites existing)
    func writeOutput(id: String, content: String) async throws
    
    /// Append content to output
    func appendOutput(id: String, content: String) async throws
}

// MARK: - Config Repository Protocol

/// Repository protocol for configuration operations (read-only at runtime).
public protocol ConfigRepository: Sendable {
    /// Initialize storage (create directories and default files)
    func initialize() async throws
    
    /// Load task definitions
    func loadTasks() async throws -> [Task]
    
    /// Load schedule definitions
    func loadSchedules() async throws -> [Schedule]
}
