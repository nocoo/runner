#!/usr/bin/env bats
# =============================================================================
# Routing Tests - Time-based task selection
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: auto mode at 09:00 selects morning_briefing
# -----------------------------------------------------------------------------
@test "auto at 09:00 on weekday selects morning_briefing" {
    set_mock_time 9 3  # Wednesday 09:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "morning_briefing"
}

# -----------------------------------------------------------------------------
# Test: auto mode at 10:00 selects twitter_collect
# -----------------------------------------------------------------------------
@test "auto at 10:00 on weekday selects twitter_collect" {
    set_mock_time 10 3  # Wednesday 10:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "twitter_collect"
}

# -----------------------------------------------------------------------------
# Test: auto mode at 21:00 selects evening_review
# -----------------------------------------------------------------------------
@test "auto at 21:00 on weekday selects evening_review" {
    set_mock_time 21 3  # Wednesday 21:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "evening_review"
}

# -----------------------------------------------------------------------------
# Test: auto mode at Sunday 20:00 selects weekly_synthesis
# -----------------------------------------------------------------------------
@test "auto at Sunday 20:00 selects weekly_synthesis" {
    set_mock_time 20 0  # Sunday 20:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "weekly_synthesis"
}

# -----------------------------------------------------------------------------
# Test: auto mode at Monday 03:00 selects memory_cleanup
# -----------------------------------------------------------------------------
@test "auto at Monday 03:00 selects memory_cleanup" {
    set_mock_time 3 1  # Monday 03:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "memory_cleanup"
}

# -----------------------------------------------------------------------------
# Test: auto mode at non-scheduled time exits silently
# -----------------------------------------------------------------------------
@test "auto at non-scheduled time exits silently" {
    set_mock_time 15 3  # Wednesday 15:00 - no task scheduled
    
    run runner auto
    assert_success
    assert_output ""  # Silent exit, no output
}

# -----------------------------------------------------------------------------
# Test: Sunday 21:00 still runs evening_review (daily schedule)
# -----------------------------------------------------------------------------
@test "auto at Sunday 21:00 selects evening_review" {
    set_mock_time 21 0  # Sunday 21:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "evening_review"
}

# =============================================================================
# Edge Cases - Boundary conditions
# =============================================================================

# -----------------------------------------------------------------------------
# Test: Midnight (hour=0) scheduling works
# -----------------------------------------------------------------------------
@test "auto at midnight (00:00) selects midnight_task" {
    set_mock_time 0 3 0  # Wednesday 00:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "midnight_task"
}

# -----------------------------------------------------------------------------
# Test: End of day (23:59) scheduling works
# -----------------------------------------------------------------------------
@test "auto at 23:59 selects late_night_task" {
    set_mock_time 23 3 59  # Wednesday 23:59
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "late_night_task"
}

# -----------------------------------------------------------------------------
# Test: Saturday (weekday=6) scheduling works
# -----------------------------------------------------------------------------
@test "auto at Saturday 14:00 selects saturday_task" {
    set_mock_time 14 6 0  # Saturday 14:00
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "saturday_task"
}

# -----------------------------------------------------------------------------
# Test: Specific minute matching works
# -----------------------------------------------------------------------------
@test "auto at 15:45 selects specific_minute_task" {
    set_mock_time 15 3 45  # Wednesday 15:45
    
    run runner auto --dry-run
    assert_success
    assert_output --partial "specific_minute_task"
}

# -----------------------------------------------------------------------------
# Test: Wrong minute does not match
# -----------------------------------------------------------------------------
@test "auto at 15:44 does not select specific_minute_task" {
    set_mock_time 15 3 44  # Wednesday 15:44 (1 min before)
    
    run runner auto
    assert_success
    assert_output ""  # No task matched
}

# -----------------------------------------------------------------------------
# Test: Wrong weekday does not match
# -----------------------------------------------------------------------------
@test "auto at Sunday 14:00 does not select saturday_task" {
    set_mock_time 14 0 0  # Sunday 14:00 (not Saturday)
    
    run runner auto
    assert_success
    assert_output ""  # No task matched
}
