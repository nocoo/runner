import Foundation

public struct MonitorResult: Sendable {
    public let interrupted: [String]

    public init(interrupted: [String]) {
        self.interrupted = interrupted
    }
}

public struct MonitorService {
    private let monitor: TaskMonitoring

    public init(monitor: TaskMonitoring) {
        self.monitor = monitor
    }

    public func check() async throws -> MonitorResult {
        let interrupted = try await monitor.checkRunningTasks()
        return MonitorResult(interrupted: interrupted)
    }
}
