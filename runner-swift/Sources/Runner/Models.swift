import Foundation

/// Task type
enum TaskType: String, Codable {
    case simple
    case agent
    case manual
}

/// Task definition
struct Task: Codable {
    let id: String
    let type: TaskType
    let description: String
    let timeout: Int
    let command: String?
    let prompt: String?
    let workdir: String?
    let model: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, description, timeout, command, prompt, workdir, model
    }
}

/// Schedule rule (raw JSON for flexible parsing)
struct Schedule: Codable {
    let task: String
    let hour: AnyCodable
    let minute: AnyCodable
    let weekday: AnyCodable
}

/// Run summary in index.json
struct RunSummary: Codable {
    let id: String
    let task: String
    var exitCode: Int?
    let startedAt: String
    var finishedAt: String?
    var pid: Int?
    var startedAtEpoch: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id, task
        case exitCode = "exit_code"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case pid
        case startedAtEpoch = "started_at_epoch"
    }
}

/// Runs index
struct RunsIndex: Codable {
    var runs: [RunSummary]
    var total: Int
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case runs, total
        case updatedAt = "updated_at"
    }
}

/// Run detail
struct RunDetail: Codable {
    let id: String
    let task: String
    let trigger: String
    let startedAt: String
    let finishedAt: String?
    let durationSeconds: Int?
    let exitCode: Int
    
    enum CodingKeys: String, CodingKey {
        case id, task, trigger
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationSeconds = "duration_seconds"
        case exitCode = "exit_code"
    }
}

/// System state
struct SystemState: Codable {
    var version: String
    var lastRun: LastRun?
    var totalRunsToday: Int
    var successRateToday: Double
    
    enum CodingKeys: String, CodingKey {
        case version
        case lastRun = "last_run"
        case totalRunsToday = "total_runs_today"
        case successRateToday = "success_rate_today"
    }
}

struct LastRun: Codable {
    let id: String
    let task: String
    let exitCode: Int
    let finishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, task
        case exitCode = "exit_code"
        case finishedAt = "finished_at"
    }
}

/// Helper for flexible JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = "*"
        }
    }
    
    func encode(to encoder: Encoder) throws {
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
