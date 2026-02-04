import Testing
import Foundation
@testable import RunnerLib

@Suite("ApiService Tests")
struct ApiServiceTests {
    // MARK: - Stub Loaders

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

    final class StubRunDetailLoader: RunDetailLoading {
        let details: [String: RunDetail]
        init(details: [String: RunDetail] = [:]) { self.details = details }
        func loadRunDetail(id: String) async throws -> RunDetail? { details[id] }
    }

    // MARK: - Helper

    private func makeService(
        tasks: [Task] = [],
        schedules: [Schedule] = [],
        runs: RunsIndex = RunsIndex(runs: [], total: 0, updatedAt: ""),
        stateData: Data = Data("{}".utf8),
        runDetails: [String: RunDetail] = [:],
        initializer: StubInitializer = StubInitializer()
    ) -> ApiService {
        ApiService(
            tasksLoader: StubTasksLoader(tasks: tasks),
            schedulesLoader: StubSchedulesLoader(schedules: schedules),
            runsLoader: StubRunsLoader(index: runs),
            initializer: initializer,
            stateLoader: StubStateLoader(data: stateData),
            runDetailLoader: StubRunDetailLoader(details: runDetails)
        )
    }

    // MARK: - Tasks Tests

    @Test("ApiService returns tasks json")
    func apiServiceTasks() async throws {
        let task = Task(id: "t1", executor: .shell, description: "Task", timeout: nil, command: "echo", prompt: nil, workdir: nil)
        let service = makeService(tasks: [task])

        let output = try await service.handle(query: "tasks")
        #expect(output.contains("\"id\" : \"t1\""))
    }

    // MARK: - State Tests

    @Test("ApiService returns state")
    func apiServiceState() async throws {
        let service = makeService(stateData: Data("{\"ok\":true}".utf8))

        let output = try await service.handle(query: "state")
        #expect(output.contains("\"ok\":true"))
    }

    @Test("ApiService throws on invalid UTF-8 state")
    func apiServiceInvalidUTF8State() async throws {
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        let service = makeService(stateData: invalidData)

        do {
            _ = try await service.handle(query: "state")
            #expect(Bool(false), "Expected error")
        } catch {
            #expect(error is ApiServiceError)
        }
    }

    // MARK: - Init Tests

    @Test("ApiService init returns ok")
    func apiServiceInit() async throws {
        let initializer = StubInitializer()
        let service = ApiService(
            tasksLoader: StubTasksLoader(tasks: []),
            schedulesLoader: StubSchedulesLoader(schedules: []),
            runsLoader: StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: "")),
            initializer: initializer,
            stateLoader: StubStateLoader(data: Data("{}".utf8)),
            runDetailLoader: StubRunDetailLoader()
        )

        let output = try await service.handle(query: "init")
        #expect(output.contains("\"status\": \"ok\""))
        #expect(initializer.called)
    }

    // MARK: - Schedules Tests

    @Test("ApiService returns schedules json")
    func apiServiceSchedules() async throws {
        let schedules = [Schedule(task: "t1", hour: AnyCodable("*"), minute: AnyCodable(0), weekday: AnyCodable("*"))]
        let service = makeService(schedules: schedules)

        let output = try await service.handle(query: "schedules")
        #expect(output.contains("\"task\" : \"t1\""))
    }

    // MARK: - Runs Index Tests

    @Test("ApiService returns runs index")
    func apiServiceRuns() async throws {
        let run = RunSummary(id: "r1", task: "t1", exitCode: 0, startedAt: "2026-01-25T08:00:00Z", finishedAt: nil, pid: nil, startedAtEpoch: nil)
        let index = RunsIndex(runs: [run], total: 1, updatedAt: "")
        let service = makeService(runs: index)

        let output = try await service.handle(query: "runs")
        #expect(output.contains("\"id\" : \"r1\""))
    }

    // MARK: - Unknown Query Tests

    @Test("ApiService unknown query throws")
    func apiServiceUnknownQuery() async throws {
        let service = makeService()

        do {
            _ = try await service.handle(query: "unknown")
            #expect(Bool(false), "Expected error")
        } catch {
            #expect(error is RunnerError)
        }
    }

    @Test("ApiService run query without id throws")
    func apiServiceRunQueryNoId() async throws {
        let service = makeService()

        do {
            _ = try await service.handle(query: "run")
            #expect(Bool(false), "Expected error for missing run id")
        } catch {
            #expect(error is RunnerError)
        }
    }

    // MARK: - Run Detail Tests (Phase 7)

    @Test("ApiService returns run detail by id")
    func apiServiceRunDetail() async throws {
        let detail = RunDetail(
            id: "run-123",
            task: "heartbeat",
            trigger: "manual",
            startedAt: "2026-02-04T10:00:00Z",
            finishedAt: "2026-02-04T10:00:05Z",
            durationSeconds: 5,
            exitCode: 0
        )
        let service = makeService(runDetails: ["run-123": detail])

        let output = try await service.handle(query: .run(id: "run-123"))
        #expect(output.contains("\"id\" : \"run-123\""))
        #expect(output.contains("\"task\" : \"heartbeat\""))
        #expect(output.contains("\"exit_code\" : 0"))
        #expect(output.contains("\"duration_seconds\" : 5"))
    }

    @Test("ApiService returns null for missing run detail")
    func apiServiceRunDetailNotFound() async throws {
        let service = makeService()

        let output = try await service.handle(query: .run(id: "nonexistent"))
        #expect(output == "null")
    }

    @Test("ApiService run query with string parsing")
    func apiServiceRunQueryParsing() async throws {
        let detail = RunDetail(
            id: "abc-def-123",
            task: "test",
            trigger: "auto",
            startedAt: "2026-02-04T10:00:00Z",
            finishedAt: "2026-02-04T10:00:10Z",
            durationSeconds: 10,
            exitCode: 1
        )
        let service = makeService(runDetails: ["abc-def-123": detail])

        // Test parsing "run abc-def-123" as query string
        let output = try await service.handle(query: "run abc-def-123")
        #expect(output.contains("\"id\" : \"abc-def-123\""))
        #expect(output.contains("\"exit_code\" : 1"))
    }

    // MARK: - ApiQuery Parsing Tests

    @Test("ApiQuery parses simple queries")
    func apiQuerySimple() {
        #expect(ApiQuery(rawValue: "tasks") == .tasks)
        #expect(ApiQuery(rawValue: "schedules") == .schedules)
        #expect(ApiQuery(rawValue: "runs") == .runs)
        #expect(ApiQuery(rawValue: "status") == .status)
        #expect(ApiQuery(rawValue: "state") == .state)
        #expect(ApiQuery(rawValue: "init") == .initialize)
    }

    @Test("ApiQuery parses run with id")
    func apiQueryRunWithId() {
        let query = ApiQuery(rawValue: "run abc-123")
        #expect(query == .run(id: "abc-123"))
    }

    @Test("ApiQuery parses run with uuid")
    func apiQueryRunWithUuid() {
        let query = ApiQuery(rawValue: "run 7d90a1b7-bf18-4d38-9610-a465a6a82dcd")
        #expect(query == .run(id: "7d90a1b7-bf18-4d38-9610-a465a6a82dcd"))
    }

    @Test("ApiQuery returns nil for invalid queries")
    func apiQueryInvalid() {
        #expect(ApiQuery(rawValue: "unknown") == nil)
        #expect(ApiQuery(rawValue: "run") == nil)  // missing id
        #expect(ApiQuery(rawValue: "run ") == nil) // empty id
        #expect(ApiQuery(rawValue: "") == nil)
    }
}
