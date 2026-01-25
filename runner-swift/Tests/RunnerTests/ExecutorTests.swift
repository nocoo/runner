import XCTest
@testable import runner

final class ExecutorTests: XCTestCase {
    
    var tempDir: URL!
    var storage: Storage!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = Storage(dataDir: tempDir)
        try await storage.initialize()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Simple Task Tests
    
    func testExecuteSimpleTask() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "echo hello",
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("hello"))
    }
    
    func testExecuteSimpleTaskFailure() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "exit 1",
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        XCTAssertEqual(result.exitCode, 1)
    }
    
    func testExecuteSimpleTaskCreatesRun() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "echo hello",
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        let index = try await storage.loadRunsIndex()
        XCTAssertEqual(index.runs.count, 1)
        XCTAssertEqual(index.runs[0].id, result.id)
        XCTAssertEqual(index.runs[0].task, "test")
        XCTAssertEqual(index.runs[0].exitCode, 0)
        XCTAssertNotNil(index.runs[0].finishedAt)
    }
    
    func testExecuteSimpleTaskCreatesOutput() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "echo hello",
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "manual")
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        XCTAssertTrue(content.contains("Task: test"))
        XCTAssertTrue(content.contains("Trigger: manual"))
        XCTAssertTrue(content.contains("Command: echo hello"))
        XCTAssertTrue(content.contains("hello"))
    }
    
    func testExecuteSimpleTaskCreatesDetail() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "echo hello",
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "scheduled")
        
        let detailPath = tempDir.appendingPathComponent("runs/\(result.id).json")
        let data = try Data(contentsOf: detailPath)
        let detail = try JSONDecoder().decode(RunDetail.self, from: data)
        
        XCTAssertEqual(detail.id, result.id)
        XCTAssertEqual(detail.task, "test")
        XCTAssertEqual(detail.trigger, "scheduled")
        XCTAssertEqual(detail.exitCode, 0)
    }
    
    func testExecuteWithWorkdir() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "pwd",
            prompt: nil,
            workdir: "/tmp",
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("/tmp") || result.output.contains("/private/tmp"))
    }
    
    // MARK: - Manual Task Tests
    
    func testExecuteManualTask() async throws {
        let task = Task(
            id: "manual",
            type: .manual,
            description: "Manual task",
            timeout: 60,
            command: nil,
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "manual")
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("not executed"))
    }
    
    // MARK: - Dry Run Tests
    
    func testDryRunSimpleTask() async throws {
        let task = Task(
            id: "test",
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "rm -rf /", // Dangerous but won't run
            prompt: nil,
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: true, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("DRY RUN"))
    }
    
    func testDryRunAgentTask() async throws {
        let task = Task(
            id: "test",
            type: .agent,
            description: "Test",
            timeout: 300,
            command: nil,
            prompt: "Do something dangerous",
            workdir: nil,
            model: nil
        )
        
        let executor = Executor(storage: storage, dryRun: true, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("DRY RUN"))
    }
}
