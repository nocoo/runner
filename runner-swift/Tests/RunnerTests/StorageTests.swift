import XCTest
@testable import runner

final class StorageTests: XCTestCase {
    
    var tempDir: URL!
    var storage: Storage!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = Storage(dataDir: tempDir)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Initialization Tests
    
    func testInitializeCreatesDirectories() async throws {
        try await storage.initialize()
        
        let runsDir = tempDir.appendingPathComponent("runs")
        XCTAssertTrue(FileManager.default.fileExists(atPath: runsDir.path))
        
        let indexPath = runsDir.appendingPathComponent("index.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexPath.path))
        
        let statePath = tempDir.appendingPathComponent("state.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: statePath.path))
    }
    
    func testInitializeCreatesValidIndex() async throws {
        try await storage.initialize()
        
        let index = try await storage.loadRunsIndex()
        XCTAssertEqual(index.runs.count, 0)
        XCTAssertEqual(index.total, 0)
    }
    
    // MARK: - Run Management Tests
    
    func testAddRun() async throws {
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
        XCTAssertEqual(index.runs.count, 1)
        XCTAssertEqual(index.runs[0].id, "test-123")
        XCTAssertEqual(index.runs[0].task, "heartbeat")
        XCTAssertNil(index.runs[0].exitCode)
        XCTAssertEqual(index.runs[0].pid, 12345)
    }
    
    func testUpdateRun() async throws {
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
        XCTAssertEqual(index.runs[0].exitCode, 0)
        XCTAssertEqual(index.runs[0].finishedAt, "2026-01-25T08:00:01Z")
        XCTAssertNil(index.runs[0].pid)
    }
    
    func testMarkInterrupted() async throws {
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
        XCTAssertEqual(index.runs[0].exitCode, -1)
        XCTAssertNotNil(index.runs[0].finishedAt)
    }
    
    func testGetRunningTasks() async throws {
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
        XCTAssertEqual(runningTasks.count, 1)
        XCTAssertEqual(runningTasks[0].id, "running-1")
    }
    
    func testGetRunningTasksExcludesNoPid() async throws {
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
        XCTAssertEqual(runningTasks.count, 0)
    }
    
    // MARK: - Output Tests
    
    func testWriteOutput() async throws {
        try await storage.initialize()
        
        try await storage.writeOutput(id: "test-123", content: "Hello, World!")
        
        let path = tempDir.appendingPathComponent("runs/test-123.output")
        let content = try String(contentsOf: path, encoding: .utf8)
        XCTAssertEqual(content, "Hello, World!")
    }
    
    func testAppendOutput() async throws {
        try await storage.initialize()
        
        try await storage.writeOutput(id: "test-123", content: "Line 1\n")
        try await storage.appendOutput(id: "test-123", content: "Line 2\n")
        
        let path = tempDir.appendingPathComponent("runs/test-123.output")
        let content = try String(contentsOf: path, encoding: .utf8)
        XCTAssertEqual(content, "Line 1\nLine 2\n")
    }
    
    // MARK: - RunDetail Tests
    
    func testWriteRunDetail() async throws {
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        
        let data = try Data(contentsOf: path)
        let loaded = try JSONDecoder().decode(RunDetail.self, from: data)
        XCTAssertEqual(loaded.id, "test-123")
        XCTAssertEqual(loaded.exitCode, 0)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAddRuns() async throws {
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
                    try? await self.storage.addRun(run)
                }
            }
        }
        
        let index = try await storage.loadRunsIndex()
        XCTAssertEqual(index.runs.count, 10)
    }
    
    // MARK: - Loading Tests
    
    func testLoadTasks() async throws {
        // Create tasks.json
        let tasks = [
            Task(id: "task1", type: .simple, description: "Task 1", timeout: 60, command: "echo 1", prompt: nil, workdir: nil, model: nil),
            Task(id: "task2", type: .agent, description: "Task 2", timeout: 300, command: nil, prompt: "Hello", workdir: nil, model: nil)
        ]
        let encoder = JSONEncoder()
        let data = try encoder.encode(tasks)
        try data.write(to: tempDir.appendingPathComponent("tasks.json"))
        
        let loaded = try await storage.loadTasks()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "task1")
        XCTAssertEqual(loaded[1].id, "task2")
    }
    
    func testLoadSchedules() async throws {
        // Create schedules.json
        let json = """
        [
            {"task": "task1", "hour": "*", "minute": 0, "weekday": "*"},
            {"task": "task2", "hour": 9, "minute": 30, "weekday": "1-5"}
        ]
        """.data(using: .utf8)!
        try json.write(to: tempDir.appendingPathComponent("schedules.json"))
        
        let loaded = try await storage.loadSchedules()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].task, "task1")
        XCTAssertEqual(loaded[1].task, "task2")
    }
}
