import Testing
@testable import RunnerLib

@Suite("AutoService Tests")
struct AutoServiceTests {
    final class StubLoader: TaskLoading {
        let tasks: [Task]
        let schedules: [Schedule]

        init(tasks: [Task], schedules: [Schedule]) {
            self.tasks = tasks
            self.schedules = schedules
        }

        func loadTasks() async throws -> [Task] {
            tasks
        }

        func loadSchedules() async throws -> [Schedule] {
            schedules
        }
    }

    final class StubMonitor: TaskMonitoring {
        let interrupted: [String]

        init(interrupted: [String]) {
            self.interrupted = interrupted
        }

        func checkRunningTasks() async throws -> [String] {
            interrupted
        }
    }

    final class StubExecutor: TaskExecuting {
        private(set) var executed: [String] = []
        var shouldThrow: Bool = false

        func execute(task: Task, trigger: String) async throws -> ExecutionResult {
            executed.append(task.id)
            if shouldThrow {
                throw ExecutorError.missingCommand
            }
            return ExecutionResult(id: "run-\(task.id)", exitCode: 0, output: "ok")
        }
    }

    func makeTask(id: String) -> Task {
        Task(id: id, type: .simple, description: "Test", timeout: 60, command: "echo test", prompt: nil, workdir: nil)
    }

    func makeSchedule(task: String, hour: Any, minute: Any, weekday: Any) -> Schedule {
        Schedule(task: task, hour: AnyCodable(hour), minute: AnyCodable(minute), weekday: AnyCodable(weekday))
    }

    @Test("AutoService runs monitor and executes matched tasks")
    func autoServiceRunsTasks() async throws {
        let tasks = [makeTask(id: "t1"), makeTask(id: "t2")]
        let schedules = [
            makeSchedule(task: "t1", hour: 9, minute: 0, weekday: "*"),
            makeSchedule(task: "t2", hour: 9, minute: 0, weekday: "*"),
        ]

        let loader = StubLoader(tasks: tasks, schedules: schedules)
        let monitor = StubMonitor(interrupted: ["old-1"])
        let executor = StubExecutor()

        var logs: [String] = []
        var errors: [(String, Error)] = []

        let service = AutoService()
        try await service.run(
            storage: loader,
            monitor: monitor,
            executor: executor,
            time: AutoTime(hour: 9, minute: 0, weekday: 1),
            log: { logs.append($0) },
            onError: { taskId, error in errors.append((taskId, error)) }
        )

        #expect(Set(executor.executed) == Set(["t1", "t2"]))
        #expect(errors.isEmpty)
        #expect(logs.contains(where: { $0.contains("Marked 1 tasks") }))
    }

    @Test("AutoService logs when no tasks scheduled")
    func autoServiceNoTasks() async throws {
        let tasks = [makeTask(id: "t1")]
        let schedules = [makeSchedule(task: "t1", hour: 8, minute: 0, weekday: "*")]

        let loader = StubLoader(tasks: tasks, schedules: schedules)
        let monitor = StubMonitor(interrupted: [])
        let executor = StubExecutor()

        var logs: [String] = []

        let service = AutoService()
        try await service.run(
            storage: loader,
            monitor: monitor,
            executor: executor,
            time: AutoTime(hour: 9, minute: 0, weekday: 1),
            log: { logs.append($0) },
            onError: { _, _ in }
        )

        #expect(executor.executed.isEmpty)
        #expect(logs.contains("No tasks scheduled for current time"))
    }

    @Test("AutoService continues when a task fails")
    func autoServiceContinuesOnError() async throws {
        let tasks = [makeTask(id: "t1"), makeTask(id: "t2")]
        let schedules = [makeSchedule(task: "t1", hour: 9, minute: 0, weekday: "*"), makeSchedule(task: "t2", hour: 9, minute: 0, weekday: "*")]

        let loader = StubLoader(tasks: tasks, schedules: schedules)
        let monitor = StubMonitor(interrupted: [])
        let executor = StubExecutor()
        executor.shouldThrow = true

        var errors: [(String, Error)] = []

        let service = AutoService()
        try await service.run(
            storage: loader,
            monitor: monitor,
            executor: executor,
            time: AutoTime(hour: 9, minute: 0, weekday: 1),
            log: { _ in },
            onError: { taskId, error in errors.append((taskId, error)) }
        )

        #expect(Set(executor.executed) == Set(["t1", "t2"]))
        #expect(errors.count == 2)
    }
}
