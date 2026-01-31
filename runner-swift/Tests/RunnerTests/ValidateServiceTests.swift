import Testing
@testable import RunnerLib

@Suite("ValidateService Tests")
struct ValidateServiceTests {
    final class StubTasksLoader: TasksLoading {
        let tasks: [Task]
        init(tasks: [Task]) { self.tasks = tasks }
        func loadTasks() async throws -> [Task] { tasks }
    }

    final class StubSchedulesLoader: SchedulesLoading {
        let schedules: [Schedule]
        init(schedules: [Schedule]) { self.schedules = schedules }
        func loadSchedules() async throws -> [Schedule] { schedules }
    }

    @Test("ValidateService returns success when valid")
    func validateSuccess() async throws {
        let tasks = [Task(id: "t1", executor: .shell, description: "Task", timeout: 10, command: "echo", prompt: nil, workdir: nil)]
        let schedules = [Schedule(task: "t1", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))]

        let service = ValidateService(
            tasksLoader: StubTasksLoader(tasks: tasks),
            schedulesLoader: StubSchedulesLoader(schedules: schedules)
        )

        let result = try await service.validate()
        switch result {
        case .success(let summary):
            #expect(summary.taskCount == 1)
            #expect(summary.scheduleCount == 1)
        case .failure:
            #expect(Bool(false), "Expected success")
        }
    }

    @Test("ValidateService reports missing command and unknown schedule")
    func validateFailures() async throws {
        let tasks = [Task(id: "t1", executor: .shell, description: "Task", timeout: 10, command: nil, prompt: nil, workdir: nil)]
        let schedules = [Schedule(task: "missing", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))]

        let service = ValidateService(
            tasksLoader: StubTasksLoader(tasks: tasks),
            schedulesLoader: StubSchedulesLoader(schedules: schedules)
        )

        let result = try await service.validate()
        switch result {
        case .success:
            #expect(Bool(false), "Expected failures")
        case .failure(let error):
            #expect(error.issues.count == 2)
            #expect(error.issues.contains { $0.message.contains("no command") })
            #expect(error.issues.contains { $0.message.contains("unknown task") })
        }
    }

    @Test("ValidateService reports invalid http tasks")
    func validateHttpFailures() async throws {
        let tasks = [
            Task(id: "missing_url", executor: .http, description: "Missing URL", timeout: 10),
            Task(id: "bad_method", executor: .http, description: "Bad method", timeout: 10, url: "https://example.com", method: "TRACE"),
            Task(id: "get_with_body", executor: .http, description: "GET with body", timeout: 10, url: "https://example.com", method: "GET", body: "nope")
        ]
        let schedules: [Schedule] = []

        let service = ValidateService(
            tasksLoader: StubTasksLoader(tasks: tasks),
            schedulesLoader: StubSchedulesLoader(schedules: schedules)
        )

        let result = try await service.validate()
        switch result {
        case .success:
            #expect(Bool(false), "Expected failures")
        case .failure(let error):
            #expect(error.issues.count == 3)
            #expect(error.issues.contains { $0.message.contains("missing URL") })
            #expect(error.issues.contains { $0.message.contains("invalid method") })
            #expect(error.issues.contains { $0.message.contains("GET") && $0.message.contains("body") })
        }
    }
}
