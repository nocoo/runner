import Foundation

public enum ApiQuery: String, Sendable {
    case tasks
    case schedules
    case runs
    case status
    case state
    case initialize = "init"
}

public enum ApiServiceError: Error {
    case unknownQuery(String)
    case invalidUTF8
}

public protocol TasksLoading {
    func loadTasks() async throws -> [Task]
}

public protocol SchedulesLoading {
    func loadSchedules() async throws -> [Schedule]
}

public protocol StateLoading {
    func readStateData() throws -> Data
}

public protocol Initializing {
    func initialize() async throws
}

extension Storage: TasksLoading {}
extension Storage: SchedulesLoading {}
extension Storage: Initializing {}

public struct DefaultStateLoader: StateLoading {
    private let path: URL
    private let fileIO: FileIO

    public init(path: URL, fileIO: FileIO = DefaultFileIO()) {
        self.path = path
        self.fileIO = fileIO
    }

    public func readStateData() throws -> Data {
        try fileIO.readData(from: path)
    }
}

public struct ApiService {
    private let tasksLoader: TasksLoading
    private let schedulesLoader: SchedulesLoading
    private let runsLoader: RunsIndexLoading
    private let initializer: Initializing
    private let stateLoader: StateLoading
    private let encoder: JSONEncoder

    public init(
        tasksLoader: TasksLoading,
        schedulesLoader: SchedulesLoading,
        runsLoader: RunsIndexLoading,
        initializer: Initializing,
        stateLoader: StateLoading
    ) {
        self.tasksLoader = tasksLoader
        self.schedulesLoader = schedulesLoader
        self.runsLoader = runsLoader
        self.initializer = initializer
        self.stateLoader = stateLoader
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
        case .status, .state:
            let data = try stateLoader.readStateData()
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
