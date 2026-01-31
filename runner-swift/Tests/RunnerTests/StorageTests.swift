import Testing
import Foundation
@testable import RunnerLib

@Suite("Storage Tests")
struct StorageTests {
    
    func createTempStorage() async throws -> (URL, Storage) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storage = Storage(dataDir: tempDir)
        return (tempDir, storage)
    }
    
    func cleanup(_ tempDir: URL) {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize creates directories")
    func initializeCreatesDirectories() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        let runsDir = tempDir.appendingPathComponent("runs")
        #expect(FileManager.default.fileExists(atPath: runsDir.path))
        
        let indexPath = runsDir.appendingPathComponent("index.json")
        #expect(FileManager.default.fileExists(atPath: indexPath.path))
        
        let statePath = tempDir.appendingPathComponent("state.json")
        #expect(FileManager.default.fileExists(atPath: statePath.path))
    }
    
    @Test("Initialize creates valid index")
    func initializeCreatesValidIndex() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 0)
        #expect(index.total == 0)
    }
    
    // MARK: - Run Management Tests
    
    @Test("Add run")
    func addRun() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        let run = RunSummary(
            id: "test-123",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1769306400
        )
        
        try await storage.addRun(run)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 1)
        #expect(index.runs[0].id == "test-123")
        #expect(index.runs[0].task == "heartbeat")
        #expect(index.runs[0].exitCode == nil)
        #expect(index.runs[0].pid == 12345)
    }
    
    @Test("Update run")
    func updateRun() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        let run = RunSummary(
            id: "test-123",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        try await storage.addRun(run)
        
        try await storage.updateRun(id: "test-123", exitCode: 0, finishedAt: "2026-01-25T08:00:01Z")
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == 0)
        #expect(index.runs[0].finishedAt == "2026-01-25T08:00:01Z")
        #expect(index.runs[0].pid == nil)
    }
    
    @Test("Mark interrupted")
    func markInterrupted() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        let run = RunSummary(
            id: "test-123",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        try await storage.addRun(run)
        
        try await storage.markInterrupted(id: "test-123")
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == -1)
        #expect(index.runs[0].finishedAt != nil)
    }
    
    @Test("Get running tasks")
    func getRunningTasks() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        // Add running task
        let running = RunSummary(
            id: "running-1",
            task: "task1",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        try await storage.addRun(running)
        
        // Add completed task
        let completed = RunSummary(
            id: "completed-1",
            task: "task2",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: nil
        )
        try await storage.addRun(completed)
        
        let runningTasks = try await storage.getRunningTasks()
        #expect(runningTasks.count == 1)
        #expect(runningTasks[0].id == "running-1")
    }
    
    @Test("Get running tasks excludes no PID")
    func getRunningTasksExcludesNoPid() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        // Add task with no pid (shouldn't be considered running)
        let noPid = RunSummary(
            id: "no-pid",
            task: "task1",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: nil,
            startedAtEpoch: nil
        )
        try await storage.addRun(noPid)
        
        let runningTasks = try await storage.getRunningTasks()
        #expect(runningTasks.count == 0)
    }
    
    // MARK: - Output Tests
    
    @Test("Write output")
    func writeOutput() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        try await storage.writeOutput(id: "test-123", content: "Hello, World!")
        
        let path = tempDir.appendingPathComponent("runs/test-123.output")
        let content = try String(contentsOf: path, encoding: .utf8)
        #expect(content == "Hello, World!")
    }
    
    @Test("Append output")
    func appendOutput() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        try await storage.writeOutput(id: "test-123", content: "Line 1\n")
        try await storage.appendOutput(id: "test-123", content: "Line 2\n")
        
        let path = tempDir.appendingPathComponent("runs/test-123.output")
        let content = try String(contentsOf: path, encoding: .utf8)
        #expect(content == "Line 1\nLine 2\n")
    }
    
    // MARK: - RunDetail Tests
    
    @Test("Write run detail")
    func writeRunDetail() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        let detail = RunDetail(
            id: "test-123",
            task: "heartbeat",
            trigger: "manual",
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:05Z",
            durationSeconds: 5,
            exitCode: 0
        )
        
        try await storage.writeRunDetail(detail)
        
        let path = tempDir.appendingPathComponent("runs/test-123.json")
        #expect(FileManager.default.fileExists(atPath: path.path))
        
        let data = try Data(contentsOf: path)
        let loaded = try JSONDecoder().decode(RunDetail.self, from: data)
        #expect(loaded.id == "test-123")
        #expect(loaded.exitCode == 0)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent add runs")
    func concurrentAddRuns() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        try await storage.initialize()
        
        // Add 10 runs concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let run = RunSummary(
                        id: "run-\(i)",
                        task: "task",
                        exitCode: 0,
                        startedAt: "2026-01-25T08:00:00Z",
                        finishedAt: "2026-01-25T08:00:01Z",
                        pid: nil,
                        startedAtEpoch: nil
                    )
                    try? await storage.addRun(run)
                }
            }
        }
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 10)
    }
    
    // MARK: - Loading Tests
    
    @Test("Load tasks")
    func loadTasks() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Create tasks.json
        let tasks = [
            Task(id: "task1", executor: .shell, description: "Task 1", timeout: 60, command: "echo 1", prompt: nil, workdir: nil),
            Task(id: "task2", executor: .shell, description: "Task 2", timeout: 300, command: "echo 2", prompt: nil, workdir: nil)
        ]
        let encoder = JSONEncoder()
        let data = try encoder.encode(tasks)
        try data.write(to: tempDir.appendingPathComponent("tasks.json"))
        
        let loaded = try await storage.loadTasks()
        #expect(loaded.count == 2)
        #expect(loaded[0].id == "task1")
        #expect(loaded[1].id == "task2")
    }
    
    @Test("Load schedules")
    func loadSchedules() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Create schedules.json
        let json = """
        [
            {"task": "task1", "hour": "*", "minute": 0, "weekday": "*"},
            {"task": "task2", "hour": 9, "minute": 30, "weekday": "1-5"}
        ]
        """.data(using: .utf8)!
        try json.write(to: tempDir.appendingPathComponent("schedules.json"))
        
        let loaded = try await storage.loadSchedules()
        #expect(loaded.count == 2)
        #expect(loaded[0].task == "task1")
        #expect(loaded[1].task == "task2")
    }
}
