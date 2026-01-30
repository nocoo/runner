import Testing
import Foundation
@testable import RunnerLib

@Suite("CommandWiring Tests")
struct CommandWiringTests {
    @Test("AutoWiring builds dependencies")
    func autoWiringBuildsDependencies() throws {
        let options = try CommonOptions.parse([])
        _ = AutoWiring(options: options)
        #expect(Bool(true))
    }

    @Test("RunWiring builds executor")
    func runWiringBuildsExecutor() throws {
        let options = try CommonOptions.parse([])
        _ = RunWiring(options: options)
        #expect(Bool(true))
    }

    @Test("ApiWiring builds state path")
    func apiWiringBuildsStatePath() throws {
        let options = try CommonOptions.parse([])
        let wiring = ApiWiring(options: options)
        #expect(wiring.statePath.lastPathComponent == "state.json")
    }
}
