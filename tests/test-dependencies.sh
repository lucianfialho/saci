#!/bin/bash
# ============================================================================
# Integration Tests for Saci Dependency System
# Tests: linear deps, circular deps, mode 'any', cross-feature, cascade reset
# ============================================================================

set -euo pipefail

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SACI_DIR="$(dirname "$SCRIPT_DIR")"

# Test helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_empty() {
    local actual="$1"
    local test_name="$2"

    if [ -n "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected non-empty output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Actual: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" -eq "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Create temp PRP file
create_temp_prp() {
    local temp_file=$(mktemp)
    cat > "$temp_file" <<'EOF'
{
  "project": {
    "name": "Test Project",
    "description": "Test",
    "branchName": "test"
  },
  "features": [
    {
      "id": "F1",
      "name": "Feature 1",
      "description": "Test feature 1",
      "priority": 1,
      "tasks": []
    },
    {
      "id": "F2",
      "name": "Feature 2",
      "description": "Test feature 2",
      "priority": 2,
      "tasks": []
    }
  ]
}
EOF
    echo "$temp_file"
}

# Inline dependency functions (copied from saci.sh for testing)
get_task_dependencies() {
    local prp_file="$1"
    local task_id="$2"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .dependencies // [] | .[]
    ' "$prp_file"
}

get_dependency_mode() {
    local prp_file="$1"
    local task_id="$2"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .dependencyMode // "all"
    ' "$prp_file"
}

check_dependencies_met() {
    local prp_file="$1"
    local task_id="$2"
    local mode=$(get_dependency_mode "$prp_file" "$task_id")
    local dependencies=$(get_task_dependencies "$prp_file" "$task_id")

    # If no dependencies, always met
    if [ -z "$dependencies" ]; then
        return 0
    fi

    local met_count=0
    local total_count=0

    while IFS= read -r dep_id; do
        [ -z "$dep_id" ] && continue
        total_count=$((total_count + 1))

        # Check if dependency task passes
        local dep_passes=$(jq -r --arg id "$dep_id" '
            .features[].tasks[] | select(.id == $id) | .passes // false
        ' "$prp_file")

        if [ "$dep_passes" = "true" ]; then
            met_count=$((met_count + 1))
        fi
    done <<< "$dependencies"

    # If mode is 'any', at least one dependency must be met
    if [ "$mode" = "any" ]; then
        [ $met_count -gt 0 ]
        return $?
    fi

    # Default mode is 'all', all dependencies must be met
    [ $met_count -eq $total_count ]
    return $?
}

detect_circular_dependency() {
    local prp_file="$1"
    local task_id="$2"
    local path="${3:-}"
    local visited="${4:-}"

    # Add current task to path
    if [ -z "$path" ]; then
        path="$task_id"
    else
        path="$path -> $task_id"
    fi

    # Check if we've visited this node before (cycle detected)
    if echo " $visited " | grep -q " $task_id "; then
        # Cycle detected! Return the full path
        echo "$path"
        return 1
    fi

    # Add to visited list
    visited="$visited $task_id"

    # Get dependencies of current task
    local dependencies=$(get_task_dependencies "$prp_file" "$task_id")

    # If no dependencies, no cycle from this path
    if [ -z "$dependencies" ]; then
        return 0
    fi

    # Check each dependency recursively
    while IFS= read -r dep_id; do
        [ -z "$dep_id" ] && continue

        # Recursively check this dependency
        local cycle_path
        if ! cycle_path=$(detect_circular_dependency "$prp_file" "$dep_id" "$path" "$visited"); then
            # Cycle detected in recursive call
            echo "$cycle_path"
            return 1
        fi
    done <<< "$dependencies"

    # No cycle found from this task
    return 0
}

get_dependent_tasks() {
    local prp_file="$1"
    local target_id="$2"
    jq -r --arg id "$target_id" '
        .features[].tasks[] |
        select(.dependencies // [] | index($id)) |
        .id
    ' "$prp_file"
}

reset_task_cascade() {
    local prp_file="$1"
    local task_id="$2"
    local reset_list="${3:-}"

    # Check if already reset to avoid infinite loops
    if echo " $reset_list " | grep -q " $task_id "; then
        echo "$reset_list"
        return 0
    fi

    # Reset this task
    local tmp_file=$(mktemp)
    jq --arg id "$task_id" '
        .features |= map(.tasks |= map(if .id == $id then .passes = false else . end))
    ' "$prp_file" > "$tmp_file" && mv "$tmp_file" "$prp_file"

    # Add to reset list
    reset_list="$reset_list $task_id"

    # Find all tasks that depend on this task
    local dependents=$(get_dependent_tasks "$prp_file" "$task_id")

    # Recursively reset each dependent
    if [ -n "$dependents" ]; then
        while IFS= read -r dep_task; do
            [ -z "$dep_task" ] && continue
            reset_list=$(reset_task_cascade "$prp_file" "$dep_task" "$reset_list")
        done <<< "$dependents"
    fi

    echo "$reset_list"
}

# ============================================================================
# Test 1: Linear Dependency (A->B->C)
# ============================================================================
test_linear_dependency() {
    echo ""
    echo "=== Test 1: Linear Dependency (A->B->C) ==="

    local temp_prp=$(create_temp_prp)

    # Create test tasks: T1 -> T2 -> T3
    jq '.features[0].tasks = [
        {
            "id": "F1-T1",
            "title": "Task 1",
            "description": "First task",
            "priority": 1,
            "passes": false,
            "dependencies": []
        },
        {
            "id": "F1-T2",
            "title": "Task 2",
            "description": "Second task",
            "priority": 2,
            "passes": false,
            "dependencies": ["F1-T1"],
            "dependencyMode": "all"
        },
        {
            "id": "F1-T3",
            "title": "Task 3",
            "description": "Third task",
            "priority": 3,
            "passes": false,
            "dependencies": ["F1-T2"],
            "dependencyMode": "all"
        }
    ]' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: T2 dependencies should not be met (T1 incomplete)
    local result=0
    check_dependencies_met "$temp_prp" "F1-T2" || result=$?
    assert_exit_code 1 $result "T2 blocked when T1 incomplete"

    # Mark T1 as complete
    jq '.features[0].tasks[0].passes = true' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: T2 dependencies should now be met
    result=0
    check_dependencies_met "$temp_prp" "F1-T2" || result=$?
    assert_exit_code 0 $result "T2 unblocked when T1 complete"

    # Test: T3 still blocked (T2 incomplete)
    result=0
    check_dependencies_met "$temp_prp" "F1-T3" || result=$?
    assert_exit_code 1 $result "T3 blocked when T2 incomplete"

    # Mark T2 as complete
    jq '.features[0].tasks[1].passes = true' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: T3 dependencies should now be met
    result=0
    check_dependencies_met "$temp_prp" "F1-T3" || result=$?
    assert_exit_code 0 $result "T3 unblocked when T2 complete"

    rm -f "$temp_prp" "${temp_prp}.tmp"
}

# ============================================================================
# Test 2: Circular Dependency Detection
# ============================================================================
test_circular_dependency() {
    echo ""
    echo "=== Test 2: Circular Dependency Detection ==="

    local temp_prp=$(create_temp_prp)

    # Create circular dependency: T1 -> T2 -> T3 -> T1
    jq '.features[0].tasks = [
        {
            "id": "F1-T1",
            "title": "Task 1",
            "description": "First task",
            "priority": 1,
            "passes": false,
            "dependencies": ["F1-T3"]
        },
        {
            "id": "F1-T2",
            "title": "Task 2",
            "description": "Second task",
            "priority": 2,
            "passes": false,
            "dependencies": ["F1-T1"]
        },
        {
            "id": "F1-T3",
            "title": "Task 3",
            "description": "Third task",
            "priority": 3,
            "passes": false,
            "dependencies": ["F1-T2"]
        }
    ]' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: detect_circular_dependency should find cycle
    local cycle_output
    local exit_code=0
    cycle_output=$(detect_circular_dependency "$temp_prp" "F1-T1" "" "" 2>&1) || exit_code=$?

    assert_exit_code 1 $exit_code "Detects circular dependency"
    assert_contains "$cycle_output" "F1-T1" "Cycle path contains F1-T1"
    assert_contains "$cycle_output" "F1-T2" "Cycle path contains F1-T2"
    assert_contains "$cycle_output" "F1-T3" "Cycle path contains F1-T3"

    rm -f "$temp_prp" "${temp_prp}.tmp"
}

# ============================================================================
# Test 3: Mode 'any' - One Dependency Complete
# ============================================================================
test_dependency_mode_any() {
    echo ""
    echo "=== Test 3: Dependency Mode 'any' ==="

    local temp_prp=$(create_temp_prp)

    # Create task with 'any' mode: T3 depends on (T1 OR T2)
    jq '.features[0].tasks = [
        {
            "id": "F1-T1",
            "title": "Task 1",
            "description": "First task",
            "priority": 1,
            "passes": false,
            "dependencies": []
        },
        {
            "id": "F1-T2",
            "title": "Task 2",
            "description": "Second task",
            "priority": 2,
            "passes": false,
            "dependencies": []
        },
        {
            "id": "F1-T3",
            "title": "Task 3",
            "description": "Third task",
            "priority": 3,
            "passes": false,
            "dependencies": ["F1-T1", "F1-T2"],
            "dependencyMode": "any"
        }
    ]' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: T3 blocked when neither T1 nor T2 complete
    local result=0
    check_dependencies_met "$temp_prp" "F1-T3" || result=$?
    assert_exit_code 1 $result "T3 blocked when no dependencies met (mode: any)"

    # Mark T1 as complete (T2 still incomplete)
    jq '.features[0].tasks[0].passes = true' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: T3 unblocked when ANY dependency met
    result=0
    check_dependencies_met "$temp_prp" "F1-T3" || result=$?
    assert_exit_code 0 $result "T3 unblocked when one dependency met (mode: any)"

    rm -f "$temp_prp" "${temp_prp}.tmp"
}

