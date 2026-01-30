import Testing
import Foundation
import Darwin
@testable import RunnerLib

@Suite("Monitor Tests")
struct MonitorTests {
    
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

    func createRunDetail(id: String, finishedAt: String? = "2026-01-25T08:00:01Z", exitCode: Int = 0) -> RunDetail {
        RunDetail(
            id: id,
            task: "test",
            trigger: "manual",
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: finishedAt,
            durationSeconds: 1,
            exitCode: exitCode
        )
    }

    func captureStderrAsync(_ block: () async -> Void) async -> String {
        let pipe = Pipe()
        let originalFd = dup(STDERR_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        await block()
        fflush(stderr)
        pipe.fileHandleForWriting.closeFile()
        dup2(originalFd, STDERR_FILENO)
        close(originalFd)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func processStartTime(pid: Int) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "lstart=", "-p", String(pid)]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let lstart = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !lstart.isEmpty else { return nil }

            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            if let date = formatter.date(from: lstart) {
                return Int64(date.timeIntervalSince1970)
            }
        } catch {
            return nil
        }

        return nil
    }
    
    // MARK: - Empty State Tests
    
    @Test("Check running tasks empty")
    func checkRunningTasksEmpty() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()

        #expect(interrupted.isEmpty)
    }

    @Test("Monitor logs when verbose")
    func monitorLogsWhenVerbose() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let monitor = Monitor(storage: storage, verbose: true)
        let output = await captureStderrAsync {
            _ = try? await monitor.checkRunningTasks()
        }

        #expect(output.contains("[MONITOR DEBUG]"))
    }
    
    // MARK: - Running Tasks Tests
    
    @Test("Check running tasks with completed task")
    func checkRunningTasksWithCompletedTask() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Add a completed task
        let run = RunSummary(
            id: "completed-1",
            task: "test",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: nil
        )
        try await storage.addRun(run)
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        #expect(interrupted.isEmpty) // Completed tasks should not be affected
    }
    
    @Test("Check running tasks grace period")
    func checkRunningTasksGracePeriod() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Add a task that just started (within grace period)
        let now = Int64(Date().timeIntervalSince1970)
        let run = RunSummary(
            id: "running-1",
            task: "test",
            exitCode: nil,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            finishedAt: nil,
            pid: Int(ProcessInfo.processInfo.processIdentifier), // Current process (exists)
            startedAtEpoch: now
        )
        try await storage.addRun(run)
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        // Should be skipped due to grace period
        #expect(interrupted.isEmpty)
    }
    
    @Test("Check running tasks no PID")
    func checkRunningTasksNoPid() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Add a task with no PID - this shouldn't be returned by getRunningTasks
        let run = RunSummary(
            id: "no-pid",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: nil,
            startedAtEpoch: nil
        )
        try await storage.addRun(run)
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        // Tasks without PID are not considered "running" by getRunningTasks
        #expect(interrupted.isEmpty)
    }
    
    @Test("Check running tasks marks dead process")
    func checkRunningTasksMarksDeadProcess() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Add a task with a PID that definitely doesn't exist
        let oldTime = Int64(Date().timeIntervalSince1970) - 200 // 200 seconds ago (past grace period)
        let run = RunSummary(
            id: "dead-process",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 999999999, // Very unlikely to exist
            startedAtEpoch: oldTime
        )
        try await storage.addRun(run)
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        #expect(interrupted == ["dead-process"])
        
        // Verify it was marked as interrupted
        let index = try await storage.loadRunsIndex()
        let updatedRun = index.runs.first { $0.id == "dead-process" }
        #expect(updatedRun?.exitCode == -1)
    }

    @Test("Check running tasks syncs from detail when pid missing")
    func checkRunningTasksSyncsFromDetailNoPid() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let run = RunSummary(
            id: "no-pid-detail",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 999999999,
            startedAtEpoch: nil
        )
        try await storage.addRun(run)
        try await storage.writeRunDetail(createRunDetail(id: "no-pid-detail", exitCode: 0))

        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()

        #expect(interrupted.isEmpty)

        let index = try await storage.loadRunsIndex()
        let updatedRun = index.runs.first { $0.id == "no-pid-detail" }
        #expect(updatedRun?.exitCode == 0)
        #expect(updatedRun?.finishedAt != nil)
    }

    @Test("Check running tasks syncs from detail when pid dead")
    func checkRunningTasksSyncsFromDetailDeadPid() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let oldTime = Int64(Date().timeIntervalSince1970) - 200
        let run = RunSummary(
            id: "dead-pid-detail",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 999999999,
            startedAtEpoch: oldTime
        )
        try await storage.addRun(run)
        try await storage.writeRunDetail(createRunDetail(id: "dead-pid-detail", exitCode: 2))

        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()

        #expect(interrupted.isEmpty)

        let index = try await storage.loadRunsIndex()
        let updatedRun = index.runs.first { $0.id == "dead-pid-detail" }
        #expect(updatedRun?.exitCode == 2)
        #expect(updatedRun?.finishedAt != nil)
    }
    
    @Test("Check running tasks leaves running process")
    func checkRunningTasksLeavesRunningProcess() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }

        // Add a task with current process PID (which is definitely running)
        let currentPid = Int(ProcessInfo.processInfo.processIdentifier)
        let start = processStartTime(pid: currentPid)
        #expect(start != nil)
        guard let start else { return }

        let oldTime = start
        let run = RunSummary(
            id: "current-process",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: currentPid,
            startedAtEpoch: oldTime
        )
        try await storage.addRun(run)

        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()

        #expect(interrupted.isEmpty)
    }

    @Test("Check running tasks handles pid reuse")
    func checkRunningTasksHandlesPidReuse() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }

        let currentPid = Int(ProcessInfo.processInfo.processIdentifier)
        let start = processStartTime(pid: currentPid)
        #expect(start != nil)
        guard let start else { return }

        let run = RunSummary(
            id: "pid-reuse",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: currentPid,
            startedAtEpoch: start - 1000
        )
        try await storage.addRun(run)
        try await storage.writeRunDetail(createRunDetail(id: "pid-reuse", exitCode: 7))

        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()

        #expect(interrupted.isEmpty)

        let index = try await storage.loadRunsIndex()
        let updatedRun = index.runs.first { $0.id == "pid-reuse" }
        #expect(updatedRun?.exitCode == 7)
        #expect(updatedRun?.finishedAt != nil)
    }
    
    // MARK: - Multiple Tasks Tests
    
    @Test("Check running tasks multiple")
    func checkRunningTasksMultiple() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let oldTime = Int64(Date().timeIntervalSince1970) - 200
        
        // Add multiple tasks
        let tasks = [
            RunSummary(id: "dead-1", task: "task1", exitCode: nil, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: 999999991, startedAtEpoch: oldTime),
            RunSummary(id: "dead-2", task: "task2", exitCode: nil, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: 999999992, startedAtEpoch: oldTime),
            RunSummary(id: "completed", task: "task3", exitCode: 0, startedAt: "2026-01-25T08:00:00Z", finishedAt: "2026-01-25T08:00:01Z", pid: nil, startedAtEpoch: nil),
        ]
        
        for task in tasks {
            try await storage.addRun(task)
        }
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        #expect(Set(interrupted) == Set(["dead-1", "dead-2"]))
    }
    
    // MARK: - Idempotency Tests
    
    @Test("Check running tasks is idempotent")
    func checkRunningTasksIdempotent() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let oldTime = Int64(Date().timeIntervalSince1970) - 200
        let run = RunSummary(
            id: "dead-1",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 999999999,
            startedAtEpoch: oldTime
        )
        try await storage.addRun(run)
        
        let monitor = Monitor(storage: storage, verbose: false)
        
        // First call marks it as interrupted
        let interrupted1 = try await monitor.checkRunningTasks()
        #expect(interrupted1 == ["dead-1"])
        
        // Second call should find nothing (already marked)
        let interrupted2 = try await monitor.checkRunningTasks()
        #expect(interrupted2.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    @Test("Check running tasks with mixed state")
    func checkRunningTasksMixedState() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        let now = Int64(Date().timeIntervalSince1970)
        let oldTime = now - 200
        let currentPid = Int(ProcessInfo.processInfo.processIdentifier)
        
        // Add various task states
        let tasks = [
            // Completed successfully
            RunSummary(id: "success", task: "t1", exitCode: 0, startedAt: "2026-01-25T08:00:00Z", finishedAt: "2026-01-25T08:00:01Z", pid: nil, startedAtEpoch: nil),
            // Failed
            RunSummary(id: "failed", task: "t2", exitCode: 1, startedAt: "2026-01-25T08:00:00Z", finishedAt: "2026-01-25T08:00:01Z", pid: nil, startedAtEpoch: nil),
            // Dead process (past grace period)
            RunSummary(id: "dead", task: "t3", exitCode: nil, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: 999999999, startedAtEpoch: oldTime),
            // Still in grace period
            RunSummary(id: "grace", task: "t4", exitCode: nil, startedAt: ISO8601DateFormatter().string(from: Date()), finishedAt: nil, pid: currentPid, startedAtEpoch: now),
            // Already interrupted
            RunSummary(id: "interrupted", task: "t5", exitCode: -1, startedAt: "2026-01-25T08:00:00Z", finishedAt: "2026-01-25T08:00:01Z", pid: nil, startedAtEpoch: nil),
        ]
        
        for task in tasks {
            try await storage.addRun(task)
        }
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        // Only the dead process should be marked
        #expect(interrupted == ["dead"])
    }
    
    @Test("Check running tasks with no epoch falls back")
    func checkRunningTasksNoEpoch() async throws {
        let (tempDir, storage) = try await createTempStorage()
        defer { cleanup(tempDir) }
        
        // Task without startedAtEpoch - should use fallback behavior
        let run = RunSummary(
            id: "no-epoch",
            task: "test",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 999999999,
            startedAtEpoch: nil
        )
        try await storage.addRun(run)
        
        let monitor = Monitor(storage: storage, verbose: false)
        let interrupted = try await monitor.checkRunningTasks()
        
        // Should still mark as interrupted (process doesn't exist)
        #expect(interrupted == ["no-epoch"])
    }
}
