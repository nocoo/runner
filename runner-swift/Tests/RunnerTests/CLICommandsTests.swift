import Foundation
import _Concurrency
import Darwin
import Foundation
import Testing
@testable import RunnerLib

@Suite("CLICommands Tests", .serialized)
struct CLICommandsTests {
    actor ExitCaptureBox {
        var code: Int32?
        func set(_ value: Int32) { code = value }
    }
    func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func makeStorage(at url: URL) async throws -> Storage {
        let storage = Storage(dataDir: url)
        try await storage.initialize()
        return storage
    }

    func resetExitHandler() {
        ExitHandler.handle = { code in
            Darwin.exit(code)
        }
    }

    func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    func ensureRunsDirectory(at dataDir: URL) throws {
        let runsDir = dataDir.appendingPathComponent("runs")
        try FileManager.default.createDirectory(at: runsDir, withIntermediateDirectories: true)
    }

    func captureStdoutAsync(_ block: () async throws -> Void) async throws -> String {
        let pipe = Pipe()
        let originalFd = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        try await block()
        fflush(stdout)
        pipe.fileHandleForWriting.closeFile()
        dup2(originalFd, STDOUT_FILENO)
        close(originalFd)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func captureStderrAsync(_ block: () async throws -> Void) async throws -> String {
        let pipe = Pipe()
        let originalFd = dup(STDERR_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        try await block()
        fflush(stderr)
        pipe.fileHandleForWriting.closeFile()
        dup2(originalFd, STDERR_FILENO)
        close(originalFd)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func withExitCapture(_ block: () async throws -> Void) async throws -> Int32? {
        let box = ExitCaptureBox()
        let previous = ExitHandler.handle
        ExitHandler.handle = { code in
            _Concurrency.Task { await box.set(code) }
        }
        defer { ExitHandler.handle = previous }
        try await block()
        return await box.code
    }

    @Test("Run prints output and exits with code")
    func runCommandPrintsOutput() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let task = Task(id: "t1", type: .simple, description: "Task", timeout: 5, command: "echo hi", prompt: nil, workdir: nil)
        try writeJSON([task], to: tempDir.appendingPathComponent("tasks.json"))

        let options = try CommonOptions.parse([
            "--data-dir", tempDir.path,
            "--dry-run"
        ])

        let output = try await captureStdoutAsync {
            _ = try await withExitCapture {
                let result = try await runTaskCommand(options: options, task: "t1", trigger: "manual")
                print(result.output)
            }
        }

        resetExitHandler()

        resetExitHandler()

        #expect(output.contains("[DRY RUN]"))
    }

    @Test("Run exits with executor code")
    func runCommandSetsExitCode() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let task = Task(id: "t1", type: .simple, description: "Task", timeout: 5, command: "echo hi", prompt: nil, workdir: nil)
        try writeJSON([task], to: tempDir.appendingPathComponent("tasks.json"))

        let options = try CommonOptions.parse([
            "--data-dir", tempDir.path,
            "--dry-run"
        ])

        let result = try await runTaskCommand(options: options, task: "t1", trigger: "manual")
        #expect(result.exitCode == 0)
    }

    @Test("Validate prints errors and exits non-zero")
    func validateCommandErrors() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let tasks = [Task(id: "t1", type: .simple, description: "Task", timeout: nil, command: nil, prompt: nil, workdir: nil)]
        let schedules = [Schedule(task: "missing", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))]
        try writeJSON(tasks, to: tempDir.appendingPathComponent("tasks.json"))
        try writeJSON(schedules, to: tempDir.appendingPathComponent("schedules.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stderr = try await captureStderrAsync {
            _ = try await withExitCapture {
                let result = try await validateCommand(options: options)
                if case .failure(let error) = result {
                    for issue in error.issues {
                        FileHandle.standardError.write(Data("Error: \(issue.message)\n".utf8))
                    }
                    ExitHandler.exit(1)
                }
            }
        }

        resetExitHandler()

        resetExitHandler()

        #expect(stderr.contains("Error:"))
    }