# ============================================================================
# Test 4: Cross-Feature Dependency
# ============================================================================
test_cross_feature_dependency() {
    echo ""
    echo "=== Test 4: Cross-Feature Dependency ==="

    local temp_prp=$(create_temp_prp)

    # Create cross-feature dependency: F2-T1 depends on F1-T1
    jq '.features[0].tasks = [
        {
            "id": "F1-T1",
            "title": "Feature 1 Task 1",
            "description": "Task in feature 1",
            "priority": 1,
            "passes": false,
            "dependencies": []
        }
    ] | .features[1].tasks = [
        {
            "id": "F2-T1",
            "title": "Feature 2 Task 1",
            "description": "Task in feature 2",
            "priority": 1,
            "passes": false,
            "dependencies": ["F1-T1"],
            "dependencyMode": "all"
        }
    ]' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: F2-T1 blocked when F1-T1 incomplete
    local result=0
    check_dependencies_met "$temp_prp" "F2-T1" || result=$?
    assert_exit_code 1 $result "F2-T1 blocked by incomplete F1-T1"

    # Mark F1-T1 as complete
    jq '.features[0].tasks[0].passes = true' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: F2-T1 unblocked when F1-T1 complete
    result=0
    check_dependencies_met "$temp_prp" "F2-T1" || result=$?
    assert_exit_code 0 $result "F2-T1 unblocked when F1-T1 complete"

    rm -f "$temp_prp" "${temp_prp}.tmp"
}

