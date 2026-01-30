import Foundation
import ArgumentParser
import RunnerLib

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runner",
        abstract: "Declarative task scheduler for macOS",
        version: "0.1.0",
        subcommands: [Auto.self, Run.self, List.self, Validate.self, MonitorCommand.self, Init.self, Logs.self, Api.self, Cleanup.self]
    )
}

// MARK: - Auto Command

struct Auto: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run scheduled tasks based on current time")
    
    @OptionGroup var options: CommonOptions
    
    @Option(help: "Mock hour (for testing)")
    var mockHour: Int?
    
    @Option(help: "Mock minute (for testing)")
    var mockMinute: Int?
    
    @Option(help: "Mock weekday (0=Sun)")
    var mockWeekday: Int?
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)

        // Run monitor first
        let monitor = Monitor(storage: storage, verbose: options.verbose)

        // Get current time (UTC+8)
        let now = Date()
        let calendar = Calendar.current
        let tz = TimeZone(secondsFromGMT: 8 * 3600)!
        let components = calendar.dateComponents(in: tz, from: now)

        let hour = mockHour ?? components.hour!
        let minute = mockMinute ?? components.minute!
        let weekday = mockWeekday ?? (components.weekday! - 1) // Convert to 0=Sunday

        let executor = Executor(storage: storage, dryRun: options.dryRun, verbose: options.verbose)

        let service = AutoService()
        let time = AutoTime(hour: hour, minute: minute, weekday: weekday)

        try await service.run(
            storage: storage,
            monitor: monitor,
            executor: executor,
            time: time,
            log: { message in options.log(message) },
            onError: { taskId, error in
                FileHandle.standardError.write(Data("Error executing task \(taskId): \(error)\n".utf8))
            }
        )
    }
}

// MARK: - Run Command

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run a specific task")
    
    @OptionGroup var options: CommonOptions
    
    @Argument(help: "Task ID")
    var task: String
    
    @Option(name: .shortAndLong, help: "Trigger type")
    var trigger: String = "manual"
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let executor = Executor(storage: storage, dryRun: options.dryRun, verbose: options.verbose)

        let service = RunService()
        let result = try await service.run(
            storage: storage,
            executor: executor,
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

// MARK: - List Command

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List tasks")
    
    @OptionGroup var options: CommonOptions
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let tasks = try await storage.loadTasks()
        
        for task in tasks {
            print("\(task.id): \(task.description)")
        }
    }
}

// MARK: - Validate Command

struct Validate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Validate configuration")
    
    @OptionGroup var options: CommonOptions
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let tasks = try await storage.loadTasks()
        let schedules = try await storage.loadSchedules()
        
        // Validate tasks
        var errors: [String] = []
        for task in tasks {
            let hasCommand = task.command != nil && !task.command!.isEmpty
            let hasPrompt = task.prompt != nil && !task.prompt!.isEmpty
            if !hasCommand && !hasPrompt {
                errors.append("Task '\(task.id)' has no command or prompt")
            }
        }
        
        // Validate schedules
        let taskIds = Set(tasks.map { $0.id })
        for schedule in schedules where !taskIds.contains(schedule.task) {
            errors.append("Schedule references unknown task '\(schedule.task)'")
        }
        
        if errors.isEmpty {
            print("Configuration is valid")
            print("  Tasks: \(tasks.count)")
            print("  Schedules: \(schedules.count)")
        } else {
            for error in errors {
                FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            }
            Darwin.exit(1)
        }
    }
}

// MARK: - Monitor Command

struct MonitorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monitor",
        abstract: "Check running tasks and mark interrupted ones"
    )
    
    @OptionGroup var options: CommonOptions
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let monitor = Monitor(storage: storage, verbose: options.verbose)
        let interrupted = try await monitor.checkRunningTasks()
        
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

// MARK: - Init Command

struct Init: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Initialize data directory")
    
    @OptionGroup var options: CommonOptions
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        try await storage.initialize()
        print("Initialized data directory: \(options.dataDir.path)")
    }
}

// MARK: - Logs Command

struct Logs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show logs for a task run")
    
    @OptionGroup var options: CommonOptions
    
    @Argument(help: "Run ID")
    var id: String?
    
    @Flag(name: .shortAndLong, help: "List all runs")
    var list: Bool = false
    
    @Option(name: .shortAndLong, help: "Show last N lines")
    var tail: Int?
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let index = try await storage.loadRunsIndex()
        
        if list {
            for run in index.runs.suffix(20).reversed() {
                let status: String
                switch run.exitCode {
                case nil: status = "⋯"
                case 0: status = "✓"
                default: status = "✗"
                }
                print("\(status) \(run.id) \(run.task) \(run.startedAt)")
            }
            return
        }
        
        let runId: String
        if let id = id {
            runId = id
        } else if let last = index.runs.last {
            runId = last.id
        } else {
            throw RunnerError.noRunsFound
        }
        
        let outputPath = options.dataDir.appendingPathComponent("runs/\(runId).output")
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        
        if let n = tail {
            let lines = content.components(separatedBy: "\n")
            let start = max(0, lines.count - n)
            print(lines[start...].joined(separator: "\n"))
        } else {
            print(content)
        }
    }
}

// MARK: - API Command

struct Api: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "API queries")
    
    @OptionGroup var options: CommonOptions
    
    @Argument(help: "Query: tasks, schedules, runs, status, init")
    var query: String
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        switch query {
        case "tasks":
            let tasks = try await storage.loadTasks()
            let data = try encoder.encode(tasks)
            print(String(data: data, encoding: .utf8)!)
        case "schedules":
            let schedules = try await storage.loadSchedules()
            let data = try encoder.encode(schedules)
            print(String(data: data, encoding: .utf8)!)
        case "runs":
            let index = try await storage.loadRunsIndex()
            let data = try encoder.encode(index)
            print(String(data: data, encoding: .utf8)!)
        case "status", "state":
            let path = options.dataDir.appendingPathComponent("state.json")
            let data = try Data(contentsOf: path)
            print(String(data: data, encoding: .utf8)!)
        case "init":
            try await storage.initialize()
            print("{\"status\": \"ok\"}")
        default:
            throw RunnerError.unknownQuery(query)
        }
    }
}

// MARK: - Cleanup Command

struct Cleanup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Clean up stale runs and orphaned processes")
    
    @OptionGroup var options: CommonOptions
    
    @Flag(name: .shortAndLong, help: "Actually kill processes (default: dry run)")
    var force: Bool = false
    
    func run() async throws {
        let storage = Storage(dataDir: options.dataDir)
        let index = try await storage.loadRunsIndex()
        
        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: storage,
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
            try await storage.markInterrupted(id: run.id)
            print("Marked \(run.id) as interrupted")
        }
        
        print("\n✅ Cleanup complete")
    }
    
}
