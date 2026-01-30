import Testing
import Foundation
@testable import RunnerLib

@Suite("Executor Tests")
struct ExecutorTests {
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
    func makeScriptBuilder(dataDir: URL) -> ScriptBuilder {
        ScriptBuilder(dataDir: dataDir)
    }
    
    func makeTask(id: String = "test", command: String = "echo hello", workdir: String? = nil) -> Task {
        Task(
            id: id,
            type: .simple,
            description: "Test",
            timeout: 60,
            command: command,
            prompt: nil,
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

    // MARK: - Script Builder Tests

    @Test("Script builder includes command, paths, and timeout")
    func scriptBuilderIncludesBasics() async throws {
        let (tempDir, _) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let task = makeTask(command: "echo hello", workdir: "/tmp")
        let builder = makeScriptBuilder(dataDir: tempDir)
        let script = builder.build(
            task: task,
            command: "echo hello",
            runId: "run-1",
            startedAt: "2026-01-25T08:00:00Z",
            trigger: "manual"
        )

        #expect(script.contains("cd '/tmp'"))
        #expect(script.contains("TIMEOUT=60"))
        #expect(script.contains("eval 'echo hello'"))
        #expect(script.contains("runs/run-1.output"))
        #expect(script.contains("runs/run-1.json"))
        #expect(script.contains("runs/index.json"))
    }

    @Test("Script builder escapes single quotes in command")
    func scriptBuilderEscapesCommand() async throws {
        let (tempDir, _) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let task = makeTask(command: "echo 'hello'", workdir: nil)
        let builder = makeScriptBuilder(dataDir: tempDir)
        let script = builder.build(
            task: task,
            command: "echo 'hello'",
            runId: "run-2",
            startedAt: "2026-01-25T08:00:00Z",
            trigger: "manual"
        )

        #expect(script.contains("eval 'echo '\"'\"'hello'\"'\"''"))
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
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms
        
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
        
        if !isJqAvailable() {
            return
        }

        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let deadline = Date().addingTimeInterval(5)
        var content = ""
        while Date() < deadline {
            if let current = try? String(contentsOf: outputPath, encoding: .utf8) {
                content = current
                if content.contains("/tmp") || content.contains("/private/tmp") {
                    break
                }
            }
            try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        #expect(content.contains("/tmp") || content.contains("/private/tmp"))
    }
    
    // MARK: - Task Completion Tests
    
    @Test("Execute fast command completes")
    func executeFastCommandCompletes() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo 'done'")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // Wait for background task to complete (increased for CI)
        let deadline = Date().addingTimeInterval(8)
        var detail = try await storage.loadRunDetail(id: result.id)
        while Date() < deadline && detail == nil {
            try await _Concurrency.Task.sleep(nanoseconds: 250_000_000) // 250ms
            detail = try await storage.loadRunDetail(id: result.id)
        }
        
        #expect(detail != nil)
        #expect(detail?.exitCode == 0)
        #expect(detail?.task == "test")
        #expect(detail?.trigger == "test")
    }
    
    @Test("Execute failing command records exit code")
    func executeFailingCommand() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "exit 42")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // Wait for background task to complete (increased for CI)
        try await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000) // 2s
        
