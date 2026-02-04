import ArgumentParser
import Foundation
import Darwin

enum ExitHandler {
    nonisolated(unsafe) static var handle: @Sendable (Int32) -> Void = { code in
        Darwin.exit(code)
    }

    static func exit(_ code: Int32) {
        handle(code)
    }
}

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
        _ = try await runAutoCommand(
            options: options,
            mockHour: mockHour,
            mockMinute: mockMinute,
            mockWeekday: mockWeekday
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
        let result = try await runTaskCommand(
            options: options,
            task: task,
            trigger: trigger
        )

        if !options.verbose {
            print(result.output)
        }

        ExitHandler.exit(Int32(result.exitCode))
        return
    }
}

public struct List: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "List tasks")

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        let lines = try await listTaskEntries(options: options)
        for line in lines {
            print(line)
        }
    }
}

public struct Validate: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Validate configuration")

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        let result = try await validateCommand(options: options)

        switch result {
        case .success(let summary):
            print("Configuration is valid")
            print("  Tasks: \(summary.taskCount)")
            print("  Schedules: \(summary.scheduleCount)")
        case .failure(let error):
            for issue in error.issues {
                FileHandle.standardError.write(Data("Error: \(issue.message)\n".utf8))
            }
            ExitHandler.exit(1)
            return
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
        let interrupted = try await monitorCommand(options: options)

        if interrupted.isEmpty {
            print("No interrupted tasks found")
        } else {
            print("Marked \(interrupted.count) tasks as interrupted:")
            for id in interrupted {
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
        let message = try await initCommandMessage(options: options)
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
        if list {
            let lines = try await logsListEntries(options: options, limit: 20)
            for line in lines {
                print(line)
            }
            return
        }

        let content = try await logsOutput(options: options, id: id, tail: tail)
        print(content)
    }
}

public struct Api: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "API queries")

    @OptionGroup var options: CommonOptions

    @Argument(parsing: .remaining, help: "Query: tasks, schedules, runs, run <id>, status, init")
    var queryArgs: [String]

    public init() {}

    public func run() async throws {
        let query = queryArgs.joined(separator: " ")
        let output = try await apiCommandOutput(options: options, query: query)
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
        let result = try await cleanupCommand(options: options, force: force)
        for line in result.lines {
            print(line)
        }
    }
}

public struct Complete: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Mark a run as completed (called by background scripts)"
    )

    @Argument(help: "Run ID")
    var id: String

    @Option(name: .long, help: "Exit code of the command")
    var exitCode: Int

    @Option(name: .long, help: "Duration in seconds")
    var duration: Int

    @OptionGroup var options: CommonOptions

    public init() {}

    public func run() async throws {
        try await completeCommand(options: options, id: id, exitCode: exitCode, duration: duration)
    }
}

public struct Migrate: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Migrate data from JSON storage to SQLite"
    )

    @OptionGroup var options: CommonOptions

    @Flag(name: .shortAndLong, help: "Force migration even if SQLite database exists")
    var force: Bool = false
    
    @Flag(name: .long, help: "Migrate tasks.json and schedules.json to SQLite")
    var config: Bool = false
    
    @Flag(name: .long, help: "Migrate state.json to SQLite")
    var state: Bool = false

    public init() {}

    public func run() async throws {
        let result = try await migrateCommand(options: options, force: force, config: config, state: state)
        for line in result.lines {
            print(line)
        }
    }
}

public struct MigrateResult: Sendable {
    public let lines: [String]
    public let success: Bool
}

public func migrateCommand(options: CommonOptions, force: Bool, config: Bool = false, state: Bool = false) async throws -> MigrateResult {
    let dataDir = options.dataDir
    var lines: [String] = []
    
    // Config migration mode
    if config {
        return try await migrateConfigCommand(dataDir: dataDir, force: force)
    }
    
    // State migration mode
    if state {
        return try await migrateStateCommand(dataDir: dataDir, force: force)
    }
    
    // Check if JSON index exists
    if !MigrationService.jsonIndexExists(in: dataDir) {
        lines.append("No JSON data found to migrate (runs/index.json does not exist)")
        return MigrateResult(lines: lines, success: true)
    }
    
    // Check if SQLite already exists
    if MigrationService.sqliteExists(in: dataDir) && !force {
        lines.append("SQLite database already exists: runner.db")
        lines.append("Use --force to overwrite")
        return MigrateResult(lines: lines, success: false)
    }
    
    // Perform migration
    lines.append("Migrating from JSON to SQLite...")
    
    let jsonStorage = Storage(dataDir: dataDir)
    let sqliteStorage = try SQLiteStorage(dataDir: dataDir)
    
    let result = try await MigrationService.migrate(from: jsonStorage, to: sqliteStorage)
    
    lines.append("Migrated \(result.runsCount) runs")
    
    if !result.errors.isEmpty {
        lines.append("Errors:")
        for error in result.errors {
            lines.append("  - \(error)")
        }
    }
    
    if result.success {
        lines.append("Migration completed successfully!")
    } else {
        lines.append("Migration completed with errors")
    }
    
    return MigrateResult(lines: lines, success: result.success)
}

