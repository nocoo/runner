import Testing
import Foundation
@testable import RunnerLib

@Suite("CommandWiring Tests")
struct CommandWiringTests {
    func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    @Test("AutoWiring builds dependencies")
    func autoWiringBuildsDependencies() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path, "--dry-run", "--verbose"])
        let wiring = try AutoWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
        #expect(wiring.monitor.verbose == true)
        #expect(wiring.executor.dryRun == true)
        #expect(wiring.executor.verbose == true)
    }

    @Test("RunWiring builds executor")
    func runWiringBuildsExecutor() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path, "--dry-run"])
        let wiring = try RunWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
        #expect(wiring.executor.dryRun == true)
    }

    @Test("ListWiring builds storage")
    func listWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = try ListWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("ValidateWiring builds storage")
    func validateWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = try ValidateWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("MonitorWiring builds monitor")
    func monitorWiringBuildsMonitor() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path, "--verbose"])
        let wiring = try MonitorWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
        #expect(wiring.monitor.verbose == true)
    }

    @Test("InitWiring builds storage")
    func initWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = try InitWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("LogsWiring builds storage")
    func logsWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = try LogsWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("ApiWiring builds state path")
    func apiWiringBuildsStatePath() throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = try ApiWiring(options: options)
        #expect(wiring.statePath.lastPathComponent == "state.json")
    }

    @Test("CleanupWiring builds storage")
    func cleanupWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = try CleanupWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

}
