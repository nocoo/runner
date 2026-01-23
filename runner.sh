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
RUNNER_CONFIG_FILE="${RUNNER_CONFIG_FILE:-$SCRIPT_DIR/tasks.yaml}"
RUNNER_TASKS_DIR="${RUNNER_TASKS_DIR:-$SCRIPT_DIR/tasks}"
RUNNER_DATA_DIR="${RUNNER_DATA_DIR:-$SCRIPT_DIR/data}"
RUNNER_SCHEMAS_DIR="${RUNNER_SCHEMAS_DIR:-$SCRIPT_DIR/schemas}"
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
}

# =============================================================================
# Task Functions
# =============================================================================

# List all tasks from config
list_tasks() {
    if [[ ! -f "$RUNNER_CONFIG_FILE" ]]; then
        log_error "Config file not found: $RUNNER_CONFIG_FILE"
        exit 1
    fi
    
    echo "Available tasks:"
    echo ""
    yq -o=json '.tasks' "$RUNNER_CONFIG_FILE" | jq -r 'to_entries[] | "  \(.key) - \(.value.description // "No description")"'
}

# Check if task exists
task_exists() {
    local task_name="$1"
    yq -e ".tasks.${task_name}" "$RUNNER_CONFIG_FILE" > /dev/null 2>&1
}

# Get prompt file path for task
get_prompt_file() {
    local task_name="$1"
    echo "$RUNNER_TASKS_DIR/${task_name}.md"
}

# Find task for current time (auto mode)
find_scheduled_task() {
    local current_hour=$(get_current_hour)
    local current_minute=$(get_current_minute)
    local current_weekday=$(get_current_weekday)
    
    log_debug "Current time: hour=$current_hour, minute=$current_minute, weekday=$current_weekday"
    
    # Query schedules from config
    local schedules=$(yq -o=json '.schedules' "$RUNNER_CONFIG_FILE")
    local count=$(echo "$schedules" | jq 'length')
    
    for ((i=0; i<count; i++)); do
        local schedule=$(echo "$schedules" | jq ".[$i]")
        local task=$(echo "$schedule" | jq -r '.task')
        local hour=$(echo "$schedule" | jq -r '.hour')
        local minute=$(echo "$schedule" | jq -r '.minute // "0"')
        local weekday=$(echo "$schedule" | jq -r '.weekday')
        
        log_debug "Checking schedule: task=$task, hour=$hour, minute=$minute, weekday=$weekday"
        
        # Check hour match
        if [[ "$hour" != "$current_hour" ]]; then
            continue
        fi
        
        # Check minute match (default to 0 if not specified)
        if [[ "$minute" != "$current_minute" ]]; then
            continue
        fi
        
        # Check weekday match ("*" means every day)
        if [[ "$weekday" == "*" ]] || [[ "$weekday" == "$current_weekday" ]]; then
            log_debug "Match found: $task"
            echo "$task"
            return 0
        fi
    done
    
    # No match found
    return 1
}

# =============================================================================
# Execution Functions
# =============================================================================

# Execute a task
execute_task() {
    local task_name="$1"
    local prompt_file=$(get_prompt_file "$task_name")
    
    log_debug "Executing task: $task_name"
    log_debug "Prompt file: $prompt_file"
    
    # Validate task exists
    if ! task_exists "$task_name"; then
        log_error "Task not found: $task_name"
        exit 1
    fi
    
    # Validate prompt file exists
    if [[ ! -f "$prompt_file" ]]; then
        log_error "Prompt file not found: $prompt_file"
        exit 1
    fi
    
    # Read prompt
    local prompt=$(cat "$prompt_file")
    
    # Dry run mode - just output prompt
    if [[ "$DRY_RUN" == true ]]; then
        echo "# Task: $task_name"
        echo ""
        echo "$prompt"
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
    
    # Execute via opencode
    local output=""
    local exit_code=0
    
    set +e
    output=$(opencode run "$prompt" --agent build 2>&1)
    exit_code=$?
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
    
    # Update index
    update_runs_index "$run_id" "$task_name" "$exit_code" "$finished_at"
    
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
    
    local index_file="$RUNNER_DATA_DIR/runs/index.json"
    local temp_file=$(mktemp)
    
    # Add new run to index
    jq --arg id "$run_id" \
       --arg task "$task" \
       --argjson exit_code "$exit_code" \
       --arg finished_at "$finished_at" \
       --arg updated_at "$(get_timestamp)" \
       '.runs += [{"id": $id, "task": $task, "exit_code": $exit_code, "finished_at": $finished_at}] | .total = (.runs | length) | .updated_at = $updated_at' \
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
    yq -o=json '.tasks' "$RUNNER_CONFIG_FILE" | jq '[to_entries[] | {
      id: .key,
      description: .value.description,
      prompt_file: ("tasks/" + .key + ".md"),
      timeout: (.value.timeout // 300)
    }]'
}

api_schedules() {
    yq -o=json '.schedules' "$RUNNER_CONFIG_FILE"
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
    
    # Generate tasks.json
    api_tasks > "$RUNNER_DATA_DIR/tasks.json"
    
    # Generate schedules.json
    api_schedules > "$RUNNER_DATA_DIR/schedules.json"
    
    log_info "API data files initialized"
}

handle_api() {
    local endpoint="${1:-}"
    shift || true
    
    case "$endpoint" in
        tasks)
            api_tasks
            ;;
        schedules)
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
            local task=$(find_scheduled_task) || true
            if [[ -z "$task" ]]; then
                log_debug "No task scheduled for current time"
                exit 0  # Silent exit
            fi
            execute_task "$task"
            ;;
        list)
            list_tasks
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