# ============================================================================
# Test 5: Missing Dependency ID
# ============================================================================
test_missing_dependency() {
    echo ""
    echo "=== Test 5: Missing Dependency ID ==="

    local temp_prp=$(create_temp_prp)

    # Create task with non-existent dependency
    jq '.features[0].tasks = [
        {
            "id": "F1-T1",
            "title": "Task 1",
            "description": "Task with invalid dependency",
            "priority": 1,
            "passes": false,
            "dependencies": ["F1-T99"],
            "dependencyMode": "all"
        }
    ]' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: Missing dependency treated as not met
    local result=0
    check_dependencies_met "$temp_prp" "F1-T1" || result=$?
    assert_exit_code 1 $result "Task blocked when dependency ID not found"

    # Test: get_task_dependencies returns the missing ID
    local deps=$(get_task_dependencies "$temp_prp" "F1-T1")
    assert_equals "F1-T99" "$deps" "Missing dependency ID returned by get_task_dependencies"

    rm -f "$temp_prp" "${temp_prp}.tmp"
}

# ============================================================================
# Test 6: Cascade Reset
# ============================================================================
test_cascade_reset() {
    echo ""
    echo "=== Test 6: Cascade Reset ==="

    local temp_prp=$(create_temp_prp)

    # Create dependency chain: T1 -> T2 -> T3
    # Mark all as complete
    jq '.features[0].tasks = [
        {
            "id": "F1-T1",
            "title": "Task 1",
            "description": "First task",
            "priority": 1,
            "passes": true,
            "dependencies": []
        },
        {
            "id": "F1-T2",
            "title": "Task 2",
            "description": "Second task",
            "priority": 2,
            "passes": true,
            "dependencies": ["F1-T1"]
        },
        {
            "id": "F1-T3",
            "title": "Task 3",
            "description": "Third task",
            "priority": 3,
            "passes": true,
            "dependencies": ["F1-T2"]
        }
    ]' "$temp_prp" > "${temp_prp}.tmp" && mv "${temp_prp}.tmp" "$temp_prp"

    # Test: All tasks initially complete
    local t1_passes=$(jq -r '.features[0].tasks[0].passes' "$temp_prp")
    local t2_passes=$(jq -r '.features[0].tasks[1].passes' "$temp_prp")
    local t3_passes=$(jq -r '.features[0].tasks[2].passes' "$temp_prp")
    assert_equals "true" "$t1_passes" "T1 initially complete"
    assert_equals "true" "$t2_passes" "T2 initially complete"
    assert_equals "true" "$t3_passes" "T3 initially complete"

    # Perform cascade reset on T1
    local reset_list=$(reset_task_cascade "$temp_prp" "F1-T1" "")

    # Test: Reset list contains all three tasks
    assert_contains "$reset_list" "F1-T1" "Cascade reset includes T1"
    assert_contains "$reset_list" "F1-T2" "Cascade reset includes T2"
    assert_contains "$reset_list" "F1-T3" "Cascade reset includes T3"

    # Test: All tasks now incomplete
    local t1_passes=$(jq -r '.features[0].tasks[0].passes' "$temp_prp")
    local t2_passes=$(jq -r '.features[0].tasks[1].passes' "$temp_prp")
    local t3_passes=$(jq -r '.features[0].tasks[2].passes' "$temp_prp")
    assert_equals "false" "$t1_passes" "T1 reset to incomplete"
    assert_equals "false" "$t2_passes" "T2 reset to incomplete"
    assert_equals "false" "$t3_passes" "T3 reset to incomplete"

    rm -f "$temp_prp" "${temp_prp}.tmp"
}

# ============================================================================
# Run All Tests
# ============================================================================
main() {
    echo "=========================================="
    echo "Saci Dependency System Integration Tests"
    echo "=========================================="

    test_linear_dependency
    test_circular_dependency
    test_dependency_mode_any
    test_cross_feature_dependency
    test_missing_dependency
    test_cascade_reset

    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo "Total: $((TESTS_PASSED + TESTS_FAILED))"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main "$@"
