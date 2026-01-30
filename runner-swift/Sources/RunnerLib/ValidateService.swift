import Foundation

public struct ValidationIssue: Sendable, Equatable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct ValidationSummary: Sendable {
    public let taskCount: Int
    public let scheduleCount: Int

    public init(taskCount: Int, scheduleCount: Int) {
        self.taskCount = taskCount
        self.scheduleCount = scheduleCount
    }
}

public struct ValidateService {
    private let tasksLoader: TasksLoading
    private let schedulesLoader: SchedulesLoading

    public init(tasksLoader: TasksLoading, schedulesLoader: SchedulesLoading) {
        self.tasksLoader = tasksLoader
        self.schedulesLoader = schedulesLoader
    }

    public func validate() async throws -> Result<ValidationSummary, ValidationError> {
        let tasks = try await tasksLoader.loadTasks()
        let schedules = try await schedulesLoader.loadSchedules()

        var issues: [ValidationIssue] = []

        for task in tasks {
            let hasCommand = task.command != nil && !(task.command ?? "").isEmpty
            let hasPrompt = task.prompt != nil && !(task.prompt ?? "").isEmpty
            if !hasCommand && !hasPrompt {
                issues.append(ValidationIssue(message: "Task '\(task.id)' has no command or prompt"))
            }
        }

        let taskIds = Set(tasks.map { $0.id })
        for schedule in schedules where !taskIds.contains(schedule.task) {
            issues.append(ValidationIssue(message: "Schedule references unknown task '\(schedule.task)'"))
        }

        if issues.isEmpty {
            return .success(ValidationSummary(taskCount: tasks.count, scheduleCount: schedules.count))
        }

        return .failure(ValidationError(issues: issues))
    }
}

public struct ValidationError: Error {
    public let issues: [ValidationIssue]

    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }
}