/// Migrate tasks.json and schedules.json to SQLite
private func migrateConfigCommand(dataDir: URL, force: Bool) async throws -> MigrateResult {
    var lines: [String] = []
    
    // Check if tasks.json or schedules.json exists
    let hasTasksJson = MigrationService.tasksJsonExists(in: dataDir)
    let hasSchedulesJson = MigrationService.schedulesJsonExists(in: dataDir)
    
    if !hasTasksJson && !hasSchedulesJson {
        lines.append("No config files found to migrate (tasks.json and schedules.json do not exist)")
        return MigrateResult(lines: lines, success: true)
    }
    
    // Check if SQLite already has tasks
    let sqliteStorage = try SQLiteStorage(dataDir: dataDir)
    let hasTasksInDb = try await sqliteStorage.hasTasksInSQLite()
    
    if hasTasksInDb && !force {
        lines.append("SQLite database already contains tasks")
        lines.append("Use --force to overwrite")
        return MigrateResult(lines: lines, success: false)
    }
    
    // Perform migration
    lines.append("Migrating config from JSON to SQLite...")
    
    let jsonStorage = Storage(dataDir: dataDir)
    let result = try await MigrationService.migrateConfigToSQLite(from: jsonStorage, to: sqliteStorage)
    
    lines.append("Migrated \(result.tasksCount) tasks")
    lines.append("Migrated \(result.schedulesCount) schedules")
    
    if !result.errors.isEmpty {
        lines.append("Errors:")
        for error in result.errors {
            lines.append("  - \(error)")
        }
    }
    
    if result.success {
        lines.append("Config migration completed successfully!")
    } else {
        lines.append("Config migration completed with errors")
    }
    
    return MigrateResult(lines: lines, success: result.success)
}

/// Migrate state.json to SQLite
private func migrateStateCommand(dataDir: URL, force: Bool) async throws -> MigrateResult {
    var lines: [String] = []
    
    // Check if state.json exists
    if !MigrationService.stateJsonExists(in: dataDir) {
        lines.append("No state.json found to migrate")
        return MigrateResult(lines: lines, success: true)
    }
    
    // Check if SQLite already has state
    let sqliteStorage = try SQLiteStorage(dataDir: dataDir)
    let hasStateInDb = try await sqliteStorage.hasStateInSQLite()
    
    if hasStateInDb && !force {
        lines.append("SQLite database already contains state")
        lines.append("Use --force to overwrite")
        return MigrateResult(lines: lines, success: false)
    }
    
    // Perform migration
    lines.append("Migrating state from JSON to SQLite...")
    
    let result = try await MigrationService.migrateStateToSQLite(from: dataDir, to: sqliteStorage)
    
    if result.migrated {
        lines.append("State migrated successfully!")
    } else {
        for error in result.errors {
            lines.append("Error: \(error)")
        }
    }
    
    return MigrateResult(lines: lines, success: result.success)
}

public func runAutoCommand(
    options: CommonOptions,
    mockHour: Int?,
    mockMinute: Int?,
    mockWeekday: Int?
) async throws -> AutoTime {
    let wiring = try AutoWiring(options: options)

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

    return time
}

public func runTaskCommand(
    options: CommonOptions,
    task: String,
    trigger: String
) async throws -> ExecutionResult {
    let wiring = try RunWiring(options: options)
    let service = RunService()
    return try await service.run(
        storage: wiring.storage,
        executor: wiring.executor,
        taskId: task,
        trigger: trigger,
        log: { message in options.log(message) }
    )
}

public func listTaskEntries(options: CommonOptions) async throws -> [String] {
    let wiring = try ListWiring(options: options)
    let service = TaskListService(loader: wiring.storage)
    let entries = try await service.list()
    return entries.map { "\($0.id): \($0.description)" }
}

public func validateCommand(options: CommonOptions) async throws -> Result<ValidationSummary, ValidationError> {
    let wiring = try ValidateWiring(options: options)
    let service = ValidateService(tasksLoader: wiring.storage, schedulesLoader: wiring.storage)
    return try await service.validate()
}

