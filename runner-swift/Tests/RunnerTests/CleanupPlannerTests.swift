import Testing
import Foundation
@testable import RunnerLib

@Suite("CleanupPlanner Tests")
struct CleanupPlannerTests {
    final class StubDetailLoader: RunDetailLoading {
        let details: [String: RunDetail]

        init(details: [String: RunDetail]) {
            self.details = details
        }

        func loadRunDetail(id: String) async throws -> RunDetail? {
            details[id]
        }
    }

    final class StubProcessInspector: ProcessInspecting {
        let running: Set<Int>
        let ppidMap: [Int: Int]

        init(running: Set<Int>, ppidMap: [Int: Int]) {
            self.running = running
            self.ppidMap = ppidMap
        }

        func isRunning(pid: Int) -> Bool {
            running.contains(pid)
        }

        func parentPid(pid: Int) -> Int {
            ppidMap[pid] ?? -1
        }
    }

    func makeRun(id: String, pid: Int?, exitCode: Int? = nil) -> RunSummary {
        RunSummary(
            id: id,
            task: "task-\(id)",
            exitCode: exitCode,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: nil,
            pid: pid,
            startedAtEpoch: 1769308800
        )
    }

    @Test("CleanupPlanner builds plan for mixed states")
    func cleanupPlannerBuildsPlan() async throws {
        let index = RunsIndex(runs: [
            makeRun(id: "detail", pid: 111),
            makeRun(id: "no_pid", pid: nil),
            makeRun(id: "dead", pid: 222),
            makeRun(id: "orphan", pid: 333),
            makeRun(id: "running", pid: 444),
            makeRun(id: "done", pid: nil, exitCode: 0)
        ], total: 6, updatedAt: "2026-01-25T08:00:01Z")

        let detail = RunDetail(
            id: "detail",
            task: "task-detail",
            trigger: "manual",
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            durationSeconds: 1,
            exitCode: 0
        )

        let loader = StubDetailLoader(details: ["detail": detail])
        let inspector = StubProcessInspector(
            running: [333, 444],
            ppidMap: [333: 1, 444: 10]
        )

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: loader,
            processInspector: inspector
        )

        #expect(plan.staleRuns.count == 5)
        #expect(plan.processesToKill.map { $0.id } == ["orphan"])
        #expect(plan.runningProcesses.map { $0.id } == ["running"])

        let reasons = plan.runsToMark.map { $0.reason }
        #expect(reasons.contains("has detail.json (exit: 0)"))
        #expect(reasons.contains("no PID"))
        #expect(reasons.contains("process dead"))
    }

    @Test("CleanupPlanner returns empty plan when no stale runs")
    func cleanupPlannerEmptyPlan() async throws {
        let index = RunsIndex(runs: [
            makeRun(id: "done", pid: nil, exitCode: 0)
        ], total: 1, updatedAt: "2026-01-25T08:00:01Z")

        let loader = StubDetailLoader(details: [:])
        let inspector = StubProcessInspector(running: [], ppidMap: [:])

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: loader,
            processInspector: inspector
        )

        #expect(plan.staleRuns.isEmpty)
        #expect(plan.processesToKill.isEmpty)
        #expect(plan.runningProcesses.isEmpty)
        #expect(plan.runsToMark.isEmpty)
    }

    @Test("CleanupPlanner keeps running process when parent not init")
    func cleanupPlannerKeepsRunningProcess() async throws {
        let index = RunsIndex(runs: [
            makeRun(id: "running", pid: 444)
        ], total: 1, updatedAt: "2026-01-25T08:00:01Z")

        let loader = StubDetailLoader(details: [:])
        let inspector = StubProcessInspector(running: [444], ppidMap: [444: 2])

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: loader,
            processInspector: inspector
        )

        #expect(plan.processesToKill.isEmpty)
        #expect(plan.runningProcesses.map { $0.id } == ["running"])
        #expect(plan.runsToMark.isEmpty)
    }

    @Test("CleanupPlanner marks orphan when parent is init")
    func cleanupPlannerMarksOrphanWhenParentIsInit() async throws {
        let index = RunsIndex(runs: [
            makeRun(id: "orphan", pid: 333)
        ], total: 1, updatedAt: "2026-01-25T08:00:01Z")

        let loader = StubDetailLoader(details: [:])
        let inspector = StubProcessInspector(running: [333], ppidMap: [333: 1])

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: loader,
            processInspector: inspector
        )

        #expect(plan.processesToKill.map { $0.id } == ["orphan"])
        #expect(plan.runningProcesses.isEmpty)
        #expect(plan.runsToMark.isEmpty)
    }

    @Test("CleanupPlanner marks stale when process dead and no detail")
    func cleanupPlannerMarksDeadProcessNoDetail() async throws {
        let index = RunsIndex(runs: [
            makeRun(id: "dead", pid: 222)
        ], total: 1, updatedAt: "2026-01-25T08:00:01Z")

        let loader = StubDetailLoader(details: [:])
        let inspector = StubProcessInspector(running: [], ppidMap: [:])

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: loader,
            processInspector: inspector
        )

        #expect(plan.runsToMark.map { $0.id } == ["dead"])
        #expect(plan.runsToMark.map { $0.reason } == ["process dead"])
    }

    @Test("CleanupPlanner marks stale when detail exit nonzero")
    func cleanupPlannerMarksDetailNonzeroExit() async throws {
        let index = RunsIndex(runs: [
            makeRun(id: "detail_fail", pid: 111)
        ], total: 1, updatedAt: "2026-01-25T08:00:01Z")

        let detail = RunDetail(
            id: "detail_fail",
            task: "task-detail_fail",
            trigger: "manual",
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            durationSeconds: 1,
            exitCode: 2
        )

        let loader = StubDetailLoader(details: ["detail_fail": detail])
        let inspector = StubProcessInspector(running: [], ppidMap: [:])

        let planner = CleanupPlanner()
        let plan = try await planner.buildPlan(
            index: index,
            detailLoader: loader,
            processInspector: inspector
        )

        #expect(plan.runsToMark.map { $0.id } == ["detail_fail"])
        #expect(plan.runsToMark.map { $0.reason } == ["has detail.json (exit: 2)"])
    }

}
