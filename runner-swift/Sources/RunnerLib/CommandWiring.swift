import Foundation

public struct AutoWiring {
    public let storage: Storage
    public let monitor: Monitor
    public let executor: Executor

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
        self.monitor = Monitor(storage: storage, verbose: options.verbose)
        self.executor = Executor(storage: storage, dryRun: options.dryRun, verbose: options.verbose)
    }
}

public struct RunWiring {
    public let storage: Storage
    public let executor: Executor

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
        self.executor = Executor(storage: storage, dryRun: options.dryRun, verbose: options.verbose)
    }
}

public struct ListWiring {
    public let storage: Storage

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
    }
}

public struct ValidateWiring {
    public let storage: Storage

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
    }
}

public struct MonitorWiring {
    public let storage: Storage
    public let monitor: Monitor

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
        self.monitor = Monitor(storage: storage, verbose: options.verbose)
    }
}

public struct InitWiring {
    public let storage: Storage

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
    }
}

public struct LogsWiring {
    public let storage: Storage

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
    }
}

public struct ApiWiring {
    public let storage: Storage
    public let statePath: URL

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
        self.statePath = options.dataDir.appendingPathComponent("state.json")
    }
}

public struct CleanupWiring {
    public let storage: Storage

    public init(options: CommonOptions) {
        self.storage = Storage(dataDir: options.dataDir)
    }
}