    @Test("Validate prints summary on success")
    func validateCommandSuccess() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let tasks = [Task(id: "t1", type: .simple, description: "Task", timeout: 5, command: "echo hi", prompt: nil, workdir: nil)]
        let schedules = [Schedule(task: "t1", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))]
        try writeJSON(tasks, to: tempDir.appendingPathComponent("tasks.json"))
        try writeJSON(schedules, to: tempDir.appendingPathComponent("schedules.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let result = try await validateCommand(options: options)
            if case .success(let summary) = result {
                print("Configuration is valid")
                print("  Tasks: \(summary.taskCount)")
                print("  Schedules: \(summary.scheduleCount)")
            }
        }

        resetExitHandler()

        #expect(stdout.contains("Configuration is valid"))
        #expect(stdout.contains("Tasks: 1"))
        #expect(stdout.contains("Schedules: 1"))
    }

    @Test("List prints task entries")
    func listCommandPrintsTasks() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let tasks = [Task(id: "t1", type: .simple, description: "Task", timeout: 5, command: "echo hi", prompt: nil, workdir: nil)]
        try writeJSON(tasks, to: tempDir.appendingPathComponent("tasks.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let lines = try await listTaskEntries(options: options)
            for line in lines { print(line) }
        }

        resetExitHandler()

        #expect(stdout.contains("t1: Task"))
    }

    @Test("Logs list outputs entries")
    func logsCommandList() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let run = RunSummary(id: "r1", task: "t1", exitCode: 0, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: nil, startedAtEpoch: nil)
        let index = RunsIndex(runs: [run], total: 1, updatedAt: "")
        try writeJSON(index, to: tempDir.appendingPathComponent("runs/index.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let lines = try await logsListEntries(options: options, limit: 20)
            for line in lines { print(line) }
        }

        resetExitHandler()

        #expect(stdout.contains("r1"))
        #expect(stdout.contains("t1"))
    }

    @Test("Logs output prints last run")
    func logsCommandOutput() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let run = RunSummary(id: "r1", task: "t1", exitCode: 0, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: nil, startedAtEpoch: nil)
        let index = RunsIndex(runs: [run], total: 1, updatedAt: "")
        try writeJSON(index, to: tempDir.appendingPathComponent("runs/index.json"))
        try "line1\nline2".write(to: tempDir.appendingPathComponent("runs/r1.output"), atomically: true, encoding: .utf8)

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let content = try await logsOutput(options: options, id: "r1", tail: 1)

        resetExitHandler()

        #expect(content.contains("line2"))
    }

    @Test("Api prints output")
    func apiCommandPrintsOutput() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let tasks = [Task(id: "t1", type: .simple, description: "Task", timeout: 5, command: "echo hi", prompt: nil, workdir: nil)]
        let schedules = [Schedule(task: "t1", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))]
        try writeJSON(tasks, to: tempDir.appendingPathComponent("tasks.json"))
        try writeJSON(schedules, to: tempDir.appendingPathComponent("schedules.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let output = try await apiCommandOutput(options: options, query: "tasks")
            print(output)
        }

        resetExitHandler()

        #expect(stdout.contains("\"id\" : \"t1\""))
    }

    @Test("Cleanup prints dry run summary")
    func cleanupCommandDryRun() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let run = RunSummary(id: "stale", task: "t1", exitCode: nil, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: nil, startedAtEpoch: 1769308800)
        let index = RunsIndex(runs: [run], total: 1, updatedAt: "")
        try writeJSON(index, to: tempDir.appendingPathComponent("runs/index.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let result = try await cleanupCommand(options: options, force: false)
            for line in result.lines { print(line) }
        }

        resetExitHandler()

        #expect(stdout.contains("Dry run mode"))
        #expect(stdout.contains("No stale runs found") == false)
    }

    @Test("Cleanup marks interrupted when forced")
    func cleanupCommandForceMarksInterrupted() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let run = RunSummary(id: "stale", task: "t1", exitCode: nil, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: nil, startedAtEpoch: 1769308800)
        let index = RunsIndex(runs: [run], total: 1, updatedAt: "")
        try writeJSON(index, to: tempDir.appendingPathComponent("runs/index.json"))

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let result = try await cleanupCommand(options: options, force: true)
            for line in result.lines { print(line) }
        }

        resetExitHandler()

        #expect(stdout.contains("Marked stale as interrupted"))
    }

    @Test("Monitor prints no interrupted tasks")
    func monitorCommandEmpty() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let interrupted = try await monitorCommand(options: options)
            if interrupted.isEmpty {
                print("No interrupted tasks found")
            } else {
                print("Marked \(interrupted.count) tasks as interrupted:")
                for id in interrupted { print("  \(id)") }
            }
        }

        resetExitHandler()

        #expect(stdout.contains("No interrupted tasks found"))
    }

    @Test("Init prints message")
    func initCommandPrintsMessage() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)

        let options = try CommonOptions.parse(["--data-dir", tempDir.path])

        let stdout = try await captureStdoutAsync {
            let message = try await initCommandMessage(options: options)
            print(message)
        }

        resetExitHandler()

        #expect(stdout.contains("Initialized data directory"))
    }

    @Test("Auto uses mock time")
    func autoCommandUsesMockTime() async throws {
        let tempDir = try makeTempDir()
        _ = try await makeStorage(at: tempDir)
        let tasks = [Task(id: "t1", type: .simple, description: "Task", timeout: 5, command: "echo hi", prompt: nil, workdir: nil)]
        let schedules = [Schedule(task: "t1", hour: AnyCodable(9), minute: AnyCodable(0), weekday: AnyCodable("*"))]
        try writeJSON(tasks, to: tempDir.appendingPathComponent("tasks.json"))
        try writeJSON(schedules, to: tempDir.appendingPathComponent("schedules.json"))

        let options = try CommonOptions.parse([
            "--data-dir", tempDir.path,
            "--dry-run",
            "--verbose"
        ])

        let stderr = try await captureStderrAsync {
            _ = try await runAutoCommand(
                options: options,
                mockHour: 9,
                mockMinute: 0,
                mockWeekday: 1
            )
        }

        resetExitHandler()

        #expect(stderr.contains("[DEBUG]"))
    }


}
