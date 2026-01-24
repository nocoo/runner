#!/usr/bin/env bats
# =============================================================================
# Schema Tests - JSON Schema validation
# =============================================================================

load 'test_helper'

# -----------------------------------------------------------------------------
# Test: api tasks output conforms to task schema
# -----------------------------------------------------------------------------
@test "api tasks output conforms to task schema" {
    # Get tasks and save to temp file
    runner api tasks > "$TEST_TMP_DIR/tasks.json"
    
    # Create array schema wrapper for new task format
    cat > "$TEST_TMP_DIR/tasks-array.schema.json" << 'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "id": { "type": "string" },
      "type": { "type": "string", "enum": ["simple", "agent"] },
      "description": { "type": "string" },
      "timeout": { "type": "integer" },
      "command": { "type": ["string", "null"] },
      "prompt": { "type": ["string", "null"] },
      "workdir": { "type": ["string", "null"] }
    },
    "required": ["id", "type", "description", "timeout"]
  }
}
EOF
    
    run ajv validate -s "$TEST_TMP_DIR/tasks-array.schema.json" -d "$TEST_TMP_DIR/tasks.json" --strict=false
    assert_success
}

# -----------------------------------------------------------------------------
# Test: api schedules output conforms to schedule schema
# -----------------------------------------------------------------------------
@test "api schedules output conforms to schedule schema" {
    # Get schedules and save to temp file
    runner api schedules > "$TEST_TMP_DIR/schedules.json"
    
    # Create array schema wrapper
    cat > "$TEST_TMP_DIR/schedules-array.schema.json" << 'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "task": { "type": "string" },
      "hour": { "type": "integer", "minimum": 0, "maximum": 23 },
      "weekday": {
        "oneOf": [
          { "type": "string", "enum": ["*"] },
          { "type": "integer", "minimum": 0, "maximum": 6 }
        ]
      }
    },
    "required": ["task", "hour", "weekday"]
  }
}
EOF
    
    run ajv validate -s "$TEST_TMP_DIR/schedules-array.schema.json" -d "$TEST_TMP_DIR/schedules.json" --strict=false
    assert_success
}

# -----------------------------------------------------------------------------
# Test: api status output conforms to status schema
# -----------------------------------------------------------------------------
@test "api status output conforms to status schema" {
    runner api status > "$TEST_TMP_DIR/status.json"
    
    run ajv validate -s "$RUNNER_SCHEMAS_DIR/status.schema.json" -d "$TEST_TMP_DIR/status.json" --strict=false
    assert_success
}

# -----------------------------------------------------------------------------
# Test: run log files conform to run schema
# -----------------------------------------------------------------------------
@test "run log files conform to run schema" {
    # Execute a task to generate a log
    runner morning_briefing
    
    local run_id=$(get_latest_run_id)
    local log_file="$RUNNER_DATA_DIR/runs/${run_id}.json"
    
    run ajv validate -s "$RUNNER_SCHEMAS_DIR/run.schema.json" -d "$log_file" --strict=false
    assert_success
}

# -----------------------------------------------------------------------------
# Test: runs index conforms to runs-index schema
# -----------------------------------------------------------------------------
@test "runs index conforms to runs-index schema" {
    # Execute a task to populate index
    runner morning_briefing
    
    run ajv validate -s "$RUNNER_SCHEMAS_DIR/runs-index.schema.json" -d "$RUNNER_DATA_DIR/runs/index.json" --strict=false
    assert_success
}

# -----------------------------------------------------------------------------
# Test: state.json conforms to status schema after execution
# -----------------------------------------------------------------------------
@test "state.json conforms to status schema" {
    runner morning_briefing
    
    run ajv validate -s "$RUNNER_SCHEMAS_DIR/status.schema.json" -d "$RUNNER_DATA_DIR/state.json" --strict=false
    assert_success
}
