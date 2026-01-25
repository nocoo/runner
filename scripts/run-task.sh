#!/bin/bash
# =============================================================================
# run-task.sh - Background task executor
# =============================================================================
# Executes tasks as independent process. Supports both simple (command) and
# agent (opencode) task types.
#
# Usage: run-task.sh <task_name> <task_type> <workdir> <command_or_prompt> \
#                    <run_id> <started_at> <start_seconds> <data_dir> \
#                    <trigger_type> [model]
# =============================================================================

# Load environment variables (needed for launchd which doesn't load shell config)
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc" 2>/dev/null || true

task_name="$1"
task_type="$2"
workdir="$3"
command_or_prompt="$4"
run_id="$5"
started_at="$6"
start_seconds="$7"
data_dir="$8"
trigger_type="$9"
model="${10:-zai-coding-plan/glm-4.7}"

# Notifier script path
NOTIFIER_SCRIPT="$HOME/.claude/skills/task-notifier/scripts/notify.py"

# Output file for complete task output
output_file="$data_dir/runs/${run_id}.output"

# =============================================================================
# Execution
# =============================================================================

exit_code=0

# Write header to output file
{
    echo "# Task: $task_name"
    echo "# Type: $task_type"
    echo "# Started: $started_at"
    echo "# Workdir: ${workdir:-<default>}"
    [[ "$task_type" != "simple" ]] && echo "# Model: $model"
    echo ""
} > "$output_file"

if [[ "$task_type" == "simple" ]]; then
    # Simple type: execute command directly
    echo "$ $command_or_prompt" >> "$output_file"
    echo "" >> "$output_file"
    if [[ -n "$workdir" && -d "$workdir" ]]; then
        (cd "$workdir" && eval "$command_or_prompt") >> "$output_file" 2>&1 || exit_code=$?
    else
        eval "$command_or_prompt" >> "$output_file" 2>&1 || exit_code=$?
    fi
else
    # Agent type: execute via opencode
    if [[ -n "$workdir" && -d "$workdir" ]]; then
        (cd "$workdir" && opencode run "$command_or_prompt" --agent build --model "$model") >> "$output_file" 2>&1 || exit_code=$?
    else
        opencode run "$command_or_prompt" --agent build --model "$model" >> "$output_file" 2>&1 || exit_code=$?
    fi
fi

# Append footer
{
    echo ""
    echo "# Exit code: $exit_code"
    echo "# Finished: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} >> "$output_file"

# =============================================================================
# Record Results
# =============================================================================

finished_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
end_seconds=$(date +%s)
duration=$((end_seconds - start_seconds))

# Write run metadata (output is in .output file)
run_file="$data_dir/runs/${run_id}.json"
cat > "$run_file" << EOF
{
  "id": "$run_id",
  "task": "$task_name",
  "trigger": "$trigger_type",
  "started_at": "$started_at",
  "finished_at": "$finished_at",
  "duration_seconds": $duration,
  "exit_code": $exit_code
}
EOF

# Update index with final exit_code and finished_at, clear pid
index_file="$data_dir/runs/index.json"
temp_file=$(mktemp)
jq --arg id "$run_id" \
   --argjson exit_code "$exit_code" \
   --arg finished_at "$finished_at" \
   '(.runs[] | select(.id == $id)) |= . + {exit_code: $exit_code, finished_at: $finished_at, pid: null}' \
   "$index_file" > "$temp_file" && mv "$temp_file" "$index_file"

# Update state
state_file="$data_dir/state.json"
temp_file=$(mktemp)
jq --arg run_id "$run_id" \
   --arg task "$task_name" \
   --argjson exit_code "$exit_code" \
   --arg finished_at "$finished_at" \
   '.last_run = {id: $run_id, task: $task, exit_code: $exit_code, finished_at: $finished_at}' \
   "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"

# =============================================================================
# Send Notification
# =============================================================================

if [[ "${RUNNER_SKIP_NOTIFY:-}" != "1" && -f "$NOTIFIER_SCRIPT" ]]; then
    if [[ "$exit_code" -eq 0 ]]; then
        python3 "$NOTIFIER_SCRIPT" "✅ $task_name completed (${duration}s)" "success" 2>/dev/null || true
    else
        python3 "$NOTIFIER_SCRIPT" "❌ $task_name failed (exit code: $exit_code)" "error" 2>/dev/null || true
    fi
fi

exit $exit_code
