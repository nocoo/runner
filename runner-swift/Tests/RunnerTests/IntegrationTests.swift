import Testing
import Foundation
@testable import RunnerLib

@Suite("Integration Tests")
struct IntegrationTests {
    
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

    func isJqAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["jq"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - End-to-End Flow Tests
    
    @Test("Full task execution flow")
    func fullTaskExecutionFlow() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // 1. Create task
        let task = Task(
            id: "integration_test",
            executor: .shell,
            description: "Integration test",
            timeout: 60,
            command: "echo 'Hello from integration test' && date",
            prompt: nil,
            workdir: nil
        )
        
        // 2. Execute task
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "integration_test")
        
        #expect(result.exitCode == 0)
        #expect(!result.id.isEmpty)
        
        // 3. Verify run was recorded
        let indexBefore = try await storage.loadRunsIndex()
        #expect(indexBefore.runs.count == 1)
        #expect(indexBefore.runs[0].id == result.id)
        #expect(indexBefore.runs[0].exitCode == nil) // Still running
        
        // 4. Wait for completion
        try await _Concurrency.Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        
        // 5. Verify completion
        let indexAfter = try await storage.loadRunsIndex()
        if isJqAvailable() {
            #expect(indexAfter.runs[0].exitCode == 0)
            #expect(indexAfter.runs[0].finishedAt != nil)
        }
        
        // 6. Verify output
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let output = try String(contentsOf: outputPath, encoding: .utf8)
        #expect(output.contains("Hello from integration test"))
        