        let detail = try await storage.loadRunDetail(id: result.id)
        #expect(detail?.exitCode == 42)
    }
    
    @Test("Execute updates index after completion")
    func executeUpdatesIndex() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo done")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        _ = try await executor.execute(task: task, trigger: "test")
        
        // Initially running
        let indexBefore = try await storage.loadRunsIndex()
        #expect(indexBefore.runs[0].exitCode == nil)
        #expect(indexBefore.runs[0].pid != nil)
        
        // Wait for completion
        if !isJqAvailable() {
            return
        }

        let deadline = Date().addingTimeInterval(8)
        var indexAfter = try await storage.loadRunsIndex()
        while Date() < deadline && indexAfter.runs[0].exitCode == nil {
            try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms
            indexAfter = try await storage.loadRunsIndex()
        }

        #expect(indexAfter.runs[0].exitCode == 0)
        #expect(indexAfter.runs[0].finishedAt != nil)
        #expect(indexAfter.runs[0].pid == nil)
    }
    
    // MARK: - Timeout Tests
    
    @Test("Execute timeout triggers kill")
    func executeTimeout() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Task with 2 second timeout but runs for 10 seconds
        let task = Task(
            id: "timeout_test",
            type: .simple,
            description: "Timeout test",
            timeout: 2,
            command: "sleep 10",
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
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        #expect(content.contains("TIMEOUT"))
    }
    
    // MARK: - Script Cleanup Tests
    
    @Test("Execute cleans up script after completion")
    func executeScriptCleanup() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo done")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // Script should exist initially
        let scriptPath = tempDir.appendingPathComponent("runs/.\(result.id).sh")
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms
        #expect(FileManager.default.fileExists(atPath: scriptPath.path))
        
        // Wait for completion
        if isJqAvailable() {
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if !FileManager.default.fileExists(atPath: scriptPath.path) {
                    break
                }
                try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms
            }

            #expect(!FileManager.default.fileExists(atPath: scriptPath.path))
        }
    }
    
    // MARK: - Agent Type Tests
    
    @Test("Agent task builds opencode command")
    func agentTaskBuildsCommand() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = Task(
            id: "agent_test",
            type: .agent,
            description: "Agent test",
            timeout: 60,
            command: nil,
            prompt: "Say hello",
            workdir: nil
        )
        
        // Use dry run to see the command without executing
        let executor = Executor(storage: storage, dryRun: true, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        #expect(result.output.contains("opencode"))
        #expect(result.output.contains("Say hello"))
    }
    
    @Test("Agent task with special characters in prompt")
    func agentTaskSpecialCharacters() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = Task(
            id: "special_chars",
            type: .agent,
            description: "Special chars test",
            timeout: 60,
            command: nil,
            prompt: "It's a test with \"quotes\" and $variables",
            workdir: nil
        )
        
        let executor = Executor(storage: storage, dryRun: true, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        // Should not crash and should contain escaped prompt
        #expect(result.exitCode == 0)
        #expect(result.output.contains("opencode"))
    }
    
    // MARK: - Missing Command Tests
    
    @Test("Task without command or prompt fails")
    func taskWithoutCommandFails() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = Task(
            id: "empty",
            type: .simple,
            description: "Empty task",
            timeout: 60,
            command: nil,
            prompt: nil,
            workdir: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        
        do {
            _ = try await executor.execute(task: task, trigger: "test")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is ExecutorError)
        }
    }
    
    @Test("Task with empty command fails")
    func taskWithEmptyCommandFails() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = Task(
            id: "empty_cmd",
            type: .simple,
            description: "Empty command",
            timeout: 60,
            command: "",
            prompt: nil,
            workdir: nil
        )
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        
        do {
            _ = try await executor.execute(task: task, trigger: "test")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is ExecutorError)
        }
    }
    
    // MARK: - Concurrent Execution Tests
    
    @Test("Execute multiple tasks sequentially")
    func executeMultipleSequentially() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        
        // Launch 3 tasks with delays to avoid file lock contention
        var resultIds: [String] = []
        for i in 0..<3 {
            let task = Task(
                id: "sequential_\(i)",
                type: .simple,
                description: "Sequential test \(i)",
                timeout: 60,
                command: "echo task_\(i)",
                prompt: nil,
                workdir: nil
            )
            let result = try await executor.execute(task: task, trigger: "test")
            resultIds.append(result.id)
            // Delay between launches to avoid index.json contention
            try await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        #expect(resultIds.count == 3)
        
        // Wait until storage reflects all runs or timeout
        let deadline = Date().addingTimeInterval(15)
        var index = try await storage.loadRunsIndex()
        while Date() < deadline && index.runs.count < 3 {
            try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms
            index = try await storage.loadRunsIndex()
        }

        #expect(index.runs.count == 3)

        // All should have completed
        while Date() < deadline && index.runs.contains(where: { $0.exitCode == nil }) {
            try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms
            index = try await storage.loadRunsIndex()
        }
        let completed = index.runs.filter { $0.exitCode != nil }
        #expect(completed.count == 3)
    }
    
    // MARK: - Output Capture Tests
    
    @Test("Execute captures stdout")
    func executeCapturesStdout() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo 'hello world'")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1s
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        #expect(content.contains("hello world"))
    }
    
    @Test("Execute captures stderr")
    func executeCapturesStderr() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo 'error message' >&2")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1s
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        #expect(content.contains("error message"))
    }
    
    @Test("Execute captures multiline output")
    func executeCapturesMultilineOutput() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "echo 'line1' && echo 'line2' && echo 'line3'")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1s
        
        let outputPath = tempDir.appendingPathComponent("runs/\(result.id).output")
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        #expect(content.contains("line1"))
        #expect(content.contains("line2"))
        #expect(content.contains("line3"))
    }
    
    // MARK: - Duration Tracking Tests
    
    @Test("Execute tracks duration")
    func executeTracksDuration() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let task = makeTask(command: "sleep 1")
        
        let executor = Executor(storage: storage, dryRun: false, verbose: false)
        let result = try await executor.execute(task: task, trigger: "test")
        
        try await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000) // 3s
        
        let detail = try await storage.loadRunDetail(id: result.id)
        #expect(detail != nil)
        #expect((detail?.durationSeconds ?? 0) >= 1)
        #expect((detail?.durationSeconds ?? 100) < 5)
    }
}
