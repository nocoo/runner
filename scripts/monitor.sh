#!/bin/bash
# =============================================================================
# Monitor - Check running task status
# =============================================================================
# Checks all tasks with exit_code=null and verifies if their processes are
# still alive. Handles PID reuse by comparing process start times.
#
# Called by launchd before runner.sh auto, every minute.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_DIR="$(dirname "$SCRIPT_DIR")"
RUNNER_DATA_DIR="${RUNNER_DATA_DIR:-$RUNNER_DIR/data}"

index_file="$RUNNER_DATA_DIR/runs/index.json"

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    echo "[MONITOR] $*" >&2
}

log_debug() {
    if [[ "${RUNNER_VERBOSE:-}" == "1" ]]; then
        echo "[MONITOR DEBUG] $*" >&2
    fi
}

get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Convert ps lstart format to epoch (macOS specific)
# Input: "Sun Jan 25 05:34:36 2026"
# Output: epoch seconds
lstart_to_epoch() {
    local lstart="$1"
    date -j -f "%a %b %d %H:%M:%S %Y" "$lstart" +%s 2>/dev/null || echo "0"
}

# Mark a task as interrupted (exit_code=-1)
mark_interrupted() {
    local run_id="$1"
    local finished_at=$(get_timestamp)
    local lock_file="$RUNNER_DATA_DIR/runs/.index.lock"
    
    # Use flock for atomic file operations (prevent race conditions)
    (
        flock -x 200
        local temp_file=$(mktemp)
        jq --arg id "$run_id" \
           --arg finished_at "$finished_at" \
           '(.runs[] | select(.id == $id)) |= . + {
               exit_code: -1,
               finished_at: $finished_at,
               pid: null
           }' "$index_file" > "$temp_file" && mv "$temp_file" "$index_file"
    ) 200>"$lock_file"
    
    log_info "Task $run_id marked as interrupted"
}

# =============================================================================
# Main Logic
# =============================================================================

main() {
    # Check if index file exists
    if [[ ! -f "$index_file" ]]; then
        log_debug "Index file not found: $index_file"
        exit 0
    fi
    
    # Get all running tasks (exit_code=null and pid is not null)
    local running_tasks
    running_tasks=$(jq -r '.runs[] | select(.exit_code == null and .pid != null) | "\(.id)|\(.pid)|\(.started_at_epoch // 0)"' "$index_file" 2>/dev/null) || true
    
    if [[ -z "$running_tasks" ]]; then
        log_debug "No running tasks to check"
        exit 0
    fi
    
    log_debug "Checking running tasks..."
    
    while IFS='|' read -r run_id pid started_at_epoch; do
        [[ -z "$run_id" || -z "$pid" ]] && continue
        
        log_debug "Checking task $run_id (pid=$pid, started_epoch=$started_at_epoch)"
        
        # Check if process is alive
        if kill -0 "$pid" 2>/dev/null; then
            # Process exists, check for PID reuse
            local proc_lstart
            proc_lstart=$(ps -o lstart= -p "$pid" 2>/dev/null) || true
            
            if [[ -n "$proc_lstart" ]]; then
                local proc_epoch
                proc_epoch=$(lstart_to_epoch "$proc_lstart")
                
                log_debug "Process $pid started at epoch $proc_epoch, recorded $started_at_epoch"
                
                # If process started after our recorded time, PID was reused
                # Add 2 second tolerance for timing differences
                if [[ "$proc_epoch" -gt "$((started_at_epoch + 2))" ]]; then
                    log_info "PID reuse detected for task $run_id (pid=$pid)"
                    mark_interrupted "$run_id"
                else
                    log_debug "Task $run_id still running"
                fi
            else
                # Can't get process info, assume still running
                log_debug "Cannot get lstart for pid $pid, assuming still running"
            fi
        else
            # Process is dead
            log_info "Process $pid not found for task $run_id"
            mark_interrupted "$run_id"
        fi
    done <<< "$running_tasks"
}

main "$@"
