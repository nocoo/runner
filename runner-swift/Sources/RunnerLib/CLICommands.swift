import ArgumentParser
import Foundation
import Darwin

public struct Auto: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Run scheduled tasks based on current time")

    @OptionGroup var options: CommonOptions

    @Option(help: "Mock hour (for testing)")
    var mockHour: Int?

    @Option(help: "Mock minute (for testing)")
    var mockMinute: Int?

    @Option(help: "Mock weekday (0=Sun)")
    var mockWeekday: Int?

    public init() {}

    public func run() async throws {
        let wiring = AutoWiring(options: options)

        // Get current time (UTC+8)
        let now = Date()
        let calendar = Calendar.current
        let tz = TimeZone(secondsFromGMT: 8 * 3600)!
        let components = calendar.dateComponents(in: tz, from: now)

        let hour = mockHour ?? components.hour!
        let minute = mockMinute ?? components.minute!
        let weekday = mockWeekday ?? (components.weekday! - 1) // Convert to 0=Sunday

        let service = AutoService()
        let time = AutoTime(hour: hour, minute: minute, weekday: weekday)

        try await service.run(
            storage: wiring.storage,
            monitor: wiring.monitor,
            executor: wiring.executor,
            time: time,
            log: { message in options.log(message) },
            onError: { taskId, error in
                FileHandle.standardError.write(Data("Error executing task \(taskId): \(error)\n".utf8))
            }
        )
    }
}

public struct Run: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Run a specific task")

    @OptionGroup var options: CommonOptions

    @Argument(help: "Task ID")
    var task: String

    @Option(name: .shortAndLong, help: "Trigger type")
    var trigger: String = "manual"

    public init() {}

    public func run() async throws {
        let wiring = RunWiring(options: options)

        let service = RunService()
        let result = try await service.run(
            storage: wiring.storage,
            executor: wiring.executor,
            taskId: task,
            trigger: trigger,
            log: { message in options.log(message) }
        )

        if !options.verbose {
            print(result.output)
        }

        Darwin.exit(Int32(result.exitCode))
    }
}

public struct List: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "List tasks")

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        let wiring = ListWiring(options: options)
        let service = TaskListService(loader: wiring.storage)
        let entries = try await service.list()
        for entry in entries {
            print("\(entry.id): \(entry.description)")
        }
    }
}

public struct Validate: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Validate configuration")

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        let wiring = ValidateWiring(options: options)
        let service = ValidateService(tasksLoader: wiring.storage, schedulesLoader: wiring.storage)
        let result = try await service.validate()

        switch result {
        case .success(let summary):
            print("Configuration is valid")
            print("  Tasks: \(summary.taskCount)")
            print("  Schedules: \(summary.scheduleCount)")
        case .failure(let error):
            for issue in error.issues {
                FileHandle.standardError.write(Data("Error: \(issue.message)\n".utf8))
            }
            Darwin.exit(1)
        }
    }
}

public struct MonitorCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "monitor",
        abstract: "Check running tasks and mark interrupted ones"
    )

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        let wiring = MonitorWiring(options: options)
        let service = MonitorService(monitor: wiring.monitor)
        let result = try await service.check()

        if result.interrupted.isEmpty {
            print("No interrupted tasks found")
        } else {
            print("Marked \(result.interrupted.count) tasks as interrupted:")
            for id in result.interrupted {
                print("  \(id)")
            }
        }
    }
}

public struct Init: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Initialize data directory")

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        let wiring = InitWiring(options: options)
        let service = InitService(initializer: wiring.storage, dataDir: options.dataDir)
        let message = try await service.run()
        print(message)
    }
}

public struct Logs: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Show logs for a task run")

    @OptionGroup var options: CommonOptions

    @Argument(help: "Run ID")
    var id: String?

    @Flag(name: .shortAndLong, help: "List all runs")
    var list: Bool = false

    @Option(name: .shortAndLong, help: "Show last N lines")
    var tail: Int?

    public init() {}

    public func run() async throws {
        let wiring = LogsWiring(options: options)
        let service = LogService(dataDir: options.dataDir, loader: wiring.storage)

        if list {
            let entries = try await service.listRuns(limit: 20)
            for entry in entries {
                print("\(entry.status) \(entry.id) \(entry.task) \(entry.startedAt)")
            }
            return
        }

        let content = try await service.output(runId: id, tail: tail)
        print(content)
    }
}

public struct Api: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "API queries")

    @OptionGroup var options: CommonOptions

    @Argument(help: "Query: tasks, schedules, runs, status, init")
    var query: String

    public init() {}

    public func run() async throws {
        let wiring = ApiWiring(options: options)
        let service = ApiService(
            tasksLoader: wiring.storage,
            schedulesLoader: wiring.storage,
            runsLoader: wiring.storage,
            initializer: wiring.storage,
            stateLoader: DefaultStateLoader(path: wiring.statePath)
        )

        let output = try await service.handle(query: query)
        print(output)
    }
}

public struct Cleanup: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Clean up stale runs and orphaned processes")

    @OptionGroup var options: CommonOptions

    @Flag(name: .shortAndLong, help: "Actually kill processes (default: dry run)")
    var force: Bool = false

    public init() {}

    public func run() async throws {
        let wiring = CleanupWiring(options: options)
        let index = try await wiring.storage.loadRunsIndex()

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: wiring.storage,
            processInspector: DefaultProcessInspector()
        )

        if plan.staleRuns.isEmpty {
            print("No stale runs found")
            return
        }

        print("Found \(plan.staleRuns.count) stale run(s):\n")

        for process in plan.processesToKill {
            print("  ⚠️  \(process.id) [\(process.task)] PID \(process.pid) - orphaned (PPID=1), started \(process.startedAt)")
        }

        for process in plan.runningProcesses {
            print("  ⋯  \(process.id) [\(process.task)] PID \(process.pid) - still running, started \(process.startedAt)")
        }

        for run in plan.runsToMark {
            print("  ✗  \(run.id) [\(run.task)] - \(run.reason)")
        }

        print("")

        if !force {
            print("Dry run mode. Use --force to:")
            if !plan.processesToKill.isEmpty {
                print("  - Kill \(plan.processesToKill.count) orphaned process(es)")
            }
            if !plan.runsToMark.isEmpty {
                print("  - Mark \(plan.runsToMark.count) run(s) as interrupted")
            }
            return
        }

        // Kill orphaned processes
        var runsToMark = plan.runsToMark
        for proc in plan.processesToKill {
            print("Killing PID \(proc.pid)...")
            kill(Int32(proc.pid), SIGTERM)
            usleep(500_000) // Wait 0.5s
            kill(Int32(proc.pid), SIGKILL)
            runsToMark.append(CleanupRun(id: proc.id, task: proc.task, reason: "killed"))
        }

        // Mark all as interrupted
        for run in runsToMark {
            try await wiring.storage.markInterrupted(id: run.id)
            print("Marked \(run.id) as interrupted")
        }

        print("\n✅ Cleanup complete")
    }
}
