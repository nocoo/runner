#!/usr/bin/env bats
# =============================================================================
# Execution Tests - Task execution flow
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: Direct task execution calls opencode (async)
# -----------------------------------------------------------------------------
@test "direct task execution calls opencode and creates run log" {
    run runner morning_briefing
    assert_success
    
    # Agent tasks are async, wait for completion
    wait_for_any_completion 10
    
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
# Test: opencode execution failure is handled (async)
# -----------------------------------------------------------------------------
@test "opencode failure is recorded correctly" {
    set_mock_exit_code 1
    
    # Runner returns success (async fork), but the task will fail
    run runner morning_briefing
    assert_success
    
    # Wait for async task to complete
    wait_for_any_completion 10
    
    # Verify the run was logged with failure
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    local exit_code=$(jq -r '.exit_code' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$exit_code" == "1" ]]
}

# -----------------------------------------------------------------------------
# Test: Trigger type is recorded correctly (async)
# -----------------------------------------------------------------------------
@test "manual trigger is recorded as manual" {
    run runner morning_briefing
    assert_success
    
    # Wait for async task
    wait_for_any_completion 10
    
    local run_id=$(get_latest_run_id)
    local trigger=$(jq -r '.trigger' "$RUNNER_DATA_DIR/runs/${run_id}.json")
    [[ "$trigger" == "manual" ]]
}

@test "auto trigger is recorded as auto" {
    set_mock_time 9 3  # Wednesday 09:00
    
    run runner auto
    assert_success
    
    # Wait for async task
    wait_for_any_completion 10
    
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
    
    # Verify the metadata file exists
    [[ -f "$RUNNER_DATA_DIR/runs/${run_id}.json" ]]
    
    # Verify the output file exists and contains success info
    [[ -f "$RUNNER_DATA_DIR/runs/${run_id}.output" ]]
    grep -q "# Exit code: 0" "$RUNNER_DATA_DIR/runs/${run_id}.output"
}

# -----------------------------------------------------------------------------
# Test: Simple task without command fails
# -----------------------------------------------------------------------------
@test "simple task without command fails" {
    # Add a bad simple task to tasks.json
    cat > "$RUNNER_DATA_DIR/tasks.json" << 'EOF'
[
  {
    "id": "bad_simple",
    "type": "simple",
    "description": "Missing command",
    "timeout": 10
  }
]
EOF
    
    run runner bad_simple
    assert_failure
    assert_output --partial "no command"
}

# -----------------------------------------------------------------------------
# Test: Agent task uses opencode (async)
# -----------------------------------------------------------------------------
@test "agent task uses opencode" {
    run runner morning_briefing
    assert_success
    
    # Wait for async task
    wait_for_any_completion 10
    
    local run_id=$(get_latest_run_id)
    [[ -n "$run_id" ]]
    
    # Check that output file was created
    [[ -f "$RUNNER_DATA_DIR/runs/${run_id}.output" ]]
    # The mock opencode should have been called, output file should have content
    [[ -s "$RUNNER_DATA_DIR/runs/${run_id}.output" ]]
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

# -----------------------------------------------------------------------------
# Test: Model support for agent tasks
# -----------------------------------------------------------------------------
@test "dry-run shows default model for agent task without model" {
    run runner morning_briefing --dry-run
    assert_success
    assert_output --partial "Model: zai-coding-plan/glm-4.7"
}

@test "dry-run shows custom model when specified" {
    run runner agent_with_model --dry-run
    assert_success
    assert_output --partial "Model: custom/test-model"
}

@test "dry-run does not show model for simple task" {
    run runner simple_task --dry-run
    assert_success
    refute_output --partial "Model:"
}
