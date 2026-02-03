import Testing
import Foundation
@testable import RunnerLib

// MARK: - Mock Implementations

/// In-memory mock implementation of RunRepository for testing
actor MockRunRepository: RunRepository {
    var runsIndex: RunsIndex
    var runDetails: [String: RunDetail] = [:]
    var outputs: [String: String] = [:]
    
    // Call tracking for verification
    var addRunCalls: [RunSummary] = []
    var updateRunCalls: [(id: String, exitCode: Int?, finishedAt: String?)] = []
    var markInterruptedCalls: [String] = []
    var completeRunCalls: [(id: String, exitCode: Int, duration: Int)] = []
    
    init(runsIndex: RunsIndex = RunsIndex(runs: [], total: 0, updatedAt: "")) {
        self.runsIndex = runsIndex
    }
    
    func loadRunsIndex() async throws -> RunsIndex {
        return runsIndex
    }
    
    func addRun(_ run: RunSummary) async throws {
        addRunCalls.append(run)
        runsIndex.runs.append(run)
        runsIndex.total = runsIndex.runs.count
    }
    
    func updateRun(id: String, exitCode: Int?, finishedAt: String?) async throws {
        updateRunCalls.append((id: id, exitCode: exitCode, finishedAt: finishedAt))
        if let idx = runsIndex.runs.firstIndex(where: { $0.id == id }) {
            if let code = exitCode {
                runsIndex.runs[idx].exitCode = code
            }
            if let finished = finishedAt {
                runsIndex.runs[idx].finishedAt = finished
            }
            runsIndex.runs[idx].pid = nil
        }
    }
    
    func markInterrupted(id: String) async throws {
        markInterruptedCalls.append(id)
        try await updateRun(id: id, exitCode: -1, finishedAt: ISO8601DateFormatter().string(from: Date()))
    }
    
    func completeRun(id: String, exitCode: Int, duration: Int) async throws {
        completeRunCalls.append((id: id, exitCode: exitCode, duration: duration))
        let finishedAt = ISO8601DateFormatter().string(from: Date())
        try await updateRun(id: id, exitCode: exitCode, finishedAt: finishedAt)
        
        // Get the run info to create detail
        if let run = runsIndex.runs.first(where: { $0.id == id }) {
            let detail = RunDetail(
                id: id,
                task: run.task,
                trigger: "auto",
                startedAt: run.startedAt,
                finishedAt: finishedAt,
                durationSeconds: duration,
                exitCode: exitCode
            )
            try await writeRunDetail(detail)
        }
    }
    
    func getRunningTasks() async throws -> [RunSummary] {
        return runsIndex.runs.filter { $0.exitCode == nil && $0.pid != nil }
    }
    
    func writeRunDetail(_ detail: RunDetail) async throws {
        runDetails[detail.id] = detail
    }
    
    func loadRunDetail(id: String) async throws -> RunDetail? {
        return runDetails[id]
    }
    
    func writeOutput(id: String, content: String) async throws {
        outputs[id] = content
    }
    
    func appendOutput(id: String, content: String) async throws {
        if let existing = outputs[id] {
            outputs[id] = existing + content
        } else {
            outputs[id] = content
        }
    }
}

/// In-memory mock implementation of ConfigRepository for testing
actor MockConfigRepository: ConfigRepository {
    var tasks: [Task] = []
    var schedules: [Schedule] = []
    var initializeCalled = false
    
    init(tasks: [Task] = [], schedules: [Schedule] = []) {
        self.tasks = tasks
        self.schedules = schedules
    }
    
    func initialize() async throws {
        initializeCalled = true
    }
    
    func loadTasks() async throws -> [Task] {
        return tasks
    }
    
    func loadSchedules() async throws -> [Schedule] {
        return schedules
    }
}

// MARK: - RunRepository Protocol Tests

@Suite("RunRepository Protocol Tests")
struct RunRepositoryTests {
    
    @Test("Mock implements RunRepository protocol")
    func mockImplementsProtocol() async throws {
        let mock: any RunRepository = MockRunRepository()
        
        // Verify protocol conformance by calling all methods
        let index = try await mock.loadRunsIndex()
        #expect(index.runs.isEmpty)
        #expect(index.total == 0)
    }
    
    @Test("addRun adds to index")
    func addRunAddsToIndex() async throws {
        let mock = MockRunRepository()
        
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        
        try await mock.addRun(run)
        
        let index = try await mock.loadRunsIndex()
        #expect(index.runs.count == 1)
        #expect(index.runs[0].id == "test-1")
        #expect(index.total == 1)
    }
    
    @Test("updateRun modifies existing run")
    func updateRunModifiesExisting() async throws {
        let mock = MockRunRepository()
        
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        try await mock.addRun(run)
        
        try await mock.updateRun(id: "test-1", exitCode: 0, finishedAt: "2026-01-25T08:00:05Z")
        
        let index = try await mock.loadRunsIndex()
        #expect(index.runs[0].exitCode == 0)
        #expect(index.runs[0].finishedAt == "2026-01-25T08:00:05Z")
        #expect(index.runs[0].pid == nil) // Should be cleared
    }
    
    @Test("markInterrupted sets exit code to -1")
    func markInterruptedSetsExitCode() async throws {
        let mock = MockRunRepository()
        
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        try await mock.addRun(run)
        
        try await mock.markInterrupted(id: "test-1")
        
        let index = try await mock.loadRunsIndex()
        #expect(index.runs[0].exitCode == -1)
        #expect(index.runs[0].finishedAt != nil)
    }
    
