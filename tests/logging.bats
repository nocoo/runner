#!/usr/bin/env bats
# =============================================================================
# Logging Tests - Run record persistence
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: Successful execution writes JSON log
# -----------------------------------------------------------------------------
@test "successful execution writes JSON log" {
    run runner morning_briefing
    assert_success
    
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    # Verify log file exists and is valid JSON
    local log_file="$RUNNER_DATA_DIR/runs/${run_id}.json"
    [[ -f "$log_file" ]]
    is_valid_json "$log_file"
}

# -----------------------------------------------------------------------------
# Test: Log contains required fields
# -----------------------------------------------------------------------------
@test "log contains required fields" {
    run runner morning_briefing
    assert_success
    
    local run_id=$(get_latest_run_id)
    local log_file="$RUNNER_DATA_DIR/runs/${run_id}.json"
    
    # Check required fields exist
    run jq -e '.id and .task and .trigger and .started_at and .exit_code' "$log_file"
    assert_success
}

# -----------------------------------------------------------------------------
# Test: Failed execution logs non-zero exit code
# -----------------------------------------------------------------------------
@test "failed execution logs non-zero exit_code" {
    set_mock_exit_code 1
    
    run runner morning_briefing
    # The runner itself should indicate failure
    assert_failure
    
    local run_id=$(get_latest_run_id)
    local exit_code=$(jq -r '.exit_code' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    
    [[ "$exit_code" == "1" ]]
}

# -----------------------------------------------------------------------------
# Test: Log includes duration
# -----------------------------------------------------------------------------
@test "log includes duration_seconds" {
    run runner morning_briefing
    assert_success
    
    local run_id=$(get_latest_run_id)
    local duration=$(jq -r '.duration_seconds' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    
    # Duration should be a non-negative number
    [[ "$duration" =~ ^[0-9]+\.?[0-9]*$ ]]
}

# -----------------------------------------------------------------------------
# Test: Index file is updated after execution
# -----------------------------------------------------------------------------
@test "runs index is updated after execution" {
    local total_before=$(jq -r '.total' "$RUNNER_DATA_DIR/runs/index.json")
    
    run runner morning_briefing
    assert_success
    
    local total_after=$(jq -r '.total' "$RUNNER_DATA_DIR/runs/index.json")
    
    [[ "$total_after" -eq $((total_before + 1)) ]]
}

# -----------------------------------------------------------------------------
# Test: Index contains run summary
# -----------------------------------------------------------------------------
@test "runs index contains run summary" {
    run runner morning_briefing
    assert_success
    
    local run_id=$(get_latest_run_id)
    
    # Verify the run appears in index with required fields
    run jq -e ".runs[] | select(.id == \"$run_id\") | .task and .exit_code and .finished_at" \
        "$RUNNER_DATA_DIR/runs/index.json"
    assert_success
}
