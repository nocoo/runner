import Foundation

public protocol RunsIndexLoading {
    func loadRunsIndex() async throws -> RunsIndex
}

extension Storage: RunsIndexLoading {}

public enum LogServiceError: Error {
    case invalidUTF8
}

public struct LogEntry: Sendable {
    public let status: String
    public let id: String
    public let task: String
    public let startedAt: String
}

public struct LogService {
    public let dataDir: URL
    private let loader: RunsIndexLoading
    private let fileIO: FileIO

    public init(dataDir: URL, loader: RunsIndexLoading, fileIO: FileIO = DefaultFileIO()) {
        self.dataDir = dataDir
        self.loader = loader
        self.fileIO = fileIO
    }

    public func listRuns(limit: Int) async throws -> [LogEntry] {
        let index = try await loader.loadRunsIndex()
        return index.runs.suffix(limit).reversed().map { run in
            LogEntry(
                status: statusSymbol(for: run.exitCode),
                id: run.id,
                task: run.task,
                startedAt: run.startedAt
            )
        }
    }

    public func output(runId: String?, tail: Int?) async throws -> String {
        let index = try await loader.loadRunsIndex()

        let resolvedId: String
        if let runId {
            resolvedId = runId
        } else if let last = index.runs.last {
            resolvedId = last.id
        } else {
            throw RunnerError.noRunsFound
        }

        let outputPath = dataDir.appendingPathComponent("runs/\(resolvedId).output")
        let data = try fileIO.readData(from: outputPath)
        guard let content = String(data: data, encoding: .utf8) else {
            throw LogServiceError.invalidUTF8
        }

        guard let tail else { return content }

        let lines = content.components(separatedBy: "\n")
        let start = max(0, lines.count - tail)
        return lines[start...].joined(separator: "\n")
    }

    private func statusSymbol(for exitCode: Int?) -> String {
        switch exitCode {
        case nil: return "⋯"
        case 0: return "✓"
        default: return "✗"
        }
    }
}
