import Foundation

public struct InitService {
    private let initializer: Initializing
    private let dataDir: URL

    public init(initializer: Initializing, dataDir: URL) {
        self.initializer = initializer
        self.dataDir = dataDir
    }

    public func run() async throws -> String {
        try await initializer.initialize()
        return "Initialized data directory: \(dataDir.path)"
    }
}
