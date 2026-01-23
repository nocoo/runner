#!/usr/bin/env bats
# =============================================================================
# Workdir Tests - Task execution in custom working directories
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Setup: Create test workdir
# -----------------------------------------------------------------------------
setup() {
    # Call parent setup
    source "$BATS_TEST_DIRNAME/test_helper.bash"
    setup
    
    # Create test workdir with a marker file
    export TEST_WORKDIR="/tmp/runner-test-workdir"
    mkdir -p "$TEST_WORKDIR"
    echo "workdir-marker" > "$TEST_WORKDIR/.marker"
}

teardown() {
    # Clean up test workdir
    if [[ -d "/tmp/runner-test-workdir" ]]; then
        rm -rf "/tmp/runner-test-workdir"
    fi
    
    # Call parent teardown
    source "$BATS_TEST_DIRNAME/test_helper.bash"
    teardown
}

# -----------------------------------------------------------------------------
# Test: Task with workdir executes successfully
# -----------------------------------------------------------------------------
@test "task with workdir executes successfully" {
    run runner task_with_workdir
    assert_success
    
    # Verify run was logged
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
}

# -----------------------------------------------------------------------------
# Test: Dry-run shows workdir in output
# -----------------------------------------------------------------------------
@test "dry-run shows workdir in output" {
    run runner task_with_workdir --dry-run
    assert_success
    
    # Should show the configured workdir
    assert_output --partial "/tmp/runner-test-workdir"
}

# -----------------------------------------------------------------------------
# Test: Task with invalid workdir falls back to default
# -----------------------------------------------------------------------------
@test "task with invalid workdir falls back to default" {
    run runner task_with_invalid_workdir --dry-run
    assert_success
    
    # Should show the invalid path (it's in config) but execute from default
    assert_output --partial "/nonexistent/path"
}

# -----------------------------------------------------------------------------
# Test: Task without workdir uses default directory
# -----------------------------------------------------------------------------
@test "task without workdir uses default directory" {
    run runner morning_briefing --dry-run
    assert_success
    
    # Should show <default> for workdir
    assert_output --partial "<default>"
}

# -----------------------------------------------------------------------------
# Test: Workdir from auto-scheduled task
# -----------------------------------------------------------------------------
@test "auto mode respects workdir for scheduled task" {
    set_mock_time 11 3 30  # Wednesday 11:30 -> task_with_workdir
    
    run runner auto --dry-run
    assert_success
    
    # Should select task_with_workdir and show its workdir
    assert_output --partial "task_with_workdir"
    assert_output --partial "/tmp/runner-test-workdir"
}
