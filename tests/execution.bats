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
# Test: Task exists but prompt file missing returns error (agent type)
# -----------------------------------------------------------------------------
@test "missing prompt file returns error" {
    # Create a task config without corresponding .md file
    # This test relies on a task defined in yaml but without .md file
    run runner orphan_task
    assert_failure
    assert_output --partial "has no prompt"
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

# -----------------------------------------------------------------------------
# Test: Simple task type executes command directly
# -----------------------------------------------------------------------------
@test "simple task executes command directly" {
    run runner simple_task
    assert_success
    
    # Verify a run log was created
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    # Verify the log file exists
    [[ -f "$RUNNER_DATA_DIR/runs/${run_id}.json" ]]
    
    # Verify output contains success message
    local output_preview=$(jq -r '.output_preview' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$output_preview" == *"Command executed successfully"* ]]
}

# -----------------------------------------------------------------------------
# Test: Simple task without command fails
# -----------------------------------------------------------------------------
@test "simple task without command fails" {
    # Create a temp config with simple task missing command
    local temp_config=$(mktemp)
    cat > "$temp_config" << 'EOF'
schedules: []
tasks:
  bad_simple:
    type: simple
    description: "Missing command"
    timeout: 10
EOF
    
    RUNNER_CONFIG_FILE="$temp_config" run runner bad_simple
    assert_failure
    assert_output --partial "no command"
    
    rm -f "$temp_config"
}

# -----------------------------------------------------------------------------
# Test: Agent task uses opencode
# -----------------------------------------------------------------------------
@test "agent task uses opencode" {
    run runner morning_briefing
    assert_success
    
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    # Check that it went through opencode (mock returns specific output)
    local output_preview=$(jq -r '.output_preview' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    # The mock opencode should have been called
    [[ -n "$output_preview" ]]
}

# -----------------------------------------------------------------------------
# Test: Task type defaults to agent
# -----------------------------------------------------------------------------
@test "task type defaults to agent" {
    # Check that tasks without explicit type are treated as agent
    run runner -v morning_briefing --dry-run
    assert_success
    assert_output --partial "Type: agent"
}

# -----------------------------------------------------------------------------
# Test: Dry-run shows task type
# -----------------------------------------------------------------------------
@test "dry-run shows task type for simple" {
    run runner simple_task --dry-run
    assert_success
    assert_output --partial "Type: simple"
    assert_output --partial "Command:"
}

@test "dry-run shows task type for agent" {
    run runner morning_briefing --dry-run
    assert_success
    assert_output --partial "Type: agent"
}
