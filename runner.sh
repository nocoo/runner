#!/bin/bash
# =============================================================================
# Runner - Task Scheduler
# =============================================================================
# A declarative task scheduler that routes tasks based on time and executes
# them via opencode.
#
# Usage: ./runner.sh <command> [options]
#
# Commands:
#   auto                    Select and execute task based on current time
#   <task_name>             Execute specified task
#   list                    List all available tasks
#   api <endpoint> [args]   Output JSON data for API
#
# Options:
#   --dry-run               Preview prompt without execution
#   --verbose               Enable debug output
#   --help                  Show this help message
#   --version               Show version
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via environment variables (for testing)
RUNNER_DATA_DIR="${RUNNER_DATA_DIR:-$SCRIPT_DIR/data}"
RUNNER_LOGS_DIR="${RUNNER_LOGS_DIR:-$SCRIPT_DIR/logs}"

VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "0.0.0")

# Notification script path
NOTIFIER_SCRIPT="$HOME/.claude/skills/task-notifier/scripts/notify.py"

# =============================================================================
# Global Variables
# =============================================================================

DRY_RUN=false
VERBOSE=false
TRIGGER_TYPE="manual"

# =============================================================================
# Utility Functions
# =============================================================================

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_info() {
    echo "[INFO] $*" >&2
}

# Get current time (with mock support for testing)
get_current_hour() {
    if [[ -n "${RUNNER_MOCK_HOUR:-}" ]]; then
        echo "$RUNNER_MOCK_HOUR"
    else
        date +%H | sed 's/^0//'
    fi
}

get_current_minute() {
    if [[ -n "${RUNNER_MOCK_MINUTE:-}" ]]; then
        echo "$RUNNER_MOCK_MINUTE"
    else
        date +%M | sed 's/^0//'
    fi
}

get_current_weekday() {
    if [[ -n "${RUNNER_MOCK_WEEKDAY:-}" ]]; then
        echo "$RUNNER_MOCK_WEEKDAY"
    else
        date +%w
    fi
}

# Generate UUID
generate_uuid() {
    uuidgen | tr '[:upper:]' '[:lower:]'
}

# Get ISO 8601 timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Ensure data directories exist
ensure_data_dirs() {
    mkdir -p "$RUNNER_DATA_DIR/runs"
    mkdir -p "$RUNNER_LOGS_DIR"

    # Initialize index.json if not exists
    if [[ ! -f "$RUNNER_DATA_DIR/runs/index.json" ]]; then
        echo '{"runs":[],"total":0,"updated_at":""}' > "$RUNNER_DATA_DIR/runs/index.json"
    fi

    # Initialize state.json if not exists
    if [[ ! -f "$RUNNER_DATA_DIR/state.json" ]]; then
        echo "{\"version\":\"$VERSION\"}" > "$RUNNER_DATA_DIR/state.json"
    fi

    # Initialize default tasks.json if not exists
    if [[ ! -f "$RUNNER_DATA_DIR/tasks.json" ]]; then
        cat > "$RUNNER_DATA_DIR/tasks.json" << 'EOF'
[
  {
    "id": "heartbeat",
    "type": "simple",
    "description": "Heartbeat - play a soft pop sound every 10 minutes",
    "timeout": 10,
    "command": "afplay /System/Library/Sounds/Pop.aiff",
    "prompt": null,
    "workdir": null
  },
  {
    "id": "clock",
    "type": "agent",
    "description": "Clock chime - announce time with text-to-speech",
    "timeout": 60,
    "command": null,
    "prompt": "用 say -v Tingting 命令播报当前时间，格式：「现在是 X 点 Y 分」，整点说「X点整」。只执行 say 命令。",
    "workdir": null
  }
]
EOF
    fi

    # Initialize default schedules.json if not exists
    if [[ ! -f "$RUNNER_DATA_DIR/schedules.json" ]]; then
        cat > "$RUNNER_DATA_DIR/schedules.json" << 'EOF'
[
  { "task": "clock", "hour": "*", "minute": 0, "weekday": "*" },
  { "task": "clock", "hour": "*", "minute": 30, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 10, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 20, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 40, "weekday": "*" },
  { "task": "heartbeat", "hour": "*", "minute": 50, "weekday": "*" }
]
EOF
    fi
}

