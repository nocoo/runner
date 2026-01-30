import Foundation

public struct RunService {
    public init() {}

    public func run(
        storage: TaskLoading,
        executor: TaskExecuting,
        taskId: String,
        trigger: String,
        log: (String) -> Void
    ) async throws -> ExecutionResult {
        let tasks = try await storage.loadTasks()

        guard let task = tasks.first(where: { $0.id == taskId }) else {
            throw RunnerError.taskNotFound(taskId)
        }

        log("Executing task: \(task.id)")

        return try await executor.execute(task: task, trigger: trigger)
    }
}
