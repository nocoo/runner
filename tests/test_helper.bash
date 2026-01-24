#!/usr/bin/env bash

# =============================================================================
# Bats Test Helper
# =============================================================================

# Load bats libraries
load '/opt/homebrew/lib/bats-support/load.bash'
load '/opt/homebrew/lib/bats-assert/load.bash'

# Project root directory
export PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

# =============================================================================
# Setup / Teardown
# =============================================================================

setup() {
    # Create temporary directories for test isolation
    export TEST_TMP_DIR="$(mktemp -d)"
    export RUNNER_DATA_DIR="$TEST_TMP_DIR/data"
    export RUNNER_LOGS_DIR="$TEST_TMP_DIR/logs"

    mkdir -p "$RUNNER_DATA_DIR/runs"
    mkdir -p "$RUNNER_LOGS_DIR"

    # Use test fixtures (allow override from calling test file)
    export RUNNER_CONFIG_FILE="${RUNNER_CONFIG_FILE:-$PROJECT_ROOT/tests/fixtures/tasks.yaml}"
    export RUNNER_TASKS_DIR="$PROJECT_ROOT/tests/fixtures/tasks"
    export RUNNER_SCHEMAS_DIR="$PROJECT_ROOT/schemas"

    # Skip notifications by default in tests
    export RUNNER_SKIP_NOTIFY=1

    # Add mocks to PATH (prepend so they take priority)
    export PATH="$PROJECT_ROOT/tests/mocks:$PATH"

    # Initialize data files from fixtures (convert YAML to JSON)
    echo '{"runs":[],"total":0,"updated_at":""}' > "$RUNNER_DATA_DIR/runs/index.json"
    echo '{"version":"1.0.0"}' > "$RUNNER_DATA_DIR/state.json"

    # Generate tasks.json and schedules.json from fixtures/tasks.yaml
    yq -o=json '.tasks' "$RUNNER_CONFIG_FILE" | jq '[to_entries[] | {
      id: .key,
      type: (.value.type // "agent"),
      description: .value.description,
      timeout: (.value.timeout // 300),
      command: (.value.command // null),
      prompt: (.value.prompt // null),
      workdir: (.value.workdir // null),
      model: (.value.model // null)
    }]' > "$RUNNER_DATA_DIR/tasks.json"

    yq -o=json '.schedules' "$RUNNER_CONFIG_FILE" > "$RUNNER_DATA_DIR/schedules.json"
}

teardown() {
    # Clean up temporary directories (force remove, ignore errors)
    if [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
    fi
}

# =============================================================================
# Helper Functions
# =============================================================================

# Get the runner script path
runner() {
    "$PROJECT_ROOT/runner.sh" "$@"
}

# Count files in a directory matching a pattern
count_files() {
    local dir="$1"
    local pattern="${2:-*.json}"
    find "$dir" -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Get the latest run ID from index
get_latest_run_id() {
    jq -r '.runs[-1].id // empty' "$RUNNER_DATA_DIR/runs/index.json"
}

# Check if a file is valid JSON
is_valid_json() {
    local file="$1"
    jq empty "$file" 2>/dev/null
}

# Validate JSON against schema using ajv
validate_schema() {
    local schema="$1"
    local data="$2"
    ajv validate -s "$schema" -d "$data" --strict=false 2>&1
}

# Set mock time for testing
set_mock_time() {
    local hour="$1"
    local weekday="$2"
    local minute="${3:-0}"
    export RUNNER_MOCK_HOUR="$hour"
    export RUNNER_MOCK_WEEKDAY="$weekday"
    export RUNNER_MOCK_MINUTE="$minute"
}

# Set mock exit code for opencode
set_mock_exit_code() {
    export MOCK_EXIT_CODE="$1"
}

# Wait for async task completion (poll index.json)
# Usage: wait_for_completion <run_id> [timeout_seconds]
wait_for_completion() {
    local run_id="$1"
    local timeout="${2:-10}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local exit_code=$(jq -r --arg id "$run_id" '.runs[] | select(.id == $id) | .exit_code // "null"' "$RUNNER_DATA_DIR/runs/index.json" 2>/dev/null)
        if [[ "$exit_code" != "null" && -n "$exit_code" ]]; then
            return 0  # Task completed
        fi
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    
    return 1  # Timeout
}

# Wait for any new run to complete (useful when run_id is unknown)
# Waits for the latest run's exit_code to become non-null
# Usage: wait_for_any_completion [timeout_seconds]
wait_for_any_completion() {
    local timeout="${1:-10}"
    local elapsed=0
    
    # Wait for a run to exist and complete (exit_code != null)
    while [[ $elapsed -lt $timeout ]]; do
        local run_count=$(jq '.runs | length' "$RUNNER_DATA_DIR/runs/index.json" 2>/dev/null || echo 0)
        if [[ $run_count -gt 0 ]]; then
            local latest_exit=$(jq '.runs[-1].exit_code' "$RUNNER_DATA_DIR/runs/index.json" 2>/dev/null)
            # jq returns "null" for null, numbers for actual values
            if [[ "$latest_exit" != "null" && -n "$latest_exit" ]]; then
                return 0
            fi
        fi
        sleep 0.2
        elapsed=$((elapsed + 1))
    done
    
    return 1  # Timeout
}