# =============================================================================
# Crontab Expression Parser
# =============================================================================
# Supported syntax:
#   *     - any value
#   N     - exact value (e.g., 9)
#   N,M   - list of values (e.g., "0,15,30,45")
#   N-M   - range of values (e.g., "9-17")
#   */N   - step/interval (e.g., "*/10")
# =============================================================================

# Check if a value matches a crontab expression
# Usage: cron_match <expression> <value> <min> <max>
# Returns: 0 if matches, 1 if not
cron_match() {
    local expr="$1"
    local value="$2"
    local min="$3"
    local max="$4"
    
    # Remove leading zeros from value for comparison (08 -> 8)
    value=$((10#$value))
    
    # Wildcard: matches everything
    if [[ "$expr" == "*" ]]; then
        return 0
    fi
    
    # Step expression: */N
    if [[ "$expr" =~ ^\*/([0-9]+)$ ]]; then
        local step="${BASH_REMATCH[1]}"
        if [[ "$step" -eq 0 ]]; then
            return 1  # Invalid step
        fi
        if (( value % step == 0 )); then
            return 0
        fi
        return 1
    fi
    
    # Range expression: N-M
    if [[ "$expr" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local range_start="${BASH_REMATCH[1]}"
        local range_end="${BASH_REMATCH[2]}"
        if (( value >= range_start && value <= range_end )); then
            return 0
        fi
        return 1
    fi
    
    # List expression: N,M,O
    if [[ "$expr" =~ , ]]; then
        IFS=',' read -ra values <<< "$expr"
        for v in "${values[@]}"; do
            # Each value in list could be a number
            if [[ "$v" == "$value" ]]; then
                return 0
            fi
        done
        return 1
    fi
    
    # Exact value: N
    if [[ "$expr" =~ ^[0-9]+$ ]]; then
        if [[ "$((10#$expr))" -eq "$value" ]]; then
            return 0
        fi
        return 1
    fi
    
    # Unknown expression format
    return 1
}

# =============================================================================
# Configuration Validation
# =============================================================================

# Validate a crontab expression
# Usage: validate_cron_expr <expr> <field_name> <min> <max>
validate_cron_expr() {
    local expr="$1"
    local field="$2"
    local min="$3"
    local max="$4"
    
    # Wildcard is always valid
    if [[ "$expr" == "*" ]]; then
        return 0
    fi
    
    # Step expression: */N
    if [[ "$expr" =~ ^\*/([0-9]+)$ ]]; then
        local step="${BASH_REMATCH[1]}"
        if [[ "$step" -eq 0 ]]; then
            echo "Invalid $field: step value cannot be 0"
            return 1
        fi
        if [[ "$step" -gt "$max" ]]; then
            echo "Invalid $field: step value $step exceeds maximum $max"
            return 1
        fi
        return 0
    fi
    
    # Range expression: N-M
    if [[ "$expr" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local range_start="${BASH_REMATCH[1]}"
        local range_end="${BASH_REMATCH[2]}"
        if [[ "$range_start" -lt "$min" ]] || [[ "$range_start" -gt "$max" ]]; then
            echo "Invalid $field: range start $range_start outside $min-$max"
            return 1
        fi
        if [[ "$range_end" -lt "$min" ]] || [[ "$range_end" -gt "$max" ]]; then
            echo "Invalid $field: range end $range_end outside $min-$max"
            return 1
        fi
        if [[ "$range_start" -gt "$range_end" ]]; then
            echo "Invalid $field: range start $range_start > end $range_end"
            return 1
        fi
        return 0
    fi
    
    # List expression: N,M,O
    if [[ "$expr" =~ , ]]; then
        IFS=',' read -ra values <<< "$expr"
        for v in "${values[@]}"; do
            if ! [[ "$v" =~ ^[0-9]+$ ]]; then
                echo "Invalid $field: list contains non-numeric value '$v'"
                return 1
            fi
            if [[ "$v" -lt "$min" ]] || [[ "$v" -gt "$max" ]]; then
                echo "Invalid $field: value $v outside $min-$max"
                return 1
            fi
        done
        return 0
    fi
    
    # Exact value: N
    if [[ "$expr" =~ ^-?[0-9]+$ ]]; then
        if [[ "$expr" -lt "$min" ]] || [[ "$expr" -gt "$max" ]]; then
            echo "Invalid $field: value $expr outside $min-$max"
            return 1
        fi
        return 0
    fi
    
    echo "Invalid $field: unrecognized expression '$expr'"
    return 1
}

# Validate entire configuration file
# Validate configuration from JSON files
validate_config() {
    local errors=()
    local has_errors=false

    # Ensure data directories exist
    ensure_data_dirs

    # Check tasks.json exists
    if [[ ! -f "$RUNNER_DATA_DIR/tasks.json" ]]; then
        echo "[ERROR] tasks.json not found. Run './runner.sh api init' to initialize."
        return 1
    fi

    # Check schedules.json exists
    if [[ ! -f "$RUNNER_DATA_DIR/schedules.json" ]]; then
        echo "[ERROR] schedules.json not found. Run './runner.sh api init' to initialize."
        return 1
    fi

    # Validate JSON syntax
    if ! cat "$RUNNER_DATA_DIR/tasks.json" | jq '.' > /dev/null 2>&1; then
        echo "[ERROR] Invalid JSON syntax in tasks.json"
        return 1
    fi

    if ! cat "$RUNNER_DATA_DIR/schedules.json" | jq '.' > /dev/null 2>&1; then
        echo "[ERROR] Invalid JSON syntax in schedules.json"
        return 1
    fi

    # Validate schedules
    local schedules=$(cat "$RUNNER_DATA_DIR/schedules.json")
    local schedule_count=$(echo "$schedules" | jq 'length')

    for ((i=0; i<schedule_count; i++)); do
        local schedule=$(echo "$schedules" | jq ".[$i]")
        local task=$(echo "$schedule" | jq -r '.task // empty')
        local hour=$(echo "$schedule" | jq -r '.hour // empty')
        local minute=$(echo "$schedule" | jq -r '.minute // "0"')
        local weekday=$(echo "$schedule" | jq -r '.weekday // empty')

        local prefix="Schedule #$((i+1))"

        # Required fields
        if [[ -z "$task" ]]; then
            errors+=("$prefix: missing 'task' field")
            has_errors=true
            continue
        fi

        if [[ -z "$hour" ]]; then
            errors+=("$prefix ($task): missing 'hour' field")
            has_errors=true
        fi

        if [[ -z "$weekday" ]]; then
            errors+=("$prefix ($task): missing 'weekday' field")
            has_errors=true
        fi

        # Validate crontab expressions
        local result
        if [[ -n "$hour" ]]; then
            result=$(validate_cron_expr "$hour" "hour" 0 23) || {
                errors+=("$prefix ($task): $result")
                has_errors=true
            }
        fi

        if [[ -n "$minute" ]]; then
            result=$(validate_cron_expr "$minute" "minute" 0 59) || {
                errors+=("$prefix ($task): $result")
                has_errors=true
            }
        fi

        if [[ -n "$weekday" ]]; then
            result=$(validate_cron_expr "$weekday" "weekday" 0 6) || {
                errors+=("$prefix ($task): $result")
                has_errors=true
            }
        fi

        # Check task exists in tasks.json
        if [[ -n "$task" ]] && ! task_exists "$task"; then
            errors+=("$prefix: task '$task' not found in tasks.json")
            has_errors=true
        fi
    done

    # Validate tasks
    local tasks=$(cat "$RUNNER_DATA_DIR/tasks.json")
    local task_count=$(echo "$tasks" | jq 'length')

    for ((i=0; i<task_count; i++)); do
        local task=$(echo "$tasks" | jq ".[$i]")
        local task_id=$(echo "$task" | jq -r '.id // empty')
        local task_type=$(echo "$task" | jq -r '.type // "agent"')
        local description=$(echo "$task" | jq -r '.description // empty')
        local timeout=$(echo "$task" | jq -r '.timeout // empty')
        local workdir=$(echo "$task" | jq -r '.workdir // empty')
        local command=$(echo "$task" | jq -r '.command // empty')
        local prompt=$(echo "$task" | jq -r '.prompt // empty')

        # Required fields
        if [[ -z "$task_id" ]]; then
            errors+=("Task #$((i+1)): missing 'id' field")
            has_errors=true
            continue
        fi

        if [[ -z "$description" ]]; then
            errors+=("Task '$task_id': missing 'description' field")
            has_errors=true
        fi

        if [[ -z "$timeout" ]]; then
            errors+=("Task '$task_id': missing 'timeout' field")
            has_errors=true
        elif ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ "$timeout" -le 0 ]]; then
            errors+=("Task '$task_id': timeout must be a positive integer")
            has_errors=true
        fi

        # Type-specific validation
        if [[ "$task_type" == "simple" ]]; then
            # Simple type requires command
            if [[ -z "$command" ]]; then
                errors+=("Task '$task_id' (simple): missing 'command' field")
                has_errors=true
            fi
        elif [[ "$task_type" == "agent" ]]; then
            # Agent type requires prompt
            if [[ -z "$prompt" ]]; then
                errors+=("Task '$task_id' (agent): missing 'prompt' field")
                has_errors=true
            fi
        else
            errors+=("Task '$task_id': invalid type '$task_type' (must be 'simple' or 'agent')")
            has_errors=true
        fi

        # Check workdir exists if specified
        if [[ -n "$workdir" ]] && [[ ! -d "$workdir" ]]; then
            errors+=("Task '$task_id': workdir does not exist: $workdir")
            has_errors=true
        fi
    done

    # Output results
    if [[ "$has_errors" == true ]]; then
        echo "[ERROR] Configuration validation failed:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    fi

    echo "[OK] Configuration is valid"
    return 0
}

# =============================================================================
# Task Functions (JSON-based)
# =============================================================================

# Load tasks from JSON file
load_tasks() {
    ensure_data_dirs
    cat "$RUNNER_DATA_DIR/tasks.json"
}

# Load schedules from JSON file
load_schedules() {
    ensure_data_dirs
    cat "$RUNNER_DATA_DIR/schedules.json"
}

# List all tasks from JSON config
list_tasks() {
    ensure_data_dirs

    if [[ ! -s "$RUNNER_DATA_DIR/tasks.json" ]]; then
        log_error "No tasks found. Run './runner.sh api init' to initialize."
        exit 1
    fi

    echo "Available tasks:"
    echo ""
    cat "$RUNNER_DATA_DIR/tasks.json" | jq -r '.[] | "  \(.id) [\(.type // "agent")] - \(.description // "No description")"'
}

# Check if task exists
task_exists() {
    local task_name="$1"
    cat "$RUNNER_DATA_DIR/tasks.json" | jq -e --arg task "$task_name" '.[] | select(.id == $task)' > /dev/null 2>&1
}

# Get task type (simple or agent)
get_task_type() {
    local task_name="$1"
    cat "$RUNNER_DATA_DIR/tasks.json" | jq --arg task "$task_name" -r '.[] | select(.id == $task) | .type // "agent"'
}

# Get task command (for simple type)
get_task_command() {
    local task_name="$1"
    cat "$RUNNER_DATA_DIR/tasks.json" | jq --arg task "$task_name" -r '.[] | select(.id == $task) | .command // ""'
}

# Get task prompt (for agent type)
get_task_prompt() {
    local task_name="$1"
    cat "$RUNNER_DATA_DIR/tasks.json" | jq --arg task "$task_name" -r '.[] | select(.id == $task) | .prompt // ""'
}

# Get task timeout
get_task_timeout() {
    local task_name="$1"
    cat "$RUNNER_DATA_DIR/tasks.json" | jq --arg task "$task_name" -r '.[] | select(.id == $task) | .timeout // 300'
}

# Get task workdir
get_task_workdir() {
    local task_name="$1"
    cat "$RUNNER_DATA_DIR/tasks.json" | jq --arg task "$task_name" -r '.[] | select(.id == $task) | .workdir // ""'
}

# Find task for current time (auto mode)
find_scheduled_task() {
    local current_hour=$(get_current_hour)
    local current_minute=$(get_current_minute)
    local current_weekday=$(get_current_weekday)

    log_debug "Current time: hour=$current_hour, minute=$current_minute, weekday=$current_weekday"

    # Query schedules from JSON
    local schedules=$(load_schedules)
    local count=$(echo "$schedules" | jq 'length')

    for ((i=0; i<count; i++)); do
        local schedule=$(echo "$schedules" | jq ".[$i]")
        local task=$(echo "$schedule" | jq -r '.task')
        local hour=$(echo "$schedule" | jq -r '.hour')
        local minute=$(echo "$schedule" | jq -r '.minute // "0"')
        local weekday=$(echo "$schedule" | jq -r '.weekday')

        log_debug "Checking schedule: task=$task, hour=$hour, minute=$minute, weekday=$weekday"

        # Use crontab matcher for all fields
        if ! cron_match "$hour" "$current_hour" 0 23; then
            continue
        fi

        if ! cron_match "$minute" "$current_minute" 0 59; then
            continue
        fi

        if ! cron_match "$weekday" "$current_weekday" 0 6; then
            continue
        fi

        log_debug "Match found: $task"
        echo "$task"
        # Continue to find all matches, don't return early
    done
}

# Get task model (for agent type, default: zai-coding-plan/glm-4.7)
get_task_model() {
    local task_name="$1"
    local model=$(cat "$RUNNER_DATA_DIR/tasks.json" | jq --arg task "$task_name" -r '.[] | select(.id == $task) | .model // ""')
    if [[ -z "$model" ]]; then
        echo "zai-coding-plan/glm-4.7"
    else
        echo "$model"
    fi
}

# =============================================================================
# Execution Functions
# =============================================================================

# Execute a task
execute_task() {
    local task_name="$1"

    log_debug "Executing task: $task_name"

    # Validate task exists
    if ! task_exists "$task_name"; then
        log_error "Task not found: $task_name"
        exit 1
    fi

    # Get task type and configuration
    local task_type=$(get_task_type "$task_name")
    local workdir=$(get_task_workdir "$task_name")

    log_debug "Task type: $task_type"
    log_debug "Workdir: ${workdir:-<default>}"

    # Get command/prompt based on type
    local command=""
    local prompt=""

    if [[ "$task_type" == "simple" ]]; then
        command=$(get_task_command "$task_name")
        if [[ -z "$command" ]]; then
            log_error "Simple task '$task_name' has no command"
            exit 1
        fi
        log_debug "Command: $command"
    else
        # Agent type - get prompt from JSON
        prompt=$(get_task_prompt "$task_name")
        if [[ -z "$prompt" ]]; then
            log_error "Agent task '$task_name' has no prompt"
            exit 1
        fi
        log_debug "Prompt length: ${#prompt} chars"
    fi

    # Dry run mode - show what would be executed
    if [[ "$DRY_RUN" == true ]]; then
        echo "# Task: $task_name"
        echo "# Type: $task_type"
        echo "# Workdir: ${workdir:-<default>}"
        if [[ "$task_type" == "agent" ]]; then
            local model=$(get_task_model "$task_name")
            echo "# Model: $model"
        fi
        echo ""
        if [[ "$task_type" == "simple" ]]; then
            echo "Command: $command"
        else
            echo "$prompt"
        fi
        return 0
    fi

    # Ensure data directories exist
    ensure_data_dirs

    # Record start time
    local run_id=$(generate_uuid)
    local started_at=$(get_timestamp)
    local start_seconds=$(date +%s)

    log_debug "Run ID: $run_id"
    log_debug "Started at: $started_at"

    # Execute based on task type
    local output=""
    local exit_code=0

    set +e
    if [[ "$task_type" == "simple" ]]; then
        # Simple type: execute command directly
        log_debug "Executing simple command"
        if [[ -n "$workdir" && -d "$workdir" ]]; then
            output=$(cd "$workdir" && eval "$command" 2>&1)
        else
            output=$(eval "$command" 2>&1)
        fi
        exit_code=$?
        # Add descriptive output for simple tasks
        if [[ $exit_code -eq 0 ]]; then
            output="Command executed successfully: $command"
        else
            output="Command failed (exit $exit_code): $command\n$output"
        fi
    else
        # Agent type: execute via opencode
        log_debug "Executing agent task via opencode"
        local model=$(get_task_model "$task_name")
        log_debug "Using model: $model"

        if [[ -n "$workdir" && -d "$workdir" ]]; then
            output=$(cd "$workdir" && opencode run "$prompt" --agent build --model "$model" 2>&1)
        else
            output=$(opencode run "$prompt" --agent build --model "$model" 2>&1)
        fi
        exit_code=$?
    fi
    set -e

    # Record end time
    local finished_at=$(get_timestamp)
    local end_seconds=$(date +%s)
    local duration=$((end_seconds - start_seconds))

    log_debug "Finished at: $finished_at"
    log_debug "Duration: ${duration}s"
    log_debug "Exit code: $exit_code"

    # Truncate output for preview
    local output_preview="${output:0:500}"

    # Write run log
    local run_file="$RUNNER_DATA_DIR/runs/${run_id}.json"
    cat > "$run_file" << EOF
{
  "id": "$run_id",
  "task": "$task_name",
  "trigger": "$TRIGGER_TYPE",
  "started_at": "$started_at",
  "finished_at": "$finished_at",
  "duration_seconds": $duration,
  "exit_code": $exit_code,
  "output_preview": $(echo "$output_preview" | jq -Rs '.')
}
EOF

    log_debug "Run log written: $run_file"

    # Update index (duration in ms for frontend)
    local duration_ms=$((duration * 1000))
    update_runs_index "$run_id" "$task_name" "$exit_code" "$finished_at" "$duration_ms"

    # Update state
    update_state "$run_id" "$task_name" "$exit_code" "$finished_at"

    # Send notification
    send_notification "$task_name" "$exit_code" "$duration"

    # Return with appropriate exit code
    if [[ "$exit_code" -ne 0 ]]; then
        exit "$exit_code"
    fi
}

# Update runs index
update_runs_index() {
    local run_id="$1"
    local task="$2"
    local exit_code="$3"
    local finished_at="$4"
    local duration_ms="$5"
    
    local index_file="$RUNNER_DATA_DIR/runs/index.json"
    local temp_file=$(mktemp)
    
    # Add new run to index (with duration_ms)
    jq --arg id "$run_id" \
       --arg task "$task" \
       --argjson exit_code "$exit_code" \
       --arg finished_at "$finished_at" \
       --argjson duration_ms "$duration_ms" \
       --arg updated_at "$(get_timestamp)" \
       '.runs += [{"id": $id, "task": $task, "exit_code": $exit_code, "finished_at": $finished_at, "duration_ms": $duration_ms}] | .total = (.runs | length) | .updated_at = $updated_at' \
       "$index_file" > "$temp_file"
    
    mv "$temp_file" "$index_file"
    log_debug "Index updated"
}

# Update state
update_state() {
    local run_id="$1"
    local task="$2"
    local exit_code="$3"
    local finished_at="$4"
    
    local state_file="$RUNNER_DATA_DIR/state.json"
    local temp_file=$(mktemp)
    
    # Calculate today's stats
    local today=$(date +%Y-%m-%d)
    local today_runs=$(jq "[.runs[] | select(.finished_at | startswith(\"$today\"))]" "$RUNNER_DATA_DIR/runs/index.json")
    local total_today=$(echo "$today_runs" | jq 'length')
    local success_today=$(echo "$today_runs" | jq '[.[] | select(.exit_code == 0)] | length')
    local success_rate=0
    if [[ "$total_today" -gt 0 ]]; then
        success_rate=$(echo "scale=2; $success_today / $total_today" | bc)
    fi
    
    # Update state
    jq -n \
       --arg version "$VERSION" \
       --arg id "$run_id" \
       --arg task "$task" \
       --argjson exit_code "$exit_code" \
       --arg finished_at "$finished_at" \
       --argjson total_runs_today "$total_today" \
       --argjson success_rate_today "$success_rate" \
       '{
         version: $version,
         last_run: {id: $id, task: $task, exit_code: $exit_code, finished_at: $finished_at},
         next_scheduled: null,
         total_runs_today: $total_runs_today,
         success_rate_today: $success_rate_today
       }' > "$temp_file"
    
    mv "$temp_file" "$state_file"
    log_debug "State updated"
}

# Send notification
send_notification() {
    local task="$1"
    local exit_code="$2"
    local duration="$3"
    
    # Skip if disabled
    if [[ "${RUNNER_SKIP_NOTIFY:-}" == "1" ]]; then
        log_debug "Notifications disabled"
        return 0
    fi
    
    # Skip if notifier not found
    if [[ ! -f "$NOTIFIER_SCRIPT" ]]; then
        log_debug "Notifier not found: $NOTIFIER_SCRIPT"
        return 0
    fi
    
    local level="success"
    local message="✅ $task completed (${duration}s)"
    
    if [[ "$exit_code" -ne 0 ]]; then
        level="error"
        message="❌ $task failed (exit code: $exit_code)"
    fi
    
    python3 "$NOTIFIER_SCRIPT" "$message" "$level" 2>/dev/null || true
    log_debug "Notification sent: $level"
}

# =============================================================================
# API Functions
# =============================================================================

api_tasks() {
    cat "$RUNNER_DATA_DIR/tasks.json"
}

api_schedules() {
    cat "$RUNNER_DATA_DIR/schedules.json"
}

api_runs() {
    local run_id="${1:-}"
    
    ensure_data_dirs
    
    if [[ -n "$run_id" ]]; then
        local run_file="$RUNNER_DATA_DIR/runs/${run_id}.json"
        if [[ ! -f "$run_file" ]]; then
            log_error "Run not found: $run_id"
            exit 1
        fi
        cat "$run_file"
    else
        cat "$RUNNER_DATA_DIR/runs/index.json"
    fi
}

api_status() {
    ensure_data_dirs
    cat "$RUNNER_DATA_DIR/state.json"
}

api_init() {
    ensure_data_dirs
    log_info "API data files initialized"
}

handle_api() {
    local endpoint="${1:-}"
    shift || true

    case "$endpoint" in
        tasks)
            ensure_data_dirs
            api_tasks
            ;;
        schedules)
            ensure_data_dirs
            api_schedules
            ;;
        runs)
            api_runs "$@"
            ;;
        status)
            api_status
            ;;
        init)
            api_init
            ;;
        "")
            log_error "No endpoint specified"
            echo ""
            echo "Available endpoints:"
            echo "  tasks      - List all tasks"
            echo "  schedules  - List schedules"
            echo "  runs [id]  - List runs or get run details"
            echo "  status     - Get system status"
            echo "  init       - Initialize data files"
            exit 1
            ;;
        *)
            log_error "Unknown API endpoint: $endpoint"
            exit 1
            ;;
    esac
}

