import Foundation
import Darwin

public protocol FileIO {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func createFile(atPath path: String, contents: Data?)
    func readData(from url: URL) throws -> Data
    func writeData(_ data: Data, to url: URL) throws
    func lockFileDescriptor(_ fd: Int32) -> Bool
    func unlockFileDescriptor(_ fd: Int32)
    func openFileHandleForWriting(to url: URL) throws -> FileHandle
    func openFileHandleForUpdating(atPath path: String) throws -> FileHandle
    func closeFileHandle(_ handle: FileHandle) throws
}

public struct DefaultFileIO: FileIO {
    private let fileManager = FileManager.default

    public init() {}

    public func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    public func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }

    public func createFile(atPath path: String, contents: Data?) {
        fileManager.createFile(atPath: path, contents: contents)
    }

    public func readData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    public func lockFileDescriptor(_ fd: Int32) -> Bool {
        flock(fd, LOCK_EX) == 0
    }

    public func unlockFileDescriptor(_ fd: Int32) {
        flock(fd, LOCK_UN)
    }

    public func openFileHandleForWriting(to url: URL) throws -> FileHandle {
        try FileHandle(forWritingTo: url)
    }

    public func openFileHandleForUpdating(atPath path: String) throws -> FileHandle {
        try FileHandle(forUpdating: URL(fileURLWithPath: path))
    }

    public func closeFileHandle(_ handle: FileHandle) throws {
        try handle.close()
    }
}
