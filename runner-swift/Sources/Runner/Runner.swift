import Foundation
import ArgumentParser
import RunnerLib

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runner",
        abstract: "Declarative task scheduler for macOS",
        version: "0.1.0",
        subcommands: [Auto.self, Run.self, List.self, Validate.self, MonitorCommand.self, Init.self, Logs.self, Api.self]
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
        options.log("Running monitor to check stale tasks")
        let monitor = Monitor(storage: storage, verbose: options.verbose)
        let interrupted = try await monitor.checkRunningTasks()
        if !interrupted.isEmpty {
            options.log("Marked \(interrupted.count) tasks as interrupted")
        }
        
        // Load config
        let tasks = try await storage.loadTasks()
        let schedules = try await storage.loadSchedules()
        
        // Get current time (UTC+8)
        let now = Date()
        let calendar = Calendar.current
        let tz = TimeZone(secondsFromGMT: 8 * 3600)!
        let components = calendar.dateComponents(in: tz, from: now)
        
        let hour = mockHour ?? components.hour!
        let minute = mockMinute ?? components.minute!
        let weekday = mockWeekday ?? (components.weekday! - 1) // Convert to 0=Sunday
        
        options.log("Current time: hour=\(hour), minute=\(minute), weekday=\(weekday)")
        
        // Find scheduled tasks
        let taskIds = Scheduler.findScheduledTasks(
            schedules: schedules,
            tasks: tasks,
            hour: hour,
            minute: minute,
            weekday: weekday
        )
        
        if taskIds.isEmpty {
            options.log("No tasks scheduled for current time")
            return
        }
        
        options.log("Found \(taskIds.count) task(s) to execute")
        
        // Execute tasks
        let executor = Executor(storage: storage, dryRun: options.dryRun, verbose: options.verbose)
        
        for taskId in taskIds {
            if let task = tasks.first(where: { $0.id == taskId }) {
                options.log("Executing task: \(taskId)")
                do {
                    let result = try await executor.execute(task: task, trigger: "scheduled")
                    options.log("Task \(taskId) completed with exit code \(result.exitCode)")
                } catch {
                    FileHandle.standardError.write("Error executing task \(taskId): \(error)\n".data(using: .utf8)!)
                }
            }
        }
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
        let tasks = try await storage.loadTasks()
        
        guard let task = tasks.first(where: { $0.id == self.task }) else {
            throw RunnerError.taskNotFound(self.task)
        }
        
        options.log("Executing task: \(task.id)")
        
        let executor = Executor(storage: storage, dryRun: options.dryRun, verbose: options.verbose)
        let result = try await executor.execute(task: task, trigger: trigger)
        
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
            if task.command.isEmpty {
                errors.append("Task '\(task.id)' has no command")
            }
        }
        
        // Validate schedules
        let taskIds = Set(tasks.map { $0.id })
        for schedule in schedules {
            if !taskIds.contains(schedule.task) {
                errors.append("Schedule references unknown task '\(schedule.task)'")
            }
        }
        
        if errors.isEmpty {
            print("Configuration is valid")
            print("  Tasks: \(tasks.count)")
            print("  Schedules: \(schedules.count)")
        } else {
            for error in errors {
                FileHandle.standardError.write("Error: \(error)\n".data(using: .utf8)!)
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
