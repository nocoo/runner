#!/usr/bin/env bats
# =============================================================================
# Execution Tests - Task execution flow
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: Direct task execution calls opencode
# -----------------------------------------------------------------------------
@test "direct task execution calls opencode and creates run log" {
    run runner morning_briefing
    assert_success
    
    # Verify a run log was created (which means opencode was called)
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    # Verify the log file exists
    [[ -f "$RUNNER_DATA_DIR/runs/${run_id}.json" ]]
}

# -----------------------------------------------------------------------------
# Test: Unknown task returns error
# -----------------------------------------------------------------------------
@test "unknown task returns error" {
    run runner nonexistent_task
    assert_failure
    assert_output --partial "Task not found"
}

# -----------------------------------------------------------------------------
# Test: Task exists but prompt file missing returns error
# -----------------------------------------------------------------------------
@test "missing prompt file returns error" {
    # Create a task config without corresponding .md file
    # This test relies on a task defined in yaml but without .md file
    run runner orphan_task
    assert_failure
    assert_output --partial "not found"
}

# -----------------------------------------------------------------------------
# Test: opencode execution failure is handled
# -----------------------------------------------------------------------------
@test "opencode failure is recorded correctly" {
    set_mock_exit_code 1
    
    run runner morning_briefing
    assert_failure
    
    # Verify the run was logged with failure
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    local exit_code=$(jq -r '.exit_code' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$exit_code" == "1" ]]
}

# -----------------------------------------------------------------------------
# Test: Trigger type is recorded correctly
# -----------------------------------------------------------------------------
@test "manual trigger is recorded as manual" {
    run runner morning_briefing
    assert_success
    
    local run_id=$(get_latest_run_id)
    local trigger=$(jq -r '.trigger' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$trigger" == "manual" ]]
}

@test "auto trigger is recorded as auto" {
    set_mock_time 9 3  # Wednesday 09:00
    
    run runner auto
    assert_success
    
    local run_id=$(get_latest_run_id)
    local trigger=$(jq -r '.trigger' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$trigger" == "auto" ]]
}
