#!/usr/bin/env bats
# =============================================================================
# CLI Tests - Command line interface
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: list command shows all tasks
# -----------------------------------------------------------------------------
@test "list command shows all tasks" {
    run runner list
    assert_success
    assert_output --partial "morning_briefing"
    assert_output --partial "twitter_collect"
    assert_output --partial "evening_review"
    assert_output --partial "weekly_synthesis"
    assert_output --partial "memory_cleanup"
}

# -----------------------------------------------------------------------------
# Test: No arguments shows usage
# -----------------------------------------------------------------------------
@test "no arguments shows usage" {
    run runner
    assert_failure
    assert_output --partial "Usage:"
}

# -----------------------------------------------------------------------------
# Test: --help shows usage
# -----------------------------------------------------------------------------
@test "help flag shows usage" {
    run runner --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Commands:"
}

# -----------------------------------------------------------------------------
# Test: --version shows version
# -----------------------------------------------------------------------------
@test "version flag shows version" {
    run runner --version
    assert_success
    assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+$"
}

# -----------------------------------------------------------------------------
# Test: --verbose enables debug output
# -----------------------------------------------------------------------------
@test "verbose flag enables debug output" {
    run runner morning_briefing --verbose
    assert_success
    assert_output --partial "[DEBUG]"
}

# -----------------------------------------------------------------------------
# Test: Invalid option shows error
# -----------------------------------------------------------------------------
@test "invalid option shows error" {
    run runner --invalid-option
    assert_failure
    assert_output --partial "Unknown option"
}
