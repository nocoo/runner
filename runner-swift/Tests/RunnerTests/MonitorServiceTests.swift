import Testing
@testable import RunnerLib

@Suite("MonitorService Tests")
struct MonitorServiceTests {
    final class StubMonitor: TaskMonitoring {
        let interrupted: [String]
        init(interrupted: [String]) { self.interrupted = interrupted }
        func checkRunningTasks() async throws -> [String] { interrupted }
    }

    @Test("MonitorService returns interrupted list")
    func monitorServiceReturnsInterrupted() async throws {
        let service = MonitorService(monitor: StubMonitor(interrupted: ["r1", "r2"]))
        let result = try await service.check()

        #expect(result.interrupted == ["r1", "r2"])
    }
}
