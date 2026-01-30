import Foundation

public struct ScriptBuilder {
    public let dataDir: URL

    public init(dataDir: URL) {
        self.dataDir = dataDir
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
        let detailPath = dataDir.appendingPathComponent("runs/\(runId).json").path
        let indexPath = dataDir.appendingPathComponent("runs/index.json").path

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
        FINISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Write detail JSON atomically using jq (type-safe, handles escaping)
        if command -v jq &> /dev/null; then
            jq -n \
               --arg id "\(runId)" \
               --arg task "\(task.id)" \
               --arg trigger "\(trigger)" \
               --arg started_at "\(startedAt)" \
               --arg finished_at "$FINISHED_AT" \
               --argjson duration_seconds "$DURATION" \
               --argjson exit_code "$EXIT_CODE" \
               '{id: $id, task: $task, trigger: $trigger, started_at: $started_at, finished_at: $finished_at, duration_seconds: $duration_seconds, exit_code: $exit_code}' \
               > '\(detailPath).tmp' && mv '\(detailPath).tmp' '\(detailPath)'
        fi

        # Update index.json atomically
        if command -v jq &> /dev/null; then
            jq --arg id "\(runId)" \
               --argjson exit_code "$EXIT_CODE" \
               --arg finished_at "$FINISHED_AT" \
               '(.runs[] | select(.id == $id)) |= . + {exit_code: $exit_code, finished_at: $finished_at, pid: null} | .total = (.runs | length) | .updated_at = $finished_at' \
               '\(indexPath)' > '\(indexPath).tmp' && mv '\(indexPath).tmp' '\(indexPath)'
        fi

        # Cleanup script
        rm -f "$0"
        """
    }
}
