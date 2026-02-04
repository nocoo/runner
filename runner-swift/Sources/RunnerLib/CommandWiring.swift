import Foundation

public struct AutoWiring {
    public let storage: SQLiteStorage
    public let monitor: Monitor
    public let executor: Executor

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
        self.monitor = Monitor(repository: storage, verbose: options.verbose)
        self.executor = Executor(repository: storage, dataDir: options.dataDir, dryRun: options.dryRun, verbose: options.verbose)
    }
}

public struct RunWiring {
    public let storage: SQLiteStorage
    public let executor: Executor

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
        self.executor = Executor(repository: storage, dataDir: options.dataDir, dryRun: options.dryRun, verbose: options.verbose)
    }
}

public struct ListWiring {
    public let storage: SQLiteStorage

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
    }
}

public struct ValidateWiring {
    public let storage: SQLiteStorage

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
    }
}

public struct MonitorWiring {
    public let storage: SQLiteStorage
    public let monitor: Monitor

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
        self.monitor = Monitor(repository: storage, verbose: options.verbose)
    }
}

public struct InitWiring {
    public let storage: SQLiteStorage

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
    }
}

public struct LogsWiring {
    public let storage: SQLiteStorage

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
    }
}

public struct ApiWiring {
    public let storage: SQLiteStorage
    public let stateLoader: StateLoading

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
        self.stateLoader = SQLiteStateLoader(storage: storage)
    }
}

public struct CleanupWiring {
    public let storage: SQLiteStorage

    public init(options: CommonOptions) throws {
        self.storage = try SQLiteStorage(dataDir: options.dataDir)
    }
}
