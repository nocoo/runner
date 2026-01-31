import Testing
import Foundation
@testable import RunnerLib

@Suite("ApiService Tests")
struct ApiServiceTests {
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

    final class StubRunsLoader: RunsIndexLoading {
        let index: RunsIndex
        init(index: RunsIndex) { self.index = index }
        func loadRunsIndex() async throws -> RunsIndex { index }
    }

    final class StubInitializer: Initializing {
        private(set) var called = false
        func initialize() async throws { called = true }
    }

    final class StubStateLoader: StateLoading {
        let data: Data
        init(data: Data) { self.data = data }
        func readStateData() throws -> Data { data }
    }

    @Test("ApiService returns tasks json")
    func apiServiceTasks() async throws {
        let service = ApiService(
            tasksLoader: StubTasksLoader(tasks: [Task(id: "t1", executor: .shell, description: "Task", timeout: nil, command: "echo", prompt: nil, workdir: nil)]),
            schedulesLoader: StubSchedulesLoader(schedules: []),
            runsLoader: StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: "")),
            initializer: StubInitializer(),
            stateLoader: StubStateLoader(data: Data("{}".utf8))
        )

        let output = try await service.handle(query: "tasks")
        #expect(output.contains("\"id\" : \"t1\""))
    }

    @Test("ApiService returns state")
    func apiServiceState() async throws {
        let service = ApiService(
            tasksLoader: StubTasksLoader(tasks: []),
            schedulesLoader: StubSchedulesLoader(schedules: []),
            runsLoader: StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: "")),
            initializer: StubInitializer(),
            stateLoader: StubStateLoader(data: Data("{\"ok\":true}".utf8))
        )

        let output = try await service.handle(query: "state")
        #expect(output.contains("\"ok\":true"))
    }

    @Test("ApiService init returns ok")
    func apiServiceInit() async throws {
        let initializer = StubInitializer()
        let service = ApiService(
            tasksLoader: StubTasksLoader(tasks: []),
            schedulesLoader: StubSchedulesLoader(schedules: []),
            runsLoader: StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: "")),
            initializer: initializer,
            stateLoader: StubStateLoader(data: Data("{}".utf8))
        )

        let output = try await service.handle(query: "init")
        #expect(output.contains("\"status\": \"ok\""))
    }

    @Test("ApiService unknown query throws")
    func apiServiceUnknownQuery() async throws {
        let service = ApiService(
            tasksLoader: StubTasksLoader(tasks: []),
            schedulesLoader: StubSchedulesLoader(schedules: []),
            runsLoader: StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: "")),
            initializer: StubInitializer(),
            stateLoader: StubStateLoader(data: Data("{}".utf8))
        )

        do {
            _ = try await service.handle(query: "unknown")
            #expect(Bool(false), "Expected error")
        } catch {
            #expect(error is RunnerError)
        }
    }

    @Test("ApiService throws on invalid UTF-8 state")
    func apiServiceInvalidUTF8State() async throws {
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        let service = ApiService(
            tasksLoader: StubTasksLoader(tasks: []),
            schedulesLoader: StubSchedulesLoader(schedules: []),
            runsLoader: StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: "")),
            initializer: StubInitializer(),
            stateLoader: StubStateLoader(data: invalidData)
        )

        do {
            _ = try await service.handle(query: "state")
            #expect(Bool(false), "Expected error")
        } catch {
            #expect(error is ApiServiceError)
        }
    }
}
