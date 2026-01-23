#!/bin/bash
# =============================================================================
# Runner Test Suite
# =============================================================================
# Run all bats tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Running Runner test suite..."
echo ""

# Check dependencies
if ! command -v bats &> /dev/null; then
    echo "❌ bats-core is not installed. Install with: brew install bats-core"
    exit 1
fi

if ! command -v ajv &> /dev/null; then
    echo "❌ ajv-cli is not installed. Install with: npm install -g ajv-cli"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Install with: brew install jq"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "❌ yq is not installed. Install with: brew install yq"
    exit 1
fi

# Run tests
cd "$PROJECT_ROOT"

if [[ "$1" == "--verbose" ]] || [[ "$1" == "-v" ]]; then
    bats --verbose-run tests/*.bats
else
    bats tests/*.bats
fi

echo ""
echo "✅ All tests passed!"
