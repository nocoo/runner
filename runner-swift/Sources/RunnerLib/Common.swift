import Foundation
import ArgumentParser

// MARK: - Common Options

public struct CommonOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Data directory")
    public var dataDir: URL = URL(fileURLWithPath: "./data")
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    public var verbose: Bool = false
    
    @Flag(name: .long, help: "Dry run")
    public var dryRun: Bool = false
    
    public init() {}
    
    public func log(_ message: String) {
        if verbose {
            FileHandle.standardError.write("[DEBUG] \(message)\n".data(using: .utf8)!)
        }
    }
}

// MARK: - Errors

public enum RunnerError: Error, CustomStringConvertible {
    case taskNotFound(String)
    case noRunsFound
    case unknownQuery(String)
    
    public var description: String {
        switch self {
        case .taskNotFound(let id): return "Task not found: \(id)"
        case .noRunsFound: return "No runs found"
        case .unknownQuery(let q): return "Unknown query: \(q)"
        }
    }
}

// MARK: - URL Extension for ArgumentParser

extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self = URL(fileURLWithPath: argument)
    }
}
