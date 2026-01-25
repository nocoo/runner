import Foundation
import Darwin

/// Task executor with proper process management
struct Executor {
    let storage: Storage
    let dryRun: Bool
    let verbose: Bool
    
    func log(_ message: String) {
        if verbose {
            FileHandle.standardError.write("[DEBUG] \(message)\n".data(using: .utf8)!)
        }
    }
    
    /// Execute a task
    func execute(task: Task, trigger: String) async throws -> ExecutionResult {
        let runId = UUID().uuidString.lowercased()
        let startedAt = ISO8601DateFormatter().string(from: Date())
        let startEpoch = Int64(Date().timeIntervalSince1970)
        
        log("Run ID: \(runId)")
        log("Started at: \(startedAt)")
        
        if dryRun {
            return ExecutionResult(
                id: runId,
                exitCode: 0,
                output: "[DRY RUN] Would execute task: \(task.id)"
            )
        }
        
        switch task.type {
        case .simple:
            return try await executeSimple(task: task, runId: runId, startedAt: startedAt, trigger: trigger)
        case .agent:
            return try await executeAgent(task: task, runId: runId, startedAt: startedAt, startEpoch: startEpoch, trigger: trigger)
        case .manual:
            return ExecutionResult(id: runId, exitCode: 0, output: "Manual task - not executed")
        }
    }
    
    /// Execute simple (shell command) task synchronously
    private func executeSimple(task: Task, runId: String, startedAt: String, trigger: String) async throws -> ExecutionResult {
        guard let command = task.command else {
            throw ExecutorError.missingCommand
        }
        
        log("Task type: simple")
        log("Command: \(command)")
        
        // Add to index
        let summary = RunSummary(
            id: runId,
            task: task.id,
            exitCode: nil,
            startedAt: startedAt,
            finishedAt: nil,
            pid: nil,
            startedAtEpoch: nil
        )
        try await storage.addRun(summary)
        
        // Write output header
        let header = """
        Task: \(task.id)
        Trigger: \(trigger)
        Started: \(startedAt)
        Command: \(command)
        \(String(repeating: "=", count: 50))
        
        """
        try await storage.writeOutput(id: runId, content: header)
        
        let start = Date()
        
        // Execute
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        if let workdir = task.workdir {
            process.currentDirectoryURL = URL(fileURLWithPath: workdir)
        }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let duration = Int(Date().timeIntervalSince(start))
        let exitCode = Int(process.terminationStatus)
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        // Append output
        try await storage.appendOutput(id: runId, content: output)
        
        let finishedAt = ISO8601DateFormatter().string(from: Date())
        
        // Update index
        try await storage.updateRun(id: runId, exitCode: exitCode, finishedAt: finishedAt)
        
        // Write detail
        let detail = RunDetail(
            id: runId,
            task: task.id,
            trigger: trigger,
            startedAt: startedAt,
            finishedAt: finishedAt,
            durationSeconds: duration,
            exitCode: exitCode
        )
        try await storage.writeRunDetail(detail)
        
        log("Duration: \(duration)s, Exit code: \(exitCode)")
        
        return ExecutionResult(id: runId, exitCode: exitCode, output: output)
    }
    
    /// Execute agent (opencode) task with proper process detachment using posix_spawn
    private func executeAgent(task: Task, runId: String, startedAt: String, startEpoch: Int64, trigger: String) async throws -> ExecutionResult {
        guard let prompt = task.prompt else {
            throw ExecutorError.missingPrompt
        }
        
        log("Task type: agent")
        log("Prompt length: \(prompt.count) chars")
        
        // Write output header
        let promptPreview = String(prompt.prefix(100))
        let header = """
        Task: \(task.id)
        Trigger: \(trigger)
        Started: \(startedAt)
        Prompt: \(promptPreview)
        \(String(repeating: "=", count: 50))
        
        """
        try await storage.writeOutput(id: runId, content: header)
        
        // Create a wrapper script that runs in background
        let scriptContent = createAgentScript(
            task: task,
            prompt: prompt,
            runId: runId,
            startedAt: startedAt,
            trigger: trigger,
            dataDir: storage.dataDir
        )
        
        let scriptPath = storage.dataDir.appendingPathComponent("runs/.\(runId).sh")
        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
        
        // Make executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        
        // Spawn detached process using nohup
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
        
        // Don't wait - let it run in background
        
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
    
    /// Create a shell script that executes the agent task and updates storage
    private func createAgentScript(task: Task, prompt: String, runId: String, startedAt: String, trigger: String, dataDir: URL) -> String {
        let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\"'\"'")
        let model = task.model ?? "sonnet"
        let workdir = task.workdir ?? "."
        let outputPath = dataDir.appendingPathComponent("runs/\(runId).output").path
        let detailPath = dataDir.appendingPathComponent("runs/\(runId).json").path
        let indexPath = dataDir.appendingPathComponent("runs/index.json").path
        let lockPath = dataDir.appendingPathComponent("runs/.index.lock").path
        
        return """
        #!/bin/bash
        
        # Run opencode and capture output
        cd '\(workdir)'
        START_TIME=$(date +%s)
        
        echo '\(escapedPrompt)' | /opt/homebrew/bin/opencode run --agent \(model) >> '\(outputPath)' 2>&1
        EXIT_CODE=$?
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        FINISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Write detail JSON
        cat > '\(detailPath)' << 'DETAIL_EOF'
        {
          "id": "\(runId)",
          "task": "\(task.id)",
          "trigger": "\(trigger)",
          "started_at": "\(startedAt)",
          "finished_at": "$FINISHED_AT",
          "duration_seconds": $DURATION,
          "exit_code": $EXIT_CODE
        }
        DETAIL_EOF
        
        # Update index.json with file lock
        (
            flock -x 200
            
            # Use jq to update if available, otherwise use sed
            if command -v jq &> /dev/null; then
                jq --arg id "\(runId)" \\
                   --argjson exit_code "$EXIT_CODE" \\
                   --arg finished_at "$FINISHED_AT" \\
                   '(.runs[] | select(.id == $id)) |= . + {exit_code: $exit_code, finished_at: $finished_at, pid: null}' \\
                   '\(indexPath)' > '\(indexPath).tmp' && mv '\(indexPath).tmp' '\(indexPath)'
            fi
        ) 200>'\(lockPath)'
        
        # Cleanup script
        rm -f "$0"
        """
    }
}

struct ExecutionResult {
    let id: String
    let exitCode: Int
    let output: String
}

enum ExecutorError: Error {
    case missingCommand
    case missingPrompt
    case forkFailed
}
