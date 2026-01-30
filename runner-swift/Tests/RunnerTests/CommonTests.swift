import Testing
import Foundation
import Darwin
@testable import RunnerLib

@Suite("Common Tests")
struct CommonTests {
    func captureStderr(_ block: () -> Void) -> String {
        let pipe = Pipe()
        let originalFd = dup(STDERR_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        block()
        fflush(stderr)
        pipe.fileHandleForWriting.closeFile()
        dup2(originalFd, STDERR_FILENO)
        close(originalFd)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - RunnerError Tests
    
    @Test("RunnerError taskNotFound description")
    func runnerErrorTaskNotFound() {
        let error = RunnerError.taskNotFound("my_task")
        #expect(error.description == "Task not found: my_task")
    }
    
    @Test("RunnerError noRunsFound description")
    func runnerErrorNoRunsFound() {
        let error = RunnerError.noRunsFound
        #expect(error.description == "No runs found")
    }
    
    @Test("RunnerError unknownQuery description")
    func runnerErrorUnknownQuery() {
        let error = RunnerError.unknownQuery("invalid")
        #expect(error.description == "Unknown query: invalid")
    }

    @Test("CommonOptions defaults")
    func commonOptionsDefaults() {
        let options = try? CommonOptions.parse([])
        #expect(options != nil)
        guard let options else { return }
        #expect(options.verbose == false)
        #expect(options.dryRun == false)
        #expect(options.dataDir.path.hasSuffix("data") == true)
    }

    @Test("CommonOptions log writes when verbose")
    func commonOptionsLogWritesWhenVerbose() {
        let options = try? CommonOptions.parse(["--verbose"])
        #expect(options != nil)
        guard let options else { return }

        let output = captureStderr {
            options.log("hello")
        }

        #expect(output.contains("[DEBUG] hello"))
    }
    
    // MARK: - URL Extension Tests
    
    @Test("URL from argument absolute path")
    func urlFromArgumentAbsolute() {
        let url = URL(argument: "/tmp/test")
        #expect(url != nil)
        #expect(url?.path == "/tmp/test")
    }
    
    @Test("URL from argument relative path")
    func urlFromArgumentRelative() {
        let url = URL(argument: "./data")
        #expect(url != nil)
        #expect(url?.path.hasSuffix("data") == true)
    }
}

@Suite("Validation Tests")
struct ValidationTests {
    
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
    
    // MARK: - Task Validation Tests
    
    @Test("Valid task with command")
    func validTaskWithCommand() throws {
        let json = """
        {
            "id": "test",
            "type": "simple",
            "description": "Test task",
            "timeout": 60,
            "command": "echo hello"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.command != nil)
        #expect(task.command!.isEmpty == false)
    }
    
    @Test("Valid task with prompt")
    func validTaskWithPrompt() throws {
        let json = """
        {
            "id": "test",
            "type": "agent",
            "description": "Agent task",
            "timeout": 60,
            "prompt": "Do something"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.prompt != nil)
        #expect(task.prompt!.isEmpty == false)
    }
    
    @Test("Task effective timeout uses default")
    func taskEffectiveTimeoutDefault() throws {
        let json = """
        {
            "id": "test",
            "type": "simple",
            "description": "Test",
            "command": "echo"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.timeout == nil)
        #expect(task.effectiveTimeout == 600) // Default 10 minutes
    }
    
    @Test("Task effective timeout uses specified value")
    func taskEffectiveTimeoutSpecified() throws {
        let json = """
        {
            "id": "test",
            "type": "simple",
            "description": "Test",
            "timeout": 30,
            "command": "echo"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.timeout == 30)
        #expect(task.effectiveTimeout == 30)
    }
    
    // MARK: - Schedule Validation Tests
    
    @Test("Schedule with all wildcards")
    func scheduleAllWildcards() throws {
        let json = """
        {
            "task": "test",
            "hour": "*",
            "minute": "*",
            "weekday": "*"
        }
        """.data(using: .utf8)!
        
        let schedule = try JSONDecoder().decode(Schedule.self, from: json)
        #expect(schedule.task == "test")
        #expect(schedule.hour.value as? String == "*")
        #expect(schedule.minute.value as? String == "*")
        #expect(schedule.weekday.value as? String == "*")
    }
    
    @Test("Schedule with mixed types")
    func scheduleMixedTypes() throws {
        let json = """
        {
            "task": "test",
            "hour": 9,
            "minute": "*/15",
            "weekday": "1-5"
        }
        """.data(using: .utf8)!
        
        let schedule = try JSONDecoder().decode(Schedule.self, from: json)
        #expect(schedule.hour.value as? Int == 9)
        #expect(schedule.minute.value as? String == "*/15")
        #expect(schedule.weekday.value as? String == "1-5")
    }
    
    // MARK: - Storage Validation Tests
    
    @Test("Storage loads empty tasks gracefully")
    func storageLoadsEmptyTasks() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Create empty tasks.json
        let emptyArray = "[]".data(using: .utf8)!
        try emptyArray.write(to: tempDir.appendingPathComponent("tasks.json"))
        
        let tasks = try await storage.loadTasks()
        #expect(tasks.isEmpty)
    }
    
    @Test("Storage loads empty schedules gracefully")
    func storageLoadsEmptySchedules() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Create empty schedules.json
        let emptyArray = "[]".data(using: .utf8)!
        try emptyArray.write(to: tempDir.appendingPathComponent("schedules.json"))
        
        let schedules = try await storage.loadSchedules()
        #expect(schedules.isEmpty)
    }
}
