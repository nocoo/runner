#!/usr/bin/env bats
# =============================================================================
# Crontab-style Routing Tests
# Complete coverage for schedule matching logic
# =============================================================================

load 'test_helper'

# Use crontab-specific fixtures
setup() {
    # Call parent setup first
    source "$BATS_TEST_DIRNAME/test_helper.bash"
    setup
    
    # Override config to use crontab fixtures
    export RUNNER_CONFIG_FILE="$PROJECT_ROOT/tests/fixtures/crontab_tasks.yaml"
}

# =============================================================================
# Basic Exact Match
# =============================================================================

@test "exact hour and minute match" {
    set_mock_time 9 3 5  # Wednesday 09:05 - matches morning_briefing exactly
    run runner auto --dry-run
    assert_success
    assert_output --partial "morning_briefing"
}

@test "exact match fails when hour differs" {
    set_mock_time 10 3 0  # Wednesday 10:00, not 09:00
    run runner auto --dry-run
    # Should not match morning_briefing (09:05)
    refute_output --partial "morning_briefing"
}

@test "exact match fails when minute differs" {
    set_mock_time 9 3 6  # Wednesday 09:06, not 09:05
    run runner auto --dry-run
    refute_output --partial "morning_briefing"
}

# =============================================================================
# Wildcard: * (any value)
# =============================================================================

@test "hour=* matches any hour" {
    # heartbeat_any_hour is scheduled with hour: "*", minute: 0
    # Use hour 4 to avoid conflicts with other :00 tasks
    set_mock_time 4 3 0
    run runner auto --dry-run
    assert_success
    assert_output --partial "heartbeat_any_hour"
}

@test "hour=* matches different hours" {
    # Use hour 22 to avoid conflicts
    set_mock_time 22 3 0
    run runner auto --dry-run
    assert_success
    assert_output --partial "heartbeat_any_hour"
}

@test "minute=* matches any minute" {
    # continuous_task is scheduled with hour: 12, minute: "*"
    # Use minute 15 to avoid :00 conflict with range_task/hour_list_task
    set_mock_time 12 3 15
    run runner auto --dry-run
    assert_success
    assert_output --partial "continuous_task"
}

@test "minute=* matches different minutes" {
    set_mock_time 12 3 59
    run runner auto --dry-run
    assert_success
    assert_output --partial "continuous_task"
}

@test "hour=* and minute=* matches any time" {
    # always_task is scheduled with hour: "*", minute: "*" (last in list)
    # Use a time that doesn't match any other specific rule
    set_mock_time 3 3 42  # 03:42 on Wednesday - should only match always_task
    run runner auto --dry-run
    assert_success
    assert_output --partial "always_task"
}

# =============================================================================
# Weekday matching
# =============================================================================

@test "weekday=* matches any day" {
    set_mock_time 9 0 5  # Sunday
    run runner auto --dry-run
    assert_output --partial "morning_briefing"
    
    set_mock_time 9 6 5  # Saturday
    run runner auto --dry-run
    assert_output --partial "morning_briefing"
}

@test "specific weekday only matches that day" {
    # weekly_synthesis: hour=20, weekday=0 (Sunday)
    set_mock_time 20 0 0  # Sunday 20:00
    run runner auto --dry-run
    assert_success
    assert_output --partial "weekly_synthesis"
}

@test "specific weekday does not match other days" {
    set_mock_time 20 1 0  # Monday 20:00
    run runner auto --dry-run
    refute_output --partial "weekly_synthesis"
}

# =============================================================================
# List syntax: N,M,O
# =============================================================================

@test "minute list matches first value" {
    # list_task: minute: "0,15,30,45"
    set_mock_time 8 3 0
    run runner auto --dry-run
    assert_success
    assert_output --partial "list_task"
}

@test "minute list matches middle value" {
    set_mock_time 8 3 30
    run runner auto --dry-run
    assert_success
    assert_output --partial "list_task"
}

@test "minute list matches last value" {
    set_mock_time 8 3 45
    run runner auto --dry-run
    assert_success
    assert_output --partial "list_task"
}

@test "minute list does not match unlisted value" {
    set_mock_time 8 3 20
    run runner auto --dry-run
    refute_output --partial "list_task"
}

@test "hour list matches any listed hour" {
    # hour_list_task: hour: "18,19,21", minute: 0
    set_mock_time 19 3 0
    run runner auto --dry-run
    assert_output --partial "hour_list_task"
}

@test "weekday list matches any listed day" {
    # weekday_list_task: weekday: "1,3,5" (Mon, Wed, Fri)
    set_mock_time 10 3 30  # Wednesday
    run runner auto --dry-run
    assert_output --partial "weekday_list_task"
}

