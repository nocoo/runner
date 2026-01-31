import Testing
import Foundation
@testable import RunnerLib

@Suite("LogService Tests")
struct LogServiceTests {
    final class StubRunsLoader: RunsIndexLoading {
        let index: RunsIndex
        init(index: RunsIndex) { self.index = index }
        func loadRunsIndex() async throws -> RunsIndex { index }
    }

    final class StubFileIO: FileIO {
        var files: [String: Data]

        init(files: [String: Data]) {
            self.files = files
        }

        func fileExists(atPath path: String) -> Bool { files[path] != nil }
        func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {}
        func createFile(atPath path: String, contents: Data?) { files[path] = contents ?? Data() }
        func readData(from url: URL) throws -> Data { files[url.path] ?? Data() }
        func writeData(_ data: Data, to url: URL) throws { files[url.path] = data }
        func lockFileDescriptor(_ fd: Int32) -> Bool { true }
        func unlockFileDescriptor(_ fd: Int32) {}
        func openFileHandleForWriting(to url: URL) throws -> FileHandle { throw NSError(domain: "test", code: 1) }
        func openFileHandleForUpdating(atPath path: String) throws -> FileHandle { throw NSError(domain: "test", code: 1) }
        func closeFileHandle(_ handle: FileHandle) throws {}
    }

    @Test("LogService returns tail output")
    func logServiceTail() async throws {
        let outputPath = URL(fileURLWithPath: "/tmp/runs/abc.output")
        let fileIO = StubFileIO(files: [outputPath.path: Data("line1\nline2\nline3\n".utf8)])
        let loader = StubRunsLoader(index: RunsIndex(runs: [RunSummary(id: "abc", task: "t", exitCode: 0, startedAt: "", finishedAt: nil, pid: nil, startedAtEpoch: nil)], total: 1, updatedAt: ""))
        let service = LogService(dataDir: URL(fileURLWithPath: "/tmp"), loader: loader, fileIO: fileIO)

        let output = try await service.output(runId: nil, tail: 3)
        #expect(output.contains("line2"))
        #expect(output.contains("line3"))
    }

    @Test("LogService lists runs")
    func logServiceList() async throws {
        let index = RunsIndex(runs: [
            RunSummary(id: "a", task: "t1", exitCode: nil, startedAt: "s1", finishedAt: nil, pid: nil, startedAtEpoch: nil),
            RunSummary(id: "b", task: "t2", exitCode: 0, startedAt: "s2", finishedAt: nil, pid: nil, startedAtEpoch: nil)
        ], total: 2, updatedAt: "")
        let loader = StubRunsLoader(index: index)
        let service = LogService(dataDir: URL(fileURLWithPath: "/tmp"), loader: loader)

        let entries = try await service.listRuns(limit: 20)
        #expect(entries.count == 2)
        #expect(entries[0].status == "✓")
        #expect(entries[1].status == "⋯")
    }

    @Test("LogService throws when no runs and no id")
    func logServiceNoRuns() async throws {
        let loader = StubRunsLoader(index: RunsIndex(runs: [], total: 0, updatedAt: ""))
        let service = LogService(dataDir: URL(fileURLWithPath: "/tmp"), loader: loader)

        do {
            _ = try await service.output(runId: nil, tail: nil)
            #expect(Bool(false), "Expected noRunsFound error")
        } catch let error as RunnerError {
            switch error {
            case .noRunsFound:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "Unexpected error: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("LogService throws on invalid UTF-8")
    func logServiceInvalidUtf8() async throws {
        let outputPath = URL(fileURLWithPath: "/tmp/runs/abc.output")
        let fileIO = StubFileIO(files: [outputPath.path: Data([0xFF, 0xFE])])
        let loader = StubRunsLoader(index: RunsIndex(runs: [RunSummary(id: "abc", task: "t", exitCode: 0, startedAt: "", finishedAt: nil, pid: nil, startedAtEpoch: nil)], total: 1, updatedAt: ""))
        let service = LogService(dataDir: URL(fileURLWithPath: "/tmp"), loader: loader, fileIO: fileIO)

        do {
            _ = try await service.output(runId: "abc", tail: nil)
            #expect(Bool(false), "Expected invalidUTF8 error")
        } catch let error as LogServiceError {
            switch error {
            case .invalidUTF8:
                #expect(Bool(true))
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}
