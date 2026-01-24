#!/usr/bin/env bats
# =============================================================================
# Dry Run Tests - Preview mode without execution
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: dry-run outputs prompt content
# -----------------------------------------------------------------------------
@test "dry-run outputs prompt content" {
    run runner morning_briefing --dry-run
    assert_success
    
    # Should contain prompt content (now inline in YAML)
    assert_output --partial "morning briefing"
    refute_output --partial "MOCK_OPENCODE_CALLED"
}

# -----------------------------------------------------------------------------
# Test: dry-run does not write logs
# -----------------------------------------------------------------------------
@test "dry-run does not write run logs" {
    local count_before=$(count_files "$RUNNER_DATA_DIR/runs" "*.json")
    
    run runner morning_briefing --dry-run
    assert_success
    
    local count_after=$(count_files "$RUNNER_DATA_DIR/runs" "*.json")
    
    # Only index.json should exist, no new run files
    [[ "$count_before" == "$count_after" ]]
}

# -----------------------------------------------------------------------------
# Test: dry-run does not update state
# -----------------------------------------------------------------------------
@test "dry-run does not update state.json" {
    # Get initial state
    local initial_state=$(cat "$RUNNER_DATA_DIR/state.json")
    
    run runner morning_briefing --dry-run
    assert_success
    
    # State should be unchanged
    local final_state=$(cat "$RUNNER_DATA_DIR/state.json")
    [[ "$initial_state" == "$final_state" ]]
}

# -----------------------------------------------------------------------------
# Test: dry-run works with auto mode
# -----------------------------------------------------------------------------
@test "dry-run works with auto mode" {
    set_mock_time 9 3  # Wednesday 09:00
    
    run runner auto --dry-run
    assert_success
    
    # Should show which task would be selected
    assert_output --partial "morning_briefing"
    refute_output --partial "MOCK_OPENCODE_CALLED"
}
