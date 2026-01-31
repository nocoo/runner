import Testing
@testable import RunnerLib

@Suite("TaskListService Tests")
struct TaskListServiceTests {
    final class StubTasksLoader: TasksLoading {
        let tasks: [Task]
        init(tasks: [Task]) { self.tasks = tasks }
        func loadTasks() async throws -> [Task] { tasks }
    }

    @Test("TaskListService maps tasks")
    func taskListMapsTasks() async throws {
        let tasks = [
            Task(id: "t1", executor: .shell, description: "A", timeout: 10, command: "echo", prompt: nil, workdir: nil),
            Task(id: "t2", executor: .shell, description: "B", timeout: 10, command: "echo", prompt: nil, workdir: nil)
        ]
        let service = TaskListService(loader: StubTasksLoader(tasks: tasks))
        let entries = try await service.list()

        #expect(entries.count == 2)
        #expect(entries[0].id == "t1")
        #expect(entries[1].description == "B")
    }
}