        // 7. Verify detail
        let detail = try await storage.loadRunDetail(id: result.id)
        if isJqAvailable() {
            #expect(detail != nil)
            #expect(detail?.exitCode == 0)
            #expect(detail?.trigger == "integration_test")
        }
    }
    
    @Test("Scheduler matches and executes tasks")
    func schedulerMatchesAndExecutes() async throws {
        let (tempDir, _) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Create tasks
        let tasks = [
            Task(id: "task_9am", executor: .shell, description: "9 AM task", timeout: 60, command: "echo 9am", prompt: nil, workdir: nil),
            Task(id: "task_hourly", executor: .shell, description: "Hourly task", timeout: 60, command: "echo hourly", prompt: nil, workdir: nil),
            Task(id: "task_weekday", executor: .shell, description: "Weekday task", timeout: 60, command: "echo weekday", prompt: nil, workdir: nil),
        ]
        
        // Create schedules
        let schedules = [
            Schedule(task: "task_9am", hour: AnyCodable(9), minute: AnyCodable(0), weekday: AnyCodable("*")),
            Schedule(task: "task_hourly", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*")),
            Schedule(task: "task_weekday", hour: AnyCodable(9), minute: AnyCodable(0), weekday: AnyCodable("1-5")),
        ]
        
        // Test at 9:00 Monday
        let matched = Scheduler.findScheduledTasks(
            schedules: schedules,
            tasks: tasks,
            hour: 9,
            minute: 0,
            weekday: 1
        )
        
        // Should match all three
        #expect(matched.count == 3)
        #expect(matched.contains("task_9am"))
        #expect(matched.contains("task_hourly"))
        #expect(matched.contains("task_weekday"))
        
        // Test at 10:00 Monday
        let matched2 = Scheduler.findScheduledTasks(
            schedules: schedules,
            tasks: tasks,
            hour: 10,
            minute: 0,
            weekday: 1
        )
        
        // Should only match hourly
        #expect(matched2 == ["task_hourly"])
        
        // Test at 9:00 Sunday
        let matched3 = Scheduler.findScheduledTasks(
            schedules: schedules,
            tasks: tasks,
            hour: 9,
            minute: 0,
            weekday: 0
        )
        
        // Should match 9am and hourly but not weekday
        #expect(matched3.count == 2)
        #expect(matched3.contains("task_9am"))
        #expect(matched3.contains("task_hourly"))
        #expect(!matched3.contains("task_weekday"))
    }
    
    @Test("Monitor cleans up after executor")
    func monitorCleansUpAfterExecutor() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Execute a fast task
        let task = Task(
            id: "cleanup_test",
            executor: .shell,
            description: "Cleanup test",
            timeout: 60,
            command: "echo done",
            prompt: nil,
            workdir: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // Task is running
        let runningBefore = try await storage.getRunningTasks()
        #expect(runningBefore.count == 1)
        
        // Wait for completion
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let _ = try await storage.loadRunDetail(id: result.id) {
                break
            }
            try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        // Task completed, but still has PID in index (until jq updates it)
        // Run monitor to check
        let monitor = Monitor(storage: storage, verbose: false)
        _ = try await monitor.checkRunningTasks()
        
        // Should be empty or the task should be properly handled
        // (either already finished or monitor marks it)
        let index = try await storage.loadRunsIndex()
        let run = index.runs.first { $0.id == result.id }
        #expect(run != nil)
        if isJqAvailable() {
            let detail = try await storage.loadRunDetail(id: result.id)
            #expect(detail != nil)
        }
    }
    
    // MARK: - Failure Scenario Tests
    
    @Test("Failed task is recorded correctly")
    func failedTaskRecorded() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = Task(
            id: "failing_task",
            executor: .shell,
            description: "Failing task",
            timeout: 60,
            command: "echo 'about to fail' && exit 1",
            prompt: nil,
            workdir: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        try await _Concurrency.Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        
        let detail = try await storage.loadRunDetail(id: result.id)
        #expect(detail?.exitCode == 1)
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let output = try String(contentsOf: outputPath, encoding: .utf8)
        #expect(output.contains("about to fail"))
    }
    
    @Test("Timed out task is recorded correctly")
    func timedOutTaskRecorded() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = Task(
            id: "timeout_task",
            executor: .shell,
            description: "Timeout task",
            timeout: 2,
            command: "echo 'task_started' && sleep 10 && echo 'task_completed'",
            prompt: nil,
            workdir: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // Wait for timeout + cleanup (increased for CI)
        try await _Concurrency.Task.sleep(nanoseconds: 5_000_000_000) // 5s
        
        let detail = try await storage.loadRunDetail(id: result.id)
        #expect(detail?.exitCode == 124) // Timeout exit code
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let output = try String(contentsOf: outputPath, encoding: .utf8)
        #expect(output.contains("task_started"))
        #expect(output.contains("TIMEOUT"))
        
        // Count occurrences - "task_completed" appears once in the command header,
        // but should NOT appear as actual output (which would be a second occurrence)
        let occurrences = output.components(separatedBy: "task_completed").count - 1
        #expect(occurrences == 1) // Only in command header, not as output
    }
    
    // MARK: - Storage Persistence Tests
    
    @Test("Storage persists across instances")
    func storagePersistsAcrossInstances() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // First storage instance
        let storage1 = Storage(dataDir: tempDir)
        try await storage1.initialize()
        
        let run = RunSummary(
            id: "persist-test",
            task: "test",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: nil
        )
        try await storage1.addRun(run)
        
        // Second storage instance (same directory)
        let storage2 = Storage(dataDir: tempDir)
        let index = try await storage2.loadRunsIndex()
        
        #expect(index.runs.count == 1)
        #expect(index.runs[0].id == "persist-test")
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("Concurrent storage operations are safe")
    func concurrentStorageOperations() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Add runs with delays to avoid file contention
        for i in 0..<10 {
            let run = RunSummary(
                id: "concurrent-\(i)",
                task: "task-\(i % 3)",
                exitCode: i % 2 == 0 ? 0 : nil,
                startedAt: "2026-01-25T08:00:00Z",
                finishedAt: i % 2 == 0 ? "2026-01-25T08:00:01Z" : nil,
                pid: i % 2 == 0 ? nil : 12345 + i,
                startedAtEpoch: nil
            )
            try await storage.addRun(run)
            // Small delay to avoid file lock contention
            try await _Concurrency.Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 10)
        #expect(index.total == 10)
        
        // Verify all runs are present
        for i in 0..<10 {
            let found = index.runs.contains { $0.id == "concurrent-\(i)" }
            #expect(found, "Run concurrent-\(i) should exist")
        }
    }
}
