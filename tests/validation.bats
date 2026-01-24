#!/usr/bin/env bats
# =============================================================================
# Config Validation Tests
# Ensure invalid configurations are rejected early
# =============================================================================

load 'test_helper'

# Use crontab fixtures which are valid
setup() {
    source "$BATS_TEST_DIRNAME/test_helper.bash"
    
    # Use crontab fixtures for valid config tests
    export RUNNER_CONFIG_FILE="$PROJECT_ROOT/tests/fixtures/crontab_tasks.yaml"
    
    # Call setup AFTER setting RUNNER_CONFIG_FILE so JSON is generated from correct fixture
    setup
}

# =============================================================================
# Valid Configurations
# =============================================================================

@test "valid config passes validation" {
    run runner validate
    assert_success
    assert_output --partial "valid"
}

@test "validate command returns 0 for valid config" {
    run runner validate
    assert_success
}

# =============================================================================
# Invalid Schedule Fields
# =============================================================================

@test "missing task field in schedule is rejected" {
    create_invalid_config '
schedules:
  - hour: 9
    minute: 0
    weekday: "*"
tasks: {}'
    
    run runner validate
    assert_failure
    assert_output --partial "task"
}

@test "missing hour field in schedule is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    minute: 0
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "hour"
}

@test "missing weekday field in schedule is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: 9
    minute: 0
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "weekday"
}

# =============================================================================
# Invalid Crontab Expressions
# =============================================================================

@test "invalid hour value is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: 25
    minute: 0
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "hour"
    assert_output --partial "0-23"
}

@test "invalid minute value is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: 9
    minute: 60
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "minute"
    assert_output --partial "0-59"
}

@test "invalid weekday value is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: 9
    minute: 0
    weekday: 7
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "weekday"
    assert_output --partial "0-6"
}

@test "negative hour is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: -1
    minute: 0
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "hour"
}

@test "invalid step expression is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: 9
    minute: "*/0"
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "step"
}

@test "invalid range expression is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: "17-9"
    minute: 0
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "range"
}

@test "invalid list value is rejected" {
    create_invalid_config '
schedules:
  - task: test_task
    hour: "9,25,12"
    minute: 0
    weekday: "*"
tasks:
  test_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "25"
}

# =============================================================================
# Task Reference Validation
# =============================================================================

@test "schedule referencing non-existent task is rejected" {
    create_invalid_config '
schedules:
  - task: nonexistent_task
    hour: 9
    minute: 0
    weekday: "*"
tasks:
  other_task:
    description: "Test"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "nonexistent_task"
    assert_output --partial "not found"
}

@test "task without prompt file is rejected" {
    create_invalid_config '
schedules:
  - task: no_prompt_task
    hour: 9
    minute: 0
    weekday: "*"
tasks:
  no_prompt_task:
    type: agent
    description: "No prompt file exists"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "prompt"
    assert_output --partial "no_prompt_task"
}

# =============================================================================
# Task Type Validation
# =============================================================================

@test "simple task without command is rejected" {
    create_invalid_config '
schedules: []
tasks:
  bad_simple:
    type: simple
    description: "Missing command"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "command"
    assert_output --partial "bad_simple"
}

@test "agent task without prompt is rejected" {
    create_invalid_config '
schedules: []
tasks:
  bad_agent:
    type: agent
    description: "Missing prompt"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "prompt"
    assert_output --partial "bad_agent"
}

@test "invalid task type is rejected" {
    create_invalid_config '
schedules: []
tasks:
  bad_type:
    type: unknown
    description: "Invalid type"
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "type"
    assert_output --partial "unknown"
}

@test "simple task with command is valid" {
    create_invalid_config '
schedules: []
tasks:
  good_simple:
    type: simple
    description: "Valid simple task"
    timeout: 60
    command: "echo hello"'
    
    run runner validate
    assert_success
}

@test "agent task with prompt is valid" {
    create_invalid_config '
schedules: []
tasks:
  good_agent:
    type: agent
    description: "Valid agent task"
    timeout: 60
    prompt: "Do something"'
    
    run runner validate
    assert_success
}

# =============================================================================
# Task Metadata Validation
# =============================================================================

@test "task without description is rejected" {
    create_invalid_config '
schedules: []
tasks:
  test_task:
    timeout: 60'
    
    run runner validate
    assert_failure
    assert_output --partial "description"
}

@test "task without timeout is rejected" {
    create_invalid_config '
schedules: []
tasks:
  test_task:
    description: "Test"'
    
    run runner validate
    assert_failure
    assert_output --partial "timeout"
}

@test "invalid timeout value is rejected" {
    create_invalid_config '
schedules: []
tasks:
  test_task:
    description: "Test"
    timeout: -1'
    
    run runner validate
    assert_failure
    assert_output --partial "timeout"
    assert_output --partial "positive"
}

@test "invalid workdir path is rejected" {
    create_invalid_config '
schedules: []
tasks:
  test_task:
    description: "Test"
    timeout: 60
    workdir: /nonexistent/path/that/does/not/exist'
    
    run runner validate
    assert_failure
    assert_output --partial "workdir"
    assert_output --partial "not exist"
}

# =============================================================================
# Helper function to create invalid config
# =============================================================================

create_invalid_config() {
    local config_content="$1"
    export RUNNER_CONFIG_FILE="$TEST_TMP_DIR/invalid_config.yaml"
    echo "$config_content" > "$RUNNER_CONFIG_FILE"

    # Generate tasks JSON - preserve null values for validation testing
    yq -o=json '.tasks' "$RUNNER_CONFIG_FILE" | jq 'to_entries | map({
      id: .key,
      type: (.value.type // "agent"),
      description: (.value.description // ""),
      timeout: .value.timeout,
      command: (.value.command // ""),
      prompt: (.value.prompt // ""),
      workdir: (.value.workdir // "")
    })' > "$RUNNER_DATA_DIR/tasks.json"

    yq -o=json '.schedules' "$RUNNER_CONFIG_FILE" > "$RUNNER_DATA_DIR/schedules.json"
}
