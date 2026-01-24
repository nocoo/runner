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
      workdir: (.value.workdir // null)
    }]' > "$RUNNER_DATA_DIR/tasks.json"

    yq -o=json '.schedules' "$RUNNER_CONFIG_FILE" > "$RUNNER_DATA_DIR/schedules.json"
}

teardown() {
    # Clean up temporary directories
    if [[ -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
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
