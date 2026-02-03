import Foundation

public struct ScriptBuilder {
    public let dataDir: URL
    public let runnerPath: String

    public init(dataDir: URL, runnerPath: String? = nil) {
        self.dataDir = dataDir
        // Get the runner binary path, default to the current executable
        self.runnerPath = runnerPath ?? CommandLine.arguments[0]
    }

    public func build(
        task: Task,
        command: String,
        runId: String,
        startedAt: String,
        trigger: String
    ) -> String {
        let escapedCommand = command.replacingOccurrences(of: "'", with: "'\"'\"'")
        let workdir = task.workdir ?? "."
        let timeout = task.effectiveTimeout
        let outputPath = dataDir.appendingPathComponent("runs/\(runId).output").path

        return """
        #!/bin/bash

        # Load environment (for launchd)
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

        cd '\(workdir)'
        START_TIME=$(date +%s)
        TIMEOUT=\(timeout)

        # Execute command with timeout using background process monitoring
        eval '\(escapedCommand)' >> '\(outputPath)' 2>&1 &
        CMD_PID=$!

        # Monitor for timeout
        ELAPSED=0
        while kill -0 $CMD_PID 2>/dev/null; do
            sleep 1
            ELAPSED=$((ELAPSED + 1))
            if [ $ELAPSED -ge $TIMEOUT ]; then
                echo "" >> '\(outputPath)'
                echo "=== TIMEOUT: Task exceeded ${TIMEOUT}s limit, killing process ===" >> '\(outputPath)'
                kill -TERM $CMD_PID 2>/dev/null
                sleep 2
                kill -9 $CMD_PID 2>/dev/null
                wait $CMD_PID 2>/dev/null
                EXIT_CODE=124  # Standard timeout exit code
                break
            fi
        done

        # Get exit code if not timed out
        if [ -z "$EXIT_CODE" ]; then
            wait $CMD_PID
            EXIT_CODE=$?
        fi

        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))

        # Callback to Swift to update storage (single write point)
        '\(runnerPath)' complete '\(runId)' \\
            --exit-code $EXIT_CODE \\
            --duration $DURATION \\
            --data-dir '\(dataDir.path)'

        # Cleanup script
        rm -f "$0"
        """
    }
}
