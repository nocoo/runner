import Testing
import Foundation
@testable import RunnerLib

// MARK: - SQLiteStorage Tests

@Suite("SQLiteStorage Tests")
struct SQLiteStorageTests {
    
    @Test("SQLiteStorage can be initialized in memory")
    func initializeInMemory() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // Should be able to load empty index
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.isEmpty)
        #expect(index.total == 0)
    }
    
    @Test("addRun adds to database")
    func addRunAddsToDatabase() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: "manual",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        
        try await storage.addRun(run)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 1)
        #expect(index.runs[0].id == "test-1")
        #expect(index.runs[0].task == "heartbeat")
        #expect(index.runs[0].trigger == "manual")
        #expect(index.total == 1)
    }
    
    @Test("updateRun modifies existing run")
    func updateRunModifiesExisting() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: "auto",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        try await storage.updateRun(id: "test-1", exitCode: 0, finishedAt: "2026-01-25T08:00:05Z")
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == 0)
        #expect(index.runs[0].finishedAt == "2026-01-25T08:00:05Z")
        #expect(index.runs[0].pid == nil) // Should be cleared
    }
    
    @Test("markInterrupted sets exit code to -1")
    func markInterruptedSetsExitCode() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: "auto",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        try await storage.markInterrupted(id: "test-1")
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == -1)
        #expect(index.runs[0].finishedAt != nil)
    }
    
    @Test("completeRun updates run with exit code, duration and finished time")
    func completeRunUpdatesAll() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // Add a running task
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: "auto",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        // Complete it
        try await storage.completeRun(id: "test-1", exitCode: 0, duration: 30)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == 0)
        #expect(index.runs[0].finishedAt != nil)
        #expect(index.runs[0].pid == nil)
        
        // Check detail includes duration
        let detail = try await storage.loadRunDetail(id: "test-1")
        #expect(detail != nil)
        #expect(detail?.exitCode == 0)
        #expect(detail?.durationSeconds == 30)
    }
    
    @Test("completeRun with non-zero exit code")
    func completeRunWithFailure() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let run = RunSummary(
            id: "test-1",
            task: "failing-task",
            trigger: "auto",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        try await storage.completeRun(id: "test-1", exitCode: 1, duration: 5)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == 1)
    }
    
    @Test("completeRun with timeout exit code 124")
    func completeRunWithTimeout() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let run = RunSummary(
            id: "test-1",
            task: "slow-task",
            trigger: "auto",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        try await storage.completeRun(id: "test-1", exitCode: 124, duration: 300)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].exitCode == 124)
        
        let detail = try await storage.loadRunDetail(id: "test-1")
        #expect(detail?.durationSeconds == 300)
    }
    
    @Test("getRunningTasks filters correctly")
    func getRunningTasksFilters() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // Running task (no exitCode, has pid)
        let running = RunSummary(
            id: "running-1",
            task: "task1",
            trigger: "auto",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(running)
        
        // Completed task
        let completed = RunSummary(
            id: "completed-1",
            task: "task2",
            trigger: "auto",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: 1737795601
        )
        try await storage.addRun(completed)
        
        // Task without pid (not running)
        let noPid = RunSummary(
            id: "no-pid",
            task: "task3",
            trigger: "manual",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: nil,
            startedAtEpoch: 1737795602
        )
        try await storage.addRun(noPid)
        
        let runningTasks = try await storage.getRunningTasks()
        #expect(runningTasks.count == 1)
        #expect(runningTasks[0].id == "running-1")
    }
    
    @Test("loadRunDetail returns nil for missing")
    func loadRunDetailMissing() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let loaded = try await storage.loadRunDetail(id: "nonexistent")
        #expect(loaded == nil)
    }
    
    @Test("loadRunDetail returns run as detail")
    func loadRunDetailReturnsRun() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // Create a completed run (exitCode is set)
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: "manual",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:01:00Z",
            pid: nil,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        let detail = try await storage.loadRunDetail(id: "test-1")
        #expect(detail != nil)
        #expect(detail?.id == "test-1")
        #expect(detail?.task == "heartbeat")
        #expect(detail?.trigger == "manual")
    }
    
    @Test("loadRunDetail returns nil for running task")
    func loadRunDetailNilForRunning() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // Create a running task (no exitCode)
        let run = RunSummary(
            id: "running-1",
            task: "heartbeat",
            trigger: "manual",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        let detail = try await storage.loadRunDetail(id: "running-1")
        #expect(detail == nil)
    }
    
    @Test("runs are ordered by started_at_epoch descending")
    func runsOrderedDescending() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // Add older run first
        let older = RunSummary(
            id: "older",
            task: "task1",
            trigger: "auto",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(older)
        
        // Add newer run
        let newer = RunSummary(
            id: "newer",
            task: "task2",
            trigger: "auto",
            exitCode: 0,
            startedAt: "2026-01-25T09:00:00Z",
            finishedAt: "2026-01-25T09:00:01Z",
            pid: nil,
            startedAtEpoch: 1737799200
        )
        try await storage.addRun(newer)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs.count == 2)
        #expect(index.runs[0].id == "newer") // Newer should be first
        #expect(index.runs[1].id == "older")
    }
    
    @Test("trigger defaults to manual if nil")
    func triggerDefaultsToManual() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // RunSummary with nil trigger
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            trigger: nil,
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await storage.addRun(run)
        
        let index = try await storage.loadRunsIndex()
        #expect(index.runs[0].trigger == "manual")
    }
}

// MARK: - SQLiteStorage ConfigRepository Tests

@Suite("SQLiteStorage Config Tests")
struct SQLiteStorageConfigTests {
    
    @Test("loadTasks returns empty for missing file")
    func loadTasksEmptyForMissing() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let tasks = try await storage.loadTasks()
        #expect(tasks.isEmpty)
    }
    
    @Test("loadSchedules returns empty for missing file")
    func loadSchedulesEmptyForMissing() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let schedules = try await storage.loadSchedules()
        #expect(schedules.isEmpty)
    }
}