    @Test("getRunningTasks filters correctly")
    func getRunningTasksFilters() async throws {
        let mock = MockRunRepository()
        
        // Running task (no exitCode, has pid)
        let running = RunSummary(
            id: "running-1",
            task: "task1",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: nil
        )
        try await mock.addRun(running)
        
        // Completed task
        let completed = RunSummary(
            id: "completed-1",
            task: "task2",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: nil
        )
        try await mock.addRun(completed)
        
        // Task without pid (not running)
        let noPid = RunSummary(
            id: "no-pid",
            task: "task3",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: nil,
            startedAtEpoch: nil
        )
        try await mock.addRun(noPid)
        
        let runningTasks = try await mock.getRunningTasks()
        #expect(runningTasks.count == 1)
        #expect(runningTasks[0].id == "running-1")
    }
    
    @Test("writeRunDetail and loadRunDetail")
    func runDetailOperations() async throws {
        let mock = MockRunRepository()
        
        let detail = RunDetail(
            id: "test-1",
            task: "heartbeat",
            trigger: "manual",
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:05Z",
            durationSeconds: 5,
            exitCode: 0
        )
        
        try await mock.writeRunDetail(detail)
        let loaded = try await mock.loadRunDetail(id: "test-1")
        
        #expect(loaded != nil)
        #expect(loaded?.id == "test-1")
        #expect(loaded?.exitCode == 0)
    }
    
    @Test("loadRunDetail returns nil for missing")
    func loadRunDetailMissing() async throws {
        let mock = MockRunRepository()
        
        let loaded = try await mock.loadRunDetail(id: "nonexistent")
        #expect(loaded == nil)
    }
    
    @Test("writeOutput and appendOutput")
    func outputOperations() async throws {
        let mock = MockRunRepository()
        
        try await mock.writeOutput(id: "test-1", content: "Line 1\n")
        try await mock.appendOutput(id: "test-1", content: "Line 2\n")
        
        let output = await mock.outputs["test-1"]
        #expect(output == "Line 1\nLine 2\n")
    }
    
    @Test("appendOutput creates if not exists")
    func appendOutputCreates() async throws {
        let mock = MockRunRepository()
        
        try await mock.appendOutput(id: "test-1", content: "First line\n")
        
        let output = await mock.outputs["test-1"]
        #expect(output == "First line\n")
    }
    
    @Test("completeRun updates run with exit code, duration and finished time")
    func completeRunUpdatesAll() async throws {
        let mock = MockRunRepository()
        
        // Add a running task
        let run = RunSummary(
            id: "test-1",
            task: "heartbeat",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await mock.addRun(run)
        
        // Complete it
        try await mock.completeRun(id: "test-1", exitCode: 0, duration: 30)
        
        let index = try await mock.loadRunsIndex()
        #expect(index.runs[0].exitCode == 0)
        #expect(index.runs[0].finishedAt != nil)
        #expect(index.runs[0].pid == nil)
        
        // Check detail was written
        let detail = try await mock.loadRunDetail(id: "test-1")
        #expect(detail != nil)
        #expect(detail?.exitCode == 0)
        #expect(detail?.durationSeconds == 30)
    }
    
    @Test("completeRun with non-zero exit code")
    func completeRunWithFailure() async throws {
        let mock = MockRunRepository()
        
        let run = RunSummary(
            id: "test-1",
            task: "failing-task",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await mock.addRun(run)
        
        try await mock.completeRun(id: "test-1", exitCode: 1, duration: 5)
        
        let index = try await mock.loadRunsIndex()
        #expect(index.runs[0].exitCode == 1)
    }
    
    @Test("completeRun with timeout exit code 124")
    func completeRunWithTimeout() async throws {
        let mock = MockRunRepository()
        
        let run = RunSummary(
            id: "test-1",
            task: "slow-task",
            exitCode: nil,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: 12345,
            startedAtEpoch: 1737795600
        )
        try await mock.addRun(run)
        
        try await mock.completeRun(id: "test-1", exitCode: 124, duration: 300)
        
        let index = try await mock.loadRunsIndex()
        #expect(index.runs[0].exitCode == 124)
        
        let detail = try await mock.loadRunDetail(id: "test-1")
        #expect(detail?.durationSeconds == 300)
    }
}

// MARK: - ConfigRepository Protocol Tests

@Suite("ConfigRepository Protocol Tests")
struct ConfigRepositoryTests {
    
    @Test("Mock implements ConfigRepository protocol")
    func mockImplementsProtocol() async throws {
        let mock: any ConfigRepository = MockConfigRepository()
        
        try await mock.initialize()
        let tasks = try await mock.loadTasks()
        let schedules = try await mock.loadSchedules()
        
        #expect(tasks.isEmpty)
        #expect(schedules.isEmpty)
    }
    
    @Test("loadTasks returns configured tasks")
    func loadTasksReturns() async throws {
        let task = Task(
            id: "test-task",
            executor: .shell,
            description: "Test",
            timeout: 60,
            command: "echo hello",
            prompt: nil,
            workdir: nil
        )
        let mock = MockConfigRepository(tasks: [task])
        
        let loaded = try await mock.loadTasks()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "test-task")
    }
    
    @Test("loadSchedules returns configured schedules")
    func loadSchedulesReturns() async throws {
        let schedule = Schedule(task: "test-task", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))
        let mock = MockConfigRepository(schedules: [schedule])
        
        let loaded = try await mock.loadSchedules()
        #expect(loaded.count == 1)
        #expect(loaded[0].task == "test-task")
    }
    
    @Test("initialize is called")
    func initializeIsCalled() async throws {
        let mock = MockConfigRepository()
        
        #expect(await mock.initializeCalled == false)
        try await mock.initialize()
        #expect(await mock.initializeCalled == true)
    }
}
