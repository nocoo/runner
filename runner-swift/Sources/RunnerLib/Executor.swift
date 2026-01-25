import Foundation
import Darwin

/// Task executor - just runs shell commands
public struct Executor {
    public let storage: Storage
    public let dryRun: Bool
    public let verbose: Bool
    
    public init(storage: Storage, dryRun: Bool, verbose: Bool) {
        self.storage = storage
        self.dryRun = dryRun
        self.verbose = verbose
    }
    
    public func log(_ message: String) {
        if verbose {
            FileHandle.standardError.write("[DEBUG] \(message)\n".data(using: .utf8)!)
        }
    }
    
    /// Execute a task
    public func execute(task: Task, trigger: String) async throws -> ExecutionResult {
        let runId = UUID().uuidString
        let startedAt = ISO8601DateFormatter().string(from: Date())
        let startEpoch = Int64(Date().timeIntervalSince1970)
        
        log("Run ID: \(runId)")
        log("Started at: \(startedAt)")
        log("Command: \(task.command)")
        
        if dryRun {
            return ExecutionResult(
                id: runId,
                exitCode: 0,
                output: "[DRY RUN] Would execute: \(task.command)"
            )
        }
        
        // Write output header
        let header = """
        Task: \(task.id)
        Trigger: \(trigger)
        Started: \(startedAt)
        Command: \(task.command)
        \(String(repeating: "=", count: 50))
        
        """
        try await storage.writeOutput(id: runId, content: header)
        
        // Create wrapper script for background execution
        let scriptContent = createScript(
            task: task,
            runId: runId,
            startedAt: startedAt,
            trigger: trigger,
            dataDir: storage.dataDir
        )
        
        let scriptPath = storage.dataDir.appendingPathComponent("runs/.\(runId).sh")
        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        
        // Spawn detached process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = ["/bin/bash", scriptPath.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        if let workdir = task.workdir {
            process.currentDirectoryURL = URL(fileURLWithPath: workdir)
        }
        
        try process.run()
        let pid = process.processIdentifier
        
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
        try await storage.addRun(summary)
        
        log("Background PID: \(pid)")
        
        return ExecutionResult(id: runId, exitCode: 0, output: "Task started in background")
    }
    
    /// Create shell script that executes command and updates storage
    private func createScript(task: Task, runId: String, startedAt: String, trigger: String, dataDir: URL) -> String {
        let escapedCommand = task.command.replacingOccurrences(of: "'", with: "'\"'\"'")
        let workdir = task.workdir ?? "."
        let outputPath = dataDir.appendingPathComponent("runs/\(runId).output").path
        let detailPath = dataDir.appendingPathComponent("runs/\(runId).json").path
        let indexPath = dataDir.appendingPathComponent("runs/index.json").path
        
        return """
        #!/bin/bash
        
        # Load environment (for launchd)
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        
        cd '\(workdir)'
        START_TIME=$(date +%s)
        
        # Execute command
        eval '\(escapedCommand)' >> '\(outputPath)' 2>&1
        EXIT_CODE=$?
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        FINISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Write detail JSON
        cat > '\(detailPath)' << EOF
        {
          "id": "\(runId)",
          "task": "\(task.id)",
          "trigger": "\(trigger)",
          "started_at": "\(startedAt)",
          "finished_at": "$FINISHED_AT",
          "duration_seconds": $DURATION,
          "exit_code": $EXIT_CODE
        }
        EOF
        
        # Update index.json atomically
        if command -v jq &> /dev/null; then
            jq --arg id "\(runId)" \\
               --argjson exit_code "$EXIT_CODE" \\
               --arg finished_at "$FINISHED_AT" \\
               '(.runs[] | select(.id == $id)) |= . + {exit_code: $exit_code, finished_at: $finished_at, pid: null}' \\
               '\(indexPath)' > '\(indexPath).tmp' && mv '\(indexPath).tmp' '\(indexPath)'
        fi
        
        # Cleanup script
        rm -f "$0"
        """
    }
}

public struct ExecutionResult {
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
