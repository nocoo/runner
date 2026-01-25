import Testing
import Foundation
@testable import RunnerLib

@Suite("Executor Tests")
struct ExecutorTests {
    
    func makeTask(id: String = "test", command: String = "echo hello", workdir: String? = nil) -> Task {
        Task(
            id: id,
            description: "Test",
            timeout: 60,
            command: command,
            workdir: workdir
        )
    }
    
    func createTempStorage() async throws -> (URL, Storage) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storage = Storage(dataDir: tempDir)
        try await storage.initialize()
        return (tempDir, storage)
    }
    
    func cleanup(_ tempDir: URL) {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Dry Run Tests
    
    @Test("Dry run does not execute command")
    func dryRun() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "rm -rf /") // Dangerous but won't run
        
        let executor = Executor(storage: storage, dryRun: true, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        #expect(result.exitCode == 0)
        #expect(result.output.contains("DRY RUN"))
    }
    
    // MARK: - Background Execution Tests
    
    @Test("Execute starts background task")
    func executeStartsBackgroundTask() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo hello")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // The task starts in background, so exit code 0 means it launched successfully
        #expect(result.exitCode == 0)
        #expect(result.output.contains("background"))
        
        // Check that run was added to index
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 1)
        #expect(index.runs[0].id == result.id)
        #expect(index.runs[0].task == "test")
        #expect(index.runs[0].exitCode == nil) // Still running
        #expect(index.runs[0].pid != nil)
    }
    
    @Test("Execute creates output header")
    func executeCreatesOutputHeader() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo hello")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "manual")
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        
        // Wait a bit for the file to be created
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        #expect(content.contains("Task: test"))
        #expect(content.contains("Trigger: manual"))
        #expect(content.contains("Command: echo hello"))
    }
    
    @Test("Execute with workdir")
    func executeWithWorkdir() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "pwd", workdir: "/tmp")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        #expect(result.exitCode == 0)
        
        // Wait for background task to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        #expect(content.contains("/tmp") || content.contains("/private/tmp"))
    }
}
