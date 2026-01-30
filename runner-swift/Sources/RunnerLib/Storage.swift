import Foundation

/// Thread-safe JSON storage with file locking
public actor Storage {
    public let dataDir: URL
    private let fileIO: FileIO
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init(dataDir: URL, fileIO: FileIO = DefaultFileIO()) {
        self.dataDir = dataDir
        self.fileIO = fileIO
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Initialization
    
    public func initialize() throws {
        let runsDir = dataDir.appendingPathComponent("runs")
        try fileIO.createDirectory(at: runsDir, withIntermediateDirectories: true)
        
        let indexPath = runsDir.appendingPathComponent("index.json")
        if !fileIO.fileExists(atPath: indexPath.path) {
            let index = RunsIndex(runs: [], total: 0, updatedAt: timestamp())
            try writeJSON(index, to: indexPath)
        }
        
        let statePath = dataDir.appendingPathComponent("state.json")
        if !fileIO.fileExists(atPath: statePath.path) {
            let state = SystemState(version: "0.1.0", lastRun: nil, totalRunsToday: 0, successRateToday: 0)
            try writeJSON(state, to: statePath)
        }
    }
    
    // MARK: - Loading
    
    public func loadTasks() throws -> [Task] {
        let path = dataDir.appendingPathComponent("tasks.json")
        return try readJSON(from: path)
    }
    
    public func loadSchedules() throws -> [Schedule] {
        let path = dataDir.appendingPathComponent("schedules.json")
        return try readJSON(from: path)
    }
    
    public func loadRunsIndex() throws -> RunsIndex {
        let path = dataDir.appendingPathComponent("runs/index.json")
        if fileIO.fileExists(atPath: path.path) {
            return try readJSON(from: path)
        }
        return RunsIndex(runs: [], total: 0, updatedAt: timestamp())
    }
    
    // MARK: - Run Management (with file locking)
    
    public func addRun(_ run: RunSummary) throws {
        try withFileLock(name: "index") {
            var index = try loadRunsIndex()
            index.runs.append(run)
            index.total = index.runs.count
            index.updatedAt = timestamp()
            
            let path = dataDir.appendingPathComponent("runs/index.json")
            try writeJSON(index, to: path)
        }
    }
    
    public func updateRun(id: String, exitCode: Int?, finishedAt: String?) throws {
        try withFileLock(name: "index") {
            var index = try loadRunsIndex()
            
            if let idx = index.runs.firstIndex(where: { $0.id == id }) {
                if let code = exitCode {
                    index.runs[idx].exitCode = code
                }
                if let finished = finishedAt {
                    index.runs[idx].finishedAt = finished
                }
                index.runs[idx].pid = nil
                index.updatedAt = timestamp()
                
                let path = dataDir.appendingPathComponent("runs/index.json")
                try writeJSON(index, to: path)
            }
        }
    }
    
    public func markInterrupted(id: String) throws {
        try updateRun(id: id, exitCode: -1, finishedAt: timestamp())
    }
    
    public func getRunningTasks() throws -> [RunSummary] {
        let index = try loadRunsIndex()
        return index.runs.filter { $0.exitCode == nil && $0.pid != nil }
    }
    
    // MARK: - Output Files
    
    public func writeOutput(id: String, content: String) throws {
        let path = dataDir.appendingPathComponent("runs/\(id).output")
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
    
    public func appendOutput(id: String, content: String) throws {
        let path = dataDir.appendingPathComponent("runs/\(id).output")
        if fileIO.fileExists(atPath: path.path) {
            let handle = try fileIO.openFileHandleForWriting(to: path)
            handle.seekToEndOfFile()
            if let data = content.data(using: .utf8) {
                handle.write(data)
            }
            try fileIO.closeFileHandle(handle)
        } else {
            try content.write(to: path, atomically: true, encoding: .utf8)
        }
    }
    
    public func writeRunDetail(_ detail: RunDetail) throws {
        let path = dataDir.appendingPathComponent("runs/\(detail.id).json")
        try writeJSON(detail, to: path)
    }
    
    public func loadRunDetail(id: String) throws -> RunDetail? {
        let path = dataDir.appendingPathComponent("runs/\(id).json")
        guard fileIO.fileExists(atPath: path.path) else { return nil }
        return try readJSON(from: path)
    }
    
    // MARK: - Helpers
    
    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
    
    private func readJSON<T: Decodable>(from url: URL) throws -> T {
        let data = try fileIO.readData(from: url)
        return try decoder.decode(T.self, from: data)
    }
    
    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try fileIO.writeData(data, to: url)
    }
    
    private func withFileLock<T>(name: String, operation: () throws -> T) throws -> T {
        let lockPath = dataDir.appendingPathComponent("runs/.\(name).lock")
        
        // Create lock file if needed
        if !fileIO.fileExists(atPath: lockPath.path) {
            fileIO.createFile(atPath: lockPath.path, contents: nil)
        }
        
        let handle = try fileIO.openFileHandleForUpdating(atPath: lockPath.path)
        let fd = handle.fileDescriptor
        
        // Exclusive lock
        guard fileIO.lockFileDescriptor(fd) else {
            throw StorageError.lockFailed
        }
        defer { fileIO.unlockFileDescriptor(fd) }
        defer { try? fileIO.closeFileHandle(handle) }
        
        return try operation()
    }
}

public enum StorageError: Error {
    case lockFailed
    case fileNotFound
}
