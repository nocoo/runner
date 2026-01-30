import Foundation
import Darwin

public struct CleanupProcess: Sendable, Equatable {
    public let pid: Int
    public let id: String
    public let task: String
    public let startedAt: String

    public init(pid: Int, id: String, task: String, startedAt: String) {
        self.pid = pid
        self.id = id
        self.task = task
        self.startedAt = startedAt
    }
}

public struct CleanupRun: Sendable, Equatable {
    public let id: String
    public let task: String
    public let reason: String

    public init(id: String, task: String, reason: String) {
        self.id = id
        self.task = task
        self.reason = reason
    }
}

public struct CleanupPlan: Sendable {
    public let staleRuns: [RunSummary]
    public let processesToKill: [CleanupProcess]
    public let runningProcesses: [CleanupProcess]
    public let runsToMark: [CleanupRun]

    public init(
        staleRuns: [RunSummary],
        processesToKill: [CleanupProcess],
        runningProcesses: [CleanupProcess],
        runsToMark: [CleanupRun]
    ) {
        self.staleRuns = staleRuns
        self.processesToKill = processesToKill
        self.runningProcesses = runningProcesses
        self.runsToMark = runsToMark
    }
}

public protocol RunDetailLoading {
    func loadRunDetail(id: String) async throws -> RunDetail?
}

public protocol ProcessInspecting {
    func isRunning(pid: Int) -> Bool
    func parentPid(pid: Int) -> Int
}

extension Storage: RunDetailLoading {}

public struct DefaultProcessInspector: ProcessInspecting {
    public init() {}

    public func isRunning(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }

    public func parentPid(pid: Int) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "ppid=", "-p", "\(pid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let ppid = Int(output) {
                return ppid
            }
        } catch {}

        return -1
    }
}

public struct CleanupPlanner {
    public init() {}

    public func buildPlan(
        index: RunsIndex,
        detailLoader: RunDetailLoading,
        processInspector: ProcessInspecting
    ) async throws -> CleanupPlan {
        let staleRuns = index.runs.filter { $0.exitCode == nil }
        var processesToKill: [CleanupProcess] = []
        var runningProcesses: [CleanupProcess] = []
        var runsToMark: [CleanupRun] = []

        for run in staleRuns {
            let task = run.task
            let id = run.id

            if let detail = try await detailLoader.loadRunDetail(id: id) {
                runsToMark.append(
                    CleanupRun(
                        id: id,
                        task: task,
                        reason: "has detail.json (exit: \(detail.exitCode))"
                    )
                )
                continue
            }

            guard let pid = run.pid else {
                runsToMark.append(CleanupRun(id: id, task: task, reason: "no PID"))
                continue
            }

            if processInspector.isRunning(pid: pid) {
                let ppid = processInspector.parentPid(pid: pid)
                let process = CleanupProcess(pid: pid, id: id, task: task, startedAt: run.startedAt)
                if ppid == 1 {
                    processesToKill.append(process)
                } else {
                    runningProcesses.append(process)
                }
            } else {
                runsToMark.append(CleanupRun(id: id, task: task, reason: "process dead"))
            }
        }

        return CleanupPlan(
            staleRuns: staleRuns,
            processesToKill: processesToKill,
            runningProcesses: runningProcesses,
            runsToMark: runsToMark
        )
    }
}
