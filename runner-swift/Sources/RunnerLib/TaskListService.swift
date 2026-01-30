import Foundation

public struct TaskListEntry: Sendable {
    public let id: String
    public let description: String
}

public struct TaskListService {
    private let loader: TasksLoading

    public init(loader: TasksLoading) {
        self.loader = loader
    }

    public func list() async throws -> [TaskListEntry] {
        let tasks = try await loader.loadTasks()
        return tasks.map { TaskListEntry(id: $0.id, description: $0.description) }
    }
}
