import Foundation
import Darwin

/// Task executor - just runs shell commands
public struct Executor {
    public let repository: any RunRepository
    public let dataDir: URL
    public let dryRun: Bool
    public let verbose: Bool
    
    public init(repository: any RunRepository, dataDir: URL, dryRun: Bool, verbose: Bool) {
        self.repository = repository
        self.dataDir = dataDir
        self.dryRun = dryRun
        self.verbose = verbose
    }
    
    /// Convenience initializer for backward compatibility with Storage
    public init(storage: Storage, dryRun: Bool, verbose: Bool) {
        self.repository = storage
        self.dataDir = storage.dataDir
        self.dryRun = dryRun
        self.verbose = verbose
    }
    
    public func log(_ message: String) {
        if verbose {
            FileHandle.standardError.write(Data("[DEBUG] \(message)\n".utf8))
        }
    }
    
    /// Get executable command for a task
    private func getCommand(for task: Task) -> String? {
        if task.executor == .http {
            return buildHttpCommand(for: task)
        }
        if let command = task.command, !command.isEmpty {
            return command
        }
        if let prompt = task.prompt, !prompt.isEmpty {
            // Build opencode command from prompt
            let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\"'\"'")
            return "opencode run '\(escapedPrompt)' --agent build --model zai-coding-plan/glm-4.7"
        }
        return nil
    }

    private func buildHttpCommand(for task: Task) -> String? {
        guard let url = task.url, !url.isEmpty else {
            return nil
        }
        let method = (task.method ?? "GET").uppercased()
        var parts: [String] = ["curl", "-sS", "--fail-with-body", "-X", method]

        if let headers = task.headers {
            for (key, value) in headers {
                let headerValue = "\(key): \(value)"
                parts.append("-H")
                parts.append(shellEscape(headerValue))
            }
        }

        if method != "GET", let body = task.body, !body.isEmpty {
            parts.append("--data")
            parts.append(shellEscape(body))
        }

        parts.append(shellEscape(url))
        return parts.joined(separator: " ")
    }

    private func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }
    
    /// Execute a task
    public func execute(task: Task, trigger: String) async throws -> ExecutionResult {
        guard let command = getCommand(for: task) else {
            throw ExecutorError.missingCommand
        }
        
        let runId = UUID().uuidString
        let startedAt = ISO8601DateFormatter().string(from: Date())
        let startEpoch = Int64(Date().timeIntervalSince1970)
        
        log("Run ID: \(runId)")
        log("Started at: \(startedAt)")
        log("Command: \(command)")
        
        if dryRun {
            return ExecutionResult(
                id: runId,
                exitCode: 0,
                output: "[DRY RUN] Would execute: \(command)"
            )
        }
        
        let pid = try await prepareAndSpawn(
            task: task,
            command: command,
            runId: runId,
            startedAt: startedAt,
            trigger: trigger
        )
        
        // Add to index
        let summary = RunSummary(
            id: runId,
            task: task.id,
            exitCode: nil,
            startedAt: startedAt,
            finishedAt: nil,
            pid: Int(pid),
            startedAtEpoch: startEpoch
        )
        try await repository.addRun(summary)
        
        log("Background PID: \(pid)")
        
        return ExecutionResult(id: runId, exitCode: 0, output: "Task started in background")
    }
    
    /// Create shell script that executes command and updates storage
    private func createScript(
        task: Task,
        command: String,
        runId: String,
        startedAt: String,
        trigger: String
    ) -> String {
        let builder = ScriptBuilder(dataDir: dataDir)
        return builder.build(
            task: task,
            command: command,
            runId: runId,
            startedAt: startedAt,
            trigger: trigger
        )
    }

    private func prepareAndSpawn(
        task: Task,
        command: String,
        runId: String,
        startedAt: String,
        trigger: String
    ) async throws -> Int32 {
        let header = """
        Task: \(task.id)
        Trigger: \(trigger)
        Started: \(startedAt)
        Command: \(command)
        \(String(repeating: "=", count: 50))
        
        """
        try await repository.writeOutput(id: runId, content: header)

        let scriptContent = createScript(
            task: task,
            command: command,
            runId: runId,
            startedAt: startedAt,
            trigger: trigger
        )

        let scriptPath = dataDir.appendingPathComponent("runs/.\(runId).sh")
        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = ["/bin/bash", scriptPath.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        if let workdir = task.workdir {
            process.currentDirectoryURL = URL(fileURLWithPath: workdir)
        }

        try process.run()
        return process.processIdentifier
    }
}

public struct ExecutionResult: Sendable {
    public let id: String
    public let exitCode: Int
    public let output: String
    
    public init(id: String, exitCode: Int, output: String) {
        self.id = id
        self.exitCode = exitCode
        self.output = output
    }
}

public enum ExecutorError: Error {
    case missingCommand
}
