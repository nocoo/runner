#!/usr/bin/env bats
# =============================================================================
# Error Handling Tests - Edge cases and failure paths
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: Empty task name returns error
# -----------------------------------------------------------------------------
@test "empty task name shows usage" {
    run runner ""
    assert_failure
    assert_output --partial "Usage"
}

# -----------------------------------------------------------------------------
# Test: Unknown command returns error
# -----------------------------------------------------------------------------
@test "unknown command returns error" {
    run runner unknown_command
    assert_failure
    assert_output --partial "not found"
}

# -----------------------------------------------------------------------------
# Test: Task exists but has no prompt (agent type)
# -----------------------------------------------------------------------------
@test "task without prompt file returns error" {
    run runner orphan_task
    assert_failure
    assert_output --partial "has no prompt"
}

# -----------------------------------------------------------------------------
# Test: Invalid API subcommand
# -----------------------------------------------------------------------------
@test "invalid api subcommand returns error" {
    run runner api invalid_endpoint
    assert_failure
    assert_output --partial "Unknown API"
}

# -----------------------------------------------------------------------------
# Test: Multiple flags work correctly
# -----------------------------------------------------------------------------
@test "verbose and dry-run flags work together" {
    run runner morning_briefing --dry-run --verbose
    assert_success
    # Check for prompt content (now inline)
    assert_output --partial "morning briefing"
}

# -----------------------------------------------------------------------------
# Test: Help flag shows usage
# -----------------------------------------------------------------------------
@test "help flag shows usage" {
    run runner --help
    assert_success
    assert_output --partial "Usage"
    assert_output --partial "Commands"
}

# -----------------------------------------------------------------------------
# Test: Version flag shows version
# -----------------------------------------------------------------------------
@test "version flag shows version" {
    run runner --version
    assert_success
    assert_output --partial "1.0"
}

# -----------------------------------------------------------------------------
# Test: Unknown option handling
# -----------------------------------------------------------------------------
@test "unknown option returns error" {
    run runner --invalid-option
    assert_failure
    assert_output --partial "Unknown option"
}

# -----------------------------------------------------------------------------
# Test: Opencode failure records correct exit code (async)
# -----------------------------------------------------------------------------
@test "opencode failure records exit code in run log" {
    set_mock_exit_code 42
    
    # Runner returns success (async fork)
    run runner morning_briefing
    assert_success
    
    # Wait for async task
    wait_for_any_completion 10
    
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    local exit_code=$(jq -r '.exit_code' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$exit_code" == "42" ]]
}

# -----------------------------------------------------------------------------
# Test: Task execution records duration (async)
# -----------------------------------------------------------------------------
@test "task execution records duration" {
    run runner morning_briefing
    assert_success
    
    # Wait for async task
    wait_for_any_completion 10
    
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    local duration=$(jq -r '.duration_seconds' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$duration" -ge 0 ]]
}
