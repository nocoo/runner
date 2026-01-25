#!/bin/bash
# Manual test runner for Swift runner

set -e

RUNNER=".build/debug/runner"
TEMP_DIR=$(mktemp -d)
DATA_DIR="$TEMP_DIR/data"

echo "=== Swift Runner Tests ==="
echo "Temp dir: $TEMP_DIR"
echo ""

# Build
echo "Building..."
swift build -q

# Initialize
echo "Testing: init"
$RUNNER init --data-dir "$DATA_DIR"
[ -f "$DATA_DIR/runs/index.json" ] && echo "  ✓ index.json created" || echo "  ✗ index.json missing"
[ -f "$DATA_DIR/state.json" ] && echo "  ✓ state.json created" || echo "  ✗ state.json missing"

# Create test tasks
echo ""
echo "Setting up test data..."
cat > "$DATA_DIR/tasks.json" << 'EOF'
[
  {"id": "echo_test", "type": "simple", "description": "Test", "timeout": 60, "command": "echo hello"},
  {"id": "fail_test", "type": "simple", "description": "Fail", "timeout": 60, "command": "exit 1"},
  {"id": "manual_test", "type": "manual", "description": "Manual", "timeout": 60}
]
EOF

cat > "$DATA_DIR/schedules.json" << 'EOF'
[
  {"task": "echo_test", "hour": "*", "minute": 0, "weekday": "*"},
  {"task": "echo_test", "hour": "*", "minute": 30, "weekday": "*"}
]
EOF

# List
echo ""
echo "Testing: list"
OUTPUT=$($RUNNER list --data-dir "$DATA_DIR")
echo "$OUTPUT" | grep -q "echo_test" && echo "  ✓ echo_test listed" || echo "  ✗ echo_test missing"
echo "$OUTPUT" | grep -q "fail_test" && echo "  ✓ fail_test listed" || echo "  ✗ fail_test missing"
echo "$OUTPUT" | grep -q "manual_test" && echo "  ✓ manual_test listed" || echo "  ✗ manual_test missing"

# Validate
echo ""
echo "Testing: validate"
$RUNNER validate --data-dir "$DATA_DIR" && echo "  ✓ validation passed" || echo "  ✗ validation failed"

# Run simple task
echo ""
echo "Testing: run echo_test"
OUTPUT=$($RUNNER run echo_test --data-dir "$DATA_DIR")
echo "$OUTPUT" | grep -q "hello" && echo "  ✓ output contains 'hello'" || echo "  ✗ output missing 'hello'"

# Check run was recorded
COUNT=$(cat "$DATA_DIR/runs/index.json" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$COUNT" -ge 1 ] && echo "  ✓ run recorded in index.json" || echo "  ✗ run not recorded"

# Run failing task
echo ""
echo "Testing: run fail_test (should fail)"
$RUNNER run fail_test --data-dir "$DATA_DIR" 2>/dev/null || true
# Check for exit_code 1 (with or without spaces in JSON)
cat "$DATA_DIR/runs/index.json" | grep -q '"exit_code" *: *1' && echo "  ✓ failure recorded with exit_code 1" || echo "  ✗ failure not recorded"

# Run manual task
echo ""
echo "Testing: run manual_test"
OUTPUT=$($RUNNER run manual_test --data-dir "$DATA_DIR")
echo "$OUTPUT" | grep -q "not executed" && echo "  ✓ manual task not executed" || echo "  ✗ unexpected output"

# Dry run
echo ""
echo "Testing: dry-run"
OUTPUT=$($RUNNER run echo_test --data-dir "$DATA_DIR" --dry-run)
echo "$OUTPUT" | grep -q "DRY RUN" && echo "  ✓ dry run output correct" || echo "  ✗ dry run failed"

# Logs
echo ""
echo "Testing: logs --list"
$RUNNER logs --data-dir "$DATA_DIR" --list | grep -q "echo_test" && echo "  ✓ logs list works" || echo "  ✗ logs list failed"

# Auto (mock time)
echo ""
echo "Testing: auto --mock-hour 9 --mock-minute 0"
$RUNNER auto --data-dir "$DATA_DIR" --mock-hour 9 --mock-minute 0 --mock-weekday 1 --verbose 2>&1 | grep -q "echo_test" && echo "  ✓ auto scheduled echo_test" || echo "  ✗ auto didn't schedule"

# Monitor
echo ""
echo "Testing: monitor"
$RUNNER monitor --data-dir "$DATA_DIR" && echo "  ✓ monitor works" || echo "  ✗ monitor failed"

# API
echo ""
echo "Testing: api tasks"
$RUNNER api tasks --data-dir "$DATA_DIR" | grep -q "echo_test" && echo "  ✓ api tasks works" || echo "  ✗ api tasks failed"

echo ""
echo "Testing: api schedules"
$RUNNER api schedules --data-dir "$DATA_DIR" | grep -q "echo_test" && echo "  ✓ api schedules works" || echo "  ✗ api schedules failed"

echo ""
echo "Testing: api runs"
$RUNNER api runs --data-dir "$DATA_DIR" | grep -q '"runs"' && echo "  ✓ api runs works" || echo "  ✗ api runs failed"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== Tests Complete ==="
