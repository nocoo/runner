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

// MARK: - SQLiteStorage Tasks & Schedules Tests (Phase 5)

@Suite("SQLiteStorage Tasks Tests")
struct SQLiteStorageTasksTests {
    
    @Test("saveTask inserts new task")
    func saveTaskInsertsNew() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let task = Task(
            id: "heartbeat",
            executor: .shell,
            description: "Play sound",
            timeout: 10,
            command: "afplay /System/Library/Sounds/Pop.aiff"
        )
        
        try await storage.saveTask(task)
        
        let tasks = try await storage.loadTasks()
        #expect(tasks.count == 1)
        #expect(tasks[0].id == "heartbeat")
        #expect(tasks[0].executor == .shell)
        #expect(tasks[0].description == "Play sound")
        #expect(tasks[0].timeout == 10)
        #expect(tasks[0].command == "afplay /System/Library/Sounds/Pop.aiff")
    }
    
    @Test("saveTask updates existing task")
    func saveTaskUpdatesExisting() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let task1 = Task(id: "t1", executor: .shell, description: "v1", command: "echo 1")
        try await storage.saveTask(task1)
        
        let task2 = Task(id: "t1", executor: .shell, description: "v2", command: "echo 2")
        try await storage.saveTask(task2)
        
        let tasks = try await storage.loadTasks()
        #expect(tasks.count == 1)
        #expect(tasks[0].description == "v2")
        #expect(tasks[0].command == "echo 2")
    }
    
    @Test("saveTask with opencode executor")
    func saveTaskOpencode() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let task = Task(
            id: "clock",
            executor: .opencode,
            description: "Report time",
            timeout: 60,
            prompt: "Get current time and say it",
            workdir: "/tmp"
        )
        
        try await storage.saveTask(task)
        
        let tasks = try await storage.loadTasks()
        #expect(tasks[0].executor == .opencode)
        #expect(tasks[0].prompt == "Get current time and say it")
        #expect(tasks[0].workdir == "/tmp")
    }
    
    @Test("saveTask with http executor")
    func saveTaskHttp() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let task = Task(
            id: "ping",
            executor: .http,
            description: "Ping website",
            timeout: 30,
            url: "https://example.com",
            method: "GET",
            headers: ["Authorization": "Bearer token"],
            body: nil
        )
        
        try await storage.saveTask(task)
        
        let tasks = try await storage.loadTasks()
        #expect(tasks[0].executor == .http)
        #expect(tasks[0].url == "https://example.com")
        #expect(tasks[0].method == "GET")
        #expect(tasks[0].headers?["Authorization"] == "Bearer token")
    }
    
    @Test("deleteTask removes task")
    func deleteTaskRemoves() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let task = Task(id: "t1", executor: .shell, description: "test", command: "echo")
        try await storage.saveTask(task)
        
        try await storage.deleteTask(id: "t1")
        
        let tasks = try await storage.loadTasks()
        #expect(tasks.isEmpty)
    }
    
    @Test("loadTask returns single task by id")
    func loadTaskById() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        try await storage.saveTask(Task(id: "t1", executor: .shell, description: "first", command: "echo 1"))
        try await storage.saveTask(Task(id: "t2", executor: .shell, description: "second", command: "echo 2"))
        
        let task = try await storage.loadTask(id: "t2")
        #expect(task?.id == "t2")
        #expect(task?.description == "second")
    }
    
    @Test("loadTask returns nil for missing")
    func loadTaskMissing() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        let task = try await storage.loadTask(id: "nonexistent")
        #expect(task == nil)
    }
}

@Suite("SQLiteStorage Schedules Tests")
struct SQLiteStorageSchedulesTests {
    
    @Test("addSchedule inserts new schedule")
    func addScheduleInserts() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        // First add a task (schedules reference tasks)
        try await storage.saveTask(Task(id: "heartbeat", executor: .shell, description: "test", command: "echo"))
        
        let schedule = Schedule(
            task: "heartbeat",
            hour: AnyCodable(10),
            minute: AnyCodable(30),
            weekday: AnyCodable("*")
        )
        
        try await storage.addSchedule(schedule)
        
        let schedules = try await storage.loadSchedules()
        #expect(schedules.count == 1)
        #expect(schedules[0].task == "heartbeat")
    }
    
    @Test("addSchedule with wildcard hour")
    func addScheduleWildcardHour() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        try await storage.saveTask(Task(id: "t1", executor: .shell, description: "test", command: "echo"))
        
        let schedule = Schedule(
            task: "t1",
            hour: AnyCodable("*"),
            minute: AnyCodable(0),
            weekday: AnyCodable("*")
        )
        
        try await storage.addSchedule(schedule)
        
        let schedules = try await storage.loadSchedules()
        #expect(schedules.count == 1)
        // Hour should be stored as "*"
        if let hourInt = schedules[0].hour.value as? Int {
            #expect(Bool(false), "Hour should be string, not int: \(hourInt)")
        }
    }
    
    @Test("multiple schedules for same task")
    func multipleSchedulesSameTask() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        try await storage.saveTask(Task(id: "t1", executor: .shell, description: "test", command: "echo"))
        
        try await storage.addSchedule(Schedule(task: "t1", hour: AnyCodable(9), minute: AnyCodable(0), weekday: AnyCodable("*")))
        try await storage.addSchedule(Schedule(task: "t1", hour: AnyCodable(17), minute: AnyCodable(0), weekday: AnyCodable("*")))
        
        let schedules = try await storage.loadSchedules()
        #expect(schedules.count == 2)
    }
    
    @Test("deleteSchedulesForTask removes all schedules")
    func deleteSchedulesForTask() async throws {
        let storage = try SQLiteStorage(inMemory: true)
        
        try await storage.saveTask(Task(id: "t1", executor: .shell, description: "test", command: "echo"))
        try await storage.saveTask(Task(id: "t2", executor: .shell, description: "test2", command: "echo2"))
        
        try await storage.addSchedule(Schedule(task: "t1", hour: AnyCodable(9), minute: AnyCodable(0), weekday: AnyCodable("*")))
        try await storage.addSchedule(Schedule(task: "t1", hour: AnyCodable(17), minute: AnyCodable(0), weekday: AnyCodable("*")))
        try await storage.addSchedule(Schedule(task: "t2", hour: AnyCodable(12), minute: AnyCodable(0), weekday: AnyCodable("*")))
        
        try await storage.deleteSchedulesForTask(id: "t1")
        
        let schedules = try await storage.loadSchedules()
        #expect(schedules.count == 1)
        #expect(schedules[0].task == "t2")
    }
}
