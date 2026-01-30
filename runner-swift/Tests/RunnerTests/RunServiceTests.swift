import Testing
@testable import RunnerLib

@Suite("RunService Tests")
struct RunServiceTests {
    final class StubLoader: TaskLoading {
        let tasks: [Task]

        init(tasks: [Task]) {
            self.tasks = tasks
        }

        func loadTasks() async throws -> [Task] {
            tasks
        }

        func loadSchedules() async throws -> [Schedule] {
            []
        }
    }

    final class StubExecutor: TaskExecuting {
        private(set) var executed: [String] = []

        func execute(task: Task, trigger: String) async throws -> ExecutionResult {
            executed.append("\(task.id):\(trigger)")
            return ExecutionResult(id: "run-\(task.id)", exitCode: 0, output: "ok")
        }
    }

    func makeTask(id: String) -> Task {
        Task(id: id, type: .simple, description: "Test", timeout: 60, command: "echo test", prompt: nil, workdir: nil)
    }

    @Test("RunService executes requested task")
    func runServiceExecutesTask() async throws {
        let loader = StubLoader(tasks: [makeTask(id: "t1")])
        let executor = StubExecutor()

        var logs: [String] = []

        let service = RunService()
        let result = try await service.run(
            storage: loader,
            executor: executor,
            taskId: "t1",
            trigger: "manual",
            log: { logs.append($0) }
        )

        #expect(result.exitCode == 0)
        #expect(executor.executed == ["t1:manual"])
        #expect(logs.contains("Executing task: t1"))
    }

    @Test("RunService throws when task missing")
    func runServiceMissingTask() async throws {
        let loader = StubLoader(tasks: [makeTask(id: "t1")])
        let executor = StubExecutor()

        let service = RunService()

        do {
            _ = try await service.run(
                storage: loader,
                executor: executor,
                taskId: "nope",
                trigger: "manual",
                log: { _ in }
            )
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is RunnerError)
        }
    }
}
