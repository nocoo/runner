import Testing
import Foundation
@testable import RunnerLib

@Suite("InitService Tests")
struct InitServiceTests {
    final class StubInitializer: Initializing {
        private(set) var called = false
        func initialize() async throws { called = true }
    }

    @Test("InitService returns message")
    func initServiceReturnsMessage() async throws {
        let initializer = StubInitializer()
        let dataDir = URL(fileURLWithPath: "/tmp/data")
        let service = InitService(initializer: initializer, dataDir: dataDir)

        let message = try await service.run()
        #expect(message.contains("/tmp/data"))
    }
}
