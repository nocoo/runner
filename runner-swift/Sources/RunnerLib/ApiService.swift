import Foundation

public enum ApiQuery: Sendable, Equatable {
    case tasks
    case schedules
    case runs
    case run(id: String)
    case status
    case state
    case initialize
    
    /// Parse query string like "tasks", "runs", "run abc-123"
    public init?(rawValue: String) {
        switch rawValue {
        case "tasks": self = .tasks
        case "schedules": self = .schedules
        case "runs": self = .runs
        case "status": self = .status
        case "state": self = .state
        case "init": self = .initialize
        default:
            // Check for "run <id>" pattern
            if rawValue.hasPrefix("run ") {
                let id = String(rawValue.dropFirst(4))
                if !id.isEmpty {
                    self = .run(id: id)
                    return
                }
            }
            return nil
        }
    }
}

public enum ApiServiceError: Error {
    case unknownQuery(String)
    case invalidUTF8
    case missingRunId
}

public protocol TasksLoading {
    func loadTasks() async throws -> [Task]
}

public protocol SchedulesLoading {
    func loadSchedules() async throws -> [Schedule]
}

public protocol StateLoading: Sendable {
    func readStateData() async throws -> Data
}

public protocol Initializing {
    func initialize() async throws
}

extension Storage: TasksLoading {}
extension Storage: SchedulesLoading {}
extension Storage: Initializing {}

public struct DefaultStateLoader: StateLoading {
    private let path: URL

    public init(path: URL, fileIO: FileIO = DefaultFileIO()) {
        self.path = path
    }

    public func readStateData() async throws -> Data {
        try Data(contentsOf: path)
    }
}

public struct ApiService {
    private let tasksLoader: TasksLoading
    private let schedulesLoader: SchedulesLoading
    private let runsLoader: RunsIndexLoading
    private let initializer: Initializing
    private let stateLoader: StateLoading
    private let runDetailLoader: RunDetailLoading
    private let encoder: JSONEncoder

    public init(
        tasksLoader: TasksLoading,
        schedulesLoader: SchedulesLoading,
        runsLoader: RunsIndexLoading,
        initializer: Initializing,
        stateLoader: StateLoading,
        runDetailLoader: RunDetailLoading
    ) {
        self.tasksLoader = tasksLoader
        self.schedulesLoader = schedulesLoader
        self.runsLoader = runsLoader
        self.initializer = initializer
        self.stateLoader = stateLoader
        self.runDetailLoader = runDetailLoader
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func handle(query: String) async throws -> String {
        guard let apiQuery = ApiQuery(rawValue: query) else {
            throw RunnerError.unknownQuery(query)
        }
        return try await handle(query: apiQuery)
    }

    public func handle(query: ApiQuery) async throws -> String {
        switch query {
        case .tasks:
            return try encodeString(await tasksLoader.loadTasks())
        case .schedules:
            return try encodeString(await schedulesLoader.loadSchedules())
        case .runs:
            return try encodeString(await runsLoader.loadRunsIndex())
        case .run(let id):
            let detail = try await runDetailLoader.loadRunDetail(id: id)
            return try encodeString(detail)
        case .status, .state:
            let data = try await stateLoader.readStateData()
            guard let content = String(data: data, encoding: .utf8) else {
                throw ApiServiceError.invalidUTF8
            }
            return content
        case .initialize:
            try await initializer.initialize()
            return "{\"status\": \"ok\"}"
        }
    }

    private func encodeString<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ApiServiceError.invalidUTF8
        }
        return string
    }
}
