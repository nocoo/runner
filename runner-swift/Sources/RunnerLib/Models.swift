import Foundation

/// Task executor
public enum TaskExecutor: String, Codable, Sendable {
    case shell
    case opencode
    case http
}

/// Task definition
public struct Task: Codable, Sendable {
    public let id: String
    public let executor: TaskExecutor
    public let description: String
    public let timeout: Int?
    public let command: String?
    public let prompt: String?
    public let workdir: String?
    public let url: String?
    public let method: String?
    public let headers: [String: String]?
    public let body: String?
    
    /// Effective timeout in seconds (default: 600 = 10 minutes)
    public var effectiveTimeout: Int {
        timeout ?? 600
    }
    
    public init(
        id: String,
        executor: TaskExecutor,
        description: String,
        timeout: Int? = nil,
        command: String? = nil,
        prompt: String? = nil,
        workdir: String? = nil,
        url: String? = nil,
        method: String? = nil,
        headers: [String: String]? = nil,
        body: String? = nil
    ) {
        self.id = id
        self.executor = executor
        self.description = description
        self.timeout = timeout
        self.command = command
        self.prompt = prompt
        self.workdir = workdir
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
    
    enum CodingKeys: String, CodingKey {
        case id, executor, type, description, timeout, command, prompt, workdir, url, method, headers, body
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        timeout = try container.decodeIfPresent(Int.self, forKey: .timeout)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        workdir = try container.decodeIfPresent(String.self, forKey: .workdir)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        body = try container.decodeIfPresent(String.self, forKey: .body)

        if let executorValue = try container.decodeIfPresent(TaskExecutor.self, forKey: .executor) {
            executor = executorValue
            return
        }

        if let legacyType = try container.decodeIfPresent(String.self, forKey: .type) {
            switch legacyType {
            case "simple":
                executor = .shell
            case "agent", "manual":
                executor = .opencode
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown legacy task type: \(legacyType)"
                )
            }
            return
        }

        throw DecodingError.keyNotFound(
            CodingKeys.executor,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Missing task executor"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(executor, forKey: .executor)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(timeout, forKey: .timeout)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encodeIfPresent(workdir, forKey: .workdir)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(method, forKey: .method)
        try container.encodeIfPresent(headers, forKey: .headers)
        try container.encodeIfPresent(body, forKey: .body)
    }
}

/// Schedule rule (raw JSON for flexible parsing)
public struct Schedule: Codable, Sendable {
    public let task: String
    public let hour: AnyCodable
    public let minute: AnyCodable
    public let weekday: AnyCodable
    
    public init(task: String, hour: AnyCodable, minute: AnyCodable, weekday: AnyCodable) {
        self.task = task
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
    }
}

/// Run summary in index.json
public struct RunSummary: Codable, Sendable {
    public let id: String
    public let task: String
    public let trigger: String?
    public var exitCode: Int?
    public let startedAt: String
    public var finishedAt: String?
    public var pid: Int?
    public var startedAtEpoch: Int64?
    
    public init(id: String, task: String, trigger: String? = nil, exitCode: Int?, startedAt: String, finishedAt: String?, pid: Int?, startedAtEpoch: Int64?) {
        self.id = id
        self.task = task
        self.trigger = trigger
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.pid = pid
        self.startedAtEpoch = startedAtEpoch
    }
    
    enum CodingKeys: String, CodingKey {
        case id, task, trigger
        case exitCode = "exit_code"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case pid
        case startedAtEpoch = "started_at_epoch"
    }
}

/// Runs index
public struct RunsIndex: Codable, Sendable {
    public var runs: [RunSummary]
    public var total: Int
    public var updatedAt: String
    
    public init(runs: [RunSummary], total: Int, updatedAt: String) {
        self.runs = runs
        self.total = total
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case runs, total
        case updatedAt = "updated_at"
    }
    
    /// Custom decoder with fallback for missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runs = try container.decode([RunSummary].self, forKey: .runs)
        // Fallback: compute total from runs array if missing
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? runs.count
        // Fallback: use empty string if missing (will be updated on next write)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

/// Run detail
public struct RunDetail: Codable, Sendable {
    public let id: String
    public let task: String
    public let trigger: String
    public let startedAt: String
    public let finishedAt: String?
    public let durationSeconds: Int?
    public let exitCode: Int
    
    public init(id: String, task: String, trigger: String, startedAt: String, finishedAt: String?, durationSeconds: Int?, exitCode: Int) {
        self.id = id
        self.task = task
        self.trigger = trigger
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.durationSeconds = durationSeconds
        self.exitCode = exitCode
    }
    
    enum CodingKeys: String, CodingKey {
        case id, task, trigger
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationSeconds = "duration_seconds"
        case exitCode = "exit_code"
    }
}

/// System state
public struct SystemState: Codable, Sendable {
    public var version: String
    public var lastRun: LastRun?
    public var totalRunsToday: Int
    public var successRateToday: Double
    
    public init(version: String, lastRun: LastRun?, totalRunsToday: Int, successRateToday: Double) {
        self.version = version
        self.lastRun = lastRun
        self.totalRunsToday = totalRunsToday
        self.successRateToday = successRateToday
    }
    
    enum CodingKeys: String, CodingKey {
        case version
        case lastRun = "last_run"
        case totalRunsToday = "total_runs_today"
        case successRateToday = "success_rate_today"
    }
}

public struct LastRun: Codable, Sendable {
    public let id: String
    public let task: String
    public let exitCode: Int
    public let finishedAt: String
    
    public init(id: String, task: String, exitCode: Int, finishedAt: String) {
        self.id = id
        self.task = task
        self.exitCode = exitCode
        self.finishedAt = finishedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, task
        case exitCode = "exit_code"
        case finishedAt = "finished_at"
    }
}

/// Helper for flexible JSON values
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = "*"
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            try container.encode("*")
        }
    }
}