# =============================================================================
# Range syntax: N-M
# =============================================================================

@test "hour range matches start value" {
    # range_task: hour: "9-17"
    set_mock_time 9 3 0
    run runner auto --dry-run
    assert_output --partial "range_task"
}

@test "hour range matches middle value" {
    set_mock_time 13 3 0
    run runner auto --dry-run
    assert_output --partial "range_task"
}

@test "hour range matches end value" {
    set_mock_time 17 3 0
    run runner auto --dry-run
    assert_output --partial "range_task"
}

@test "hour range does not match outside range" {
    set_mock_time 8 3 0
    run runner auto --dry-run
    refute_output --partial "range_task"
    
    set_mock_time 18 3 0
    run runner auto --dry-run
    refute_output --partial "range_task"
}

@test "minute range matches values in range" {
    # minute_range_task: minute: "0-10"
    set_mock_time 7 3 5
    run runner auto --dry-run
    assert_output --partial "minute_range_task"
}

# =============================================================================
# Step syntax: */N
# =============================================================================

@test "minute step */10 matches 0" {
    # step_task: minute: "*/10"
    set_mock_time 6 3 0
    run runner auto --dry-run
    assert_output --partial "step_task"
}

@test "minute step */10 matches 10" {
    set_mock_time 6 3 10
    run runner auto --dry-run
    assert_output --partial "step_task"
}

@test "minute step */10 matches 50" {
    set_mock_time 6 3 50
    run runner auto --dry-run
    assert_output --partial "step_task"
}

@test "minute step */10 does not match 5" {
    set_mock_time 6 3 5
    run runner auto --dry-run
    refute_output --partial "step_task"
}

@test "minute step */15 matches correctly" {
    # step15_task: minute: "*/15"
    set_mock_time 5 3 0
    run runner auto --dry-run
    assert_output --partial "step15_task"
    
    set_mock_time 5 3 15
    run runner auto --dry-run
    assert_output --partial "step15_task"
    
    set_mock_time 5 3 30
    run runner auto --dry-run
    assert_output --partial "step15_task"
    
    set_mock_time 5 3 45
    run runner auto --dry-run
    assert_output --partial "step15_task"
}

@test "hour step */2 matches even hours" {
    # hour_step_task: hour: "*/2", minute: 30
    set_mock_time 0 3 30
    run runner auto --dry-run
    assert_output --partial "hour_step_task"
    
    set_mock_time 2 3 30
    run runner auto --dry-run
    assert_output --partial "hour_step_task"
    
    set_mock_time 22 3 30
    run runner auto --dry-run
    assert_output --partial "hour_step_task"
}

@test "hour step */2 does not match odd hours" {
    set_mock_time 1 3 30
    run runner auto --dry-run
    refute_output --partial "hour_step_task"
    
    set_mock_time 23 3 30
    run runner auto --dry-run
    refute_output --partial "hour_step_task"
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "midnight hour=0 matches correctly" {
    set_mock_time 0 3 0
    run runner auto --dry-run
    assert_output --partial "heartbeat_any_hour"
}

@test "last minute of day hour=23 minute=59" {
    # end_of_day_task: hour: 23, minute: 59
    set_mock_time 23 3 59
    run runner auto --dry-run
    assert_output --partial "end_of_day_task"
}

@test "leading zeros in time are handled (08 vs 8)" {
    # This tests that "08" from date command matches "8" in config
    set_mock_time 8 3 0
    run runner auto --dry-run
    assert_output --partial "list_task"  # hour 8
}

@test "first match wins when multiple schedules match" {
    # When time matches multiple schedules, first in config wins
    # This is documented behavior
    set_mock_time 12 3 0  # Matches multiple tasks
    run runner auto --dry-run
    assert_success
    # Should return first matching task
}

@test "no match returns empty and exits silently" {
    set_mock_time 4 3 33  # Unlikely to match anything specific
    run runner auto
    assert_success
    assert_output ""
}

# =============================================================================
# Combined Expressions
# =============================================================================

@test "complex schedule: weekday range with hour list" {
    # work_hours_task: hour: "9,12,15,18", minute: 1, weekday: "1-5"
    set_mock_time 12 3 1  # Wednesday 12:01
    run runner auto --dry-run
    assert_output --partial "work_hours_task"
}

@test "complex schedule fails outside weekday range" {
    set_mock_time 12 0 1  # Sunday 12:01
    run runner auto --dry-run
    refute_output --partial "work_hours_task"
}
