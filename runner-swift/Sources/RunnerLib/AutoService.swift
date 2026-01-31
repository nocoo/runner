import Foundation

public struct AutoTime: Sendable {
    public let hour: Int
    public let minute: Int
    public let weekday: Int

    public init(hour: Int, minute: Int, weekday: Int) {
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
    }
}

public protocol TaskLoading {
    func loadTasks() async throws -> [Task]
    func loadSchedules() async throws -> [Schedule]
}

public protocol TaskMonitoring {
    func checkRunningTasks() async throws -> [String]
}

public protocol TaskExecuting {
    func execute(task: Task, trigger: String) async throws -> ExecutionResult
}

extension Storage: TaskLoading {}
extension Monitor: TaskMonitoring {}
extension Executor: TaskExecuting {}

public struct AutoService {
    public init() {}

    public func run(
        storage: TaskLoading,
        monitor: TaskMonitoring,
        executor: TaskExecuting,
        time: AutoTime,
        log: (String) -> Void,
        onError: (String, Error) -> Void
    ) async throws {
        log("Running monitor to check stale tasks")
        let interrupted = try await monitor.checkRunningTasks()
        if !interrupted.isEmpty {
            log("Marked \(interrupted.count) tasks as interrupted")
        }

        let tasks = try await storage.loadTasks()
        let schedules = try await storage.loadSchedules()

        log("Current time: hour=\(time.hour), minute=\(time.minute), weekday=\(time.weekday)")

        let taskIds = Scheduler.findScheduledTasks(
            schedules: schedules,
            tasks: tasks,
            hour: time.hour,
            minute: time.minute,
            weekday: time.weekday
        )

        if taskIds.isEmpty {
            log("No tasks scheduled for current time")
            return
        }

        log("Found \(taskIds.count) task(s) to execute")

        for taskId in taskIds {
            if let task = tasks.first(where: { $0.id == taskId }) {
                log("Executing task: \(taskId)")
                do {
                    let result = try await executor.execute(task: task, trigger: "auto")
                    log("Task \(taskId) completed with exit code \(result.exitCode)")
                } catch {
                    onError(taskId, error)
                }
            }
        }
    }
}
