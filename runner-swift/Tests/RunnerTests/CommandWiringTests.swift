import Testing
import Foundation
import Testing
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
        let wiring = AutoWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
        #expect(wiring.monitor.verbose == true)
        #expect(wiring.executor.dryRun == true)
        #expect(wiring.executor.verbose == true)
    }

    @Test("RunWiring builds executor")
    func runWiringBuildsExecutor() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path, "--dry-run"])
        let wiring = RunWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
        #expect(wiring.executor.dryRun == true)
    }

    @Test("ListWiring builds storage")
    func listWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = ListWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("ValidateWiring builds storage")
    func validateWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = ValidateWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("MonitorWiring builds monitor")
    func monitorWiringBuildsMonitor() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path, "--verbose"])
        let wiring = MonitorWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
        #expect(wiring.monitor.verbose == true)
    }

    @Test("InitWiring builds storage")
    func initWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = InitWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("LogsWiring builds storage")
    func logsWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = LogsWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

    @Test("ApiWiring builds state path")
    func apiWiringBuildsStatePath() throws {
        let options = try CommonOptions.parse([])
        let wiring = ApiWiring(options: options)
        #expect(wiring.statePath.lastPathComponent == "state.json")
    }

    @Test("CleanupWiring builds storage")
    func cleanupWiringBuildsStorage() async throws {
        let tempDir = try makeTempDir()
        let options = try CommonOptions.parse(["--data-dir", tempDir.path])
        let wiring = CleanupWiring(options: options)
        #expect(await wiring.storage.dataDir == options.dataDir)
    }

}