# =============================================================================
# CLI Functions
# =============================================================================

show_usage() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  auto                    Select and execute task based on current time
  <task_name>             Execute specified task
  list                    List all available tasks
  validate                Validate configuration file
  api <endpoint> [args]   Output JSON data for API

API Endpoints:
  api tasks               List all tasks
  api schedules           List schedules
  api runs [id]           List runs or get run details
  api status              Get system status
  api init                Initialize data files

Options:
  --dry-run               Preview prompt without execution
  --verbose               Enable debug output
  --help                  Show this help message
  --version               Show version

Examples:
  $(basename "$0") auto                    # Auto-select and run task
  $(basename "$0") morning_briefing        # Run specific task
  $(basename "$0") morning_briefing --dry-run   # Preview prompt
  $(basename "$0") validate                # Validate config
  $(basename "$0") api runs                # Get execution history
EOF
}

show_version() {
    echo "$VERSION"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local command=""
    local args=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            --*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # No command provided
    if [[ -z "$command" ]]; then
        show_usage
        exit 1
    fi
    
    log_debug "Command: $command"
    log_debug "Args: ${args[*]:-}"
    log_debug "Dry run: $DRY_RUN"
    
    # Handle commands
    case "$command" in
        auto)
            TRIGGER_TYPE="auto"
            local tasks=$(find_scheduled_task)
            if [[ -z "$tasks" ]]; then
                log_debug "No task scheduled for current time"
                exit 0  # Silent exit
            fi
            
            # Deduplicate tasks (same task may match multiple schedules)
            local unique_tasks=$(echo "$tasks" | sort -u)
            local task_count=$(echo "$unique_tasks" | wc -l | tr -d ' ')
            
            log_debug "Found $task_count unique task(s) to execute"
            
            if [[ "$task_count" -eq 1 ]]; then
                # Single task: execute directly
                execute_task "$unique_tasks"
            else
                # Multiple tasks: execute in parallel
                local pids=()
                while IFS= read -r task; do
                    [[ -z "$task" ]] && continue
                    log_debug "Starting parallel task: $task"
                    execute_task "$task" &
                    pids+=($!)
                done <<< "$unique_tasks"
                
                # Wait for all tasks to complete
                for pid in "${pids[@]}"; do
                    wait "$pid" 2>/dev/null || true
                done
            fi
            ;;
        list)
            list_tasks
            ;;
        validate)
            validate_config
            ;;
        api)
            handle_api "${args[@]:-}"
            ;;
        *)
            # Assume it's a task name
            execute_task "$command"
            ;;
    esac
}

main "$@"
