#!/usr/bin/env bats
# =============================================================================
# API Tests - Data file API endpoints
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: api tasks returns valid JSON array
# -----------------------------------------------------------------------------
@test "api tasks returns valid JSON array" {
    run runner api tasks
    assert_success
    
    # Verify it's a valid JSON array
    echo "$output" | jq -e 'type == "array"'
}

# -----------------------------------------------------------------------------
# Test: api tasks contains all configured tasks
# -----------------------------------------------------------------------------
@test "api tasks contains all configured tasks" {
    run runner api tasks
    assert_success
    
    # Check all tasks are present
    echo "$output" | jq -e 'map(.id) | contains(["morning_briefing", "twitter_collect", "evening_review", "weekly_synthesis", "memory_cleanup"])'
}

# -----------------------------------------------------------------------------
# Test: api runs returns execution history
# -----------------------------------------------------------------------------
@test "api runs returns execution history" {
    # Execute a task first
    runner morning_briefing
    
    run runner api runs
    assert_success
    
    # Should be a valid JSON with runs array
    echo "$output" | jq -e '.runs | type == "array"'
    echo "$output" | jq -e '.total >= 1'
}

# -----------------------------------------------------------------------------
# Test: api runs <id> returns single run details
# -----------------------------------------------------------------------------
@test "api runs with id returns single run" {
    runner morning_briefing
    local run_id=$(get_latest_run_id)
    
    run runner api runs "$run_id"
    assert_success
    
    # Should contain full run details
    echo "$output" | jq -e '.id and .task and .started_at and .exit_code'
}

# -----------------------------------------------------------------------------
# Test: api runs with invalid id returns error
# -----------------------------------------------------------------------------
@test "api runs with invalid id returns error" {
    run runner api runs "invalid-uuid"
    assert_failure
    assert_output --partial "not found"
}

# -----------------------------------------------------------------------------
# Test: api status returns system status
# -----------------------------------------------------------------------------
@test "api status returns system status" {
    run runner api status
    assert_success
    
    # Should contain version at minimum
    echo "$output" | jq -e '.version'
}

# -----------------------------------------------------------------------------
# Test: api status includes last_run after execution
# -----------------------------------------------------------------------------
@test "api status includes last_run after execution" {
    runner morning_briefing
    
    run runner api status
    assert_success
    
    echo "$output" | jq -e '.last_run.task == "morning_briefing"'
}

# -----------------------------------------------------------------------------
# Test: api schedules returns all schedules
# -----------------------------------------------------------------------------
@test "api schedules returns all schedules" {
    run runner api schedules
    assert_success
    
    # Should have 11 schedule entries (updated with simple_task)
    local count=$(echo "$output" | jq 'length')
    [[ "$count" -eq 11 ]]
}

# -----------------------------------------------------------------------------
# Test: api unknown endpoint returns error
# -----------------------------------------------------------------------------
@test "api unknown endpoint returns error" {
    run runner api unknown
    assert_failure
    assert_output --partial "Unknown API endpoint"
}

# -----------------------------------------------------------------------------
# Test: api without endpoint shows available endpoints
# -----------------------------------------------------------------------------
@test "api without endpoint shows help" {
    run runner api
    assert_failure
    assert_output --partial "Available endpoints"
}