public func monitorCommand(options: CommonOptions) async throws -> [String] {
    let wiring = try MonitorWiring(options: options)
    let service = MonitorService(monitor: wiring.monitor)
    let result = try await service.check()
    return result.interrupted
}

public func initCommandMessage(options: CommonOptions) async throws -> String {
    let wiring = try InitWiring(options: options)
    let service = InitService(initializer: wiring.storage, dataDir: options.dataDir)
    return try await service.run()
}

public func logsListEntries(options: CommonOptions, limit: Int) async throws -> [String] {
    let wiring = try LogsWiring(options: options)
    let service = LogService(dataDir: options.dataDir, loader: wiring.storage)
    let entries = try await service.listRuns(limit: limit)
    return entries.map { "\($0.status) \($0.id) \($0.task) \($0.startedAt)" }
}

public func logsOutput(options: CommonOptions, id: String?, tail: Int?) async throws -> String {
    let wiring = try LogsWiring(options: options)
    let service = LogService(dataDir: options.dataDir, loader: wiring.storage)
    return try await service.output(runId: id, tail: tail)
}

public func apiCommandOutput(options: CommonOptions, query: String) async throws -> String {
    let wiring = try ApiWiring(options: options)
    let service = ApiService(
        tasksLoader: wiring.storage,
        schedulesLoader: wiring.storage,
        runsLoader: wiring.storage,
        initializer: wiring.storage,
        stateLoader: wiring.stateLoader,
        runDetailLoader: wiring.storage
    )
    return try await service.handle(query: query)
}

public struct CleanupCommandResult: Sendable {
    public let lines: [String]
}

public func cleanupCommand(options: CommonOptions, force: Bool) async throws -> CleanupCommandResult {
    let wiring = try CleanupWiring(options: options)
    let index = try await wiring.storage.loadRunsIndex()

    let planner = CleanupPlanner()
    let plan = try await planner.buildPlan(
        index: index,
        detailLoader: wiring.storage,
        processInspector: DefaultProcessInspector()
    )

    var lines: [String] = []

    if plan.staleRuns.isEmpty {
        lines.append("No stale runs found")
        return CleanupCommandResult(lines: lines)
    }

    lines.append("Found \(plan.staleRuns.count) stale run(s):\n")

    for process in plan.processesToKill {
        lines.append("  ⚠️  \(process.id) [\(process.task)] PID \(process.pid) - orphaned (PPID=1), started \(process.startedAt)")
    }

    for process in plan.runningProcesses {
        lines.append("  ⋯  \(process.id) [\(process.task)] PID \(process.pid) - still running, started \(process.startedAt)")
    }

    for run in plan.runsToMark {
        lines.append("  ✗  \(run.id) [\(run.task)] - \(run.reason)")
    }

    lines.append("")

    if !force {
        lines.append("Dry run mode. Use --force to:")
        if !plan.processesToKill.isEmpty {
            lines.append("  - Kill \(plan.processesToKill.count) orphaned process(es)")
        }
        if !plan.runsToMark.isEmpty {
            lines.append("  - Mark \(plan.runsToMark.count) run(s) as interrupted")
        }
        return CleanupCommandResult(lines: lines)
    }

    // Kill orphaned processes
    var runsToMark = plan.runsToMark
    for proc in plan.processesToKill {
        lines.append("Killing PID \(proc.pid)...")
        kill(Int32(proc.pid), SIGTERM)
        usleep(500_000) // Wait 0.5s
        kill(Int32(proc.pid), SIGKILL)
        runsToMark.append(CleanupRun(id: proc.id, task: proc.task, reason: "killed"))
    }

    // Mark all as interrupted
    for run in runsToMark {
        try await wiring.storage.markInterrupted(id: run.id)
        lines.append("Marked \(run.id) as interrupted")
    }

    lines.append("\n✅ Cleanup complete")
    return CleanupCommandResult(lines: lines)
}

public func completeCommand(options: CommonOptions, id: String, exitCode: Int, duration: Int) async throws {
    let storage = try SQLiteStorage(dataDir: options.dataDir)
    try await storage.completeRun(id: id, exitCode: exitCode, duration: duration)
}

public struct RunnerRoot: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "runner",
        abstract: "Declarative task scheduler for macOS",
        subcommands: [Auto.self, Run.self, List.self, Validate.self, MonitorCommand.self, Init.self, Logs.self, Api.self, Cleanup.self, Complete.self]
    )

    public init() {}
}
