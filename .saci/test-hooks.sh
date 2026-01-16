#!/bin/bash
#
# Saci Hooks Test Suite
#
# Tests all hooks individually and verifies they work correctly.
# Run this script before deploying hooks to production.
#
# Usage: .saci/test-hooks.sh
#

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# ================================================================
# TEST 1: PreToolUse Hook - validate-bash.py
# ================================================================
print_header "TEST 1: PreToolUse Hook (validate-bash.py)"

# Test 1.1: Valid npm script
print_test "1.1 Valid npm script (npm test)"
run_test
input='{"tool_name":"Bash","tool_input":{"command":"npm test"}}'
output=$(echo "$input" | .saci/hooks/validate-bash.py 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_pass "Valid npm script allowed (exit 0)"
else
    print_fail "Valid npm script was blocked (exit $exit_code)"
fi

# Test 1.2: Invalid npm script
print_test "1.2 Invalid npm script (npm run nonexistent)"
run_test
input='{"tool_name":"Bash","tool_input":{"command":"npm run nonexistent-script-12345"}}'
output=$(echo "$input" | .saci/hooks/validate-bash.py 2>&1)
exit_code=$?

if echo "$output" | grep -q "does not exist"; then
    print_pass "Invalid npm script blocked with helpful message"
else
    print_fail "Invalid npm script not properly blocked"
fi

# Test 1.3: Force push to main (should block)
print_test "1.3 Dangerous git operation (force push to main)"
run_test
input='{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}'
output=$(echo "$input" | .saci/hooks/validate-bash.py 2>&1)
exit_code=$?

if echo "$output" | grep -q "blocked"; then
    print_pass "Dangerous git operation blocked"
else
    print_fail "Dangerous git operation was not blocked"
fi

# Test 1.4: Normal command (should allow)
print_test "1.4 Normal command (ls -la)"
run_test
input='{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
output=$(echo "$input" | .saci/hooks/validate-bash.py 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_pass "Normal command allowed"
else
    print_fail "Normal command was blocked (exit $exit_code)"
fi

# ================================================================
# TEST 2: PostToolUse Hook - check-test-output.py
# ================================================================
print_header "TEST 2: PostToolUse Hook (check-test-output.py)"

# Test 2.1: ENVIRONMENT error (missing npm script)
print_test "2.1 Classify ENVIRONMENT error (missing script)"
run_test
input='{"tool_response":"npm ERR! missing script: db:push"}'
output=$(echo "$input" | .saci/hooks/check-test-output.py 2>&1)

if echo "$output" | grep -q "ENVIRONMENT"; then
    print_pass "Missing script classified as ENVIRONMENT"
else
    print_fail "Missing script not classified as ENVIRONMENT"
fi

# Test 2.2: CODE error (TypeError)
print_test "2.2 Classify CODE error (TypeError)"
run_test
input='{"tool_response":"TypeError: Cannot read property map of undefined at file.ts:42"}'
output=$(echo "$input" | .saci/hooks/check-test-output.py 2>&1)

if echo "$output" | grep -q "CODE"; then
    print_pass "TypeError classified as CODE error"
else
    print_fail "TypeError not classified as CODE error"
fi

# Test 2.3: Test failure
print_test "2.3 Classify test failure"
run_test
input='{"tool_response":"FAIL src/auth.test.ts\n5 tests failed"}'
output=$(echo "$input" | .saci/hooks/check-test-output.py 2>&1)

if echo "$output" | grep -q "CODE"; then
    print_pass "Test failure classified as CODE error"
else
    print_fail "Test failure not classified as CODE error"
fi

# Test 2.4: File not found (ENVIRONMENT)
print_test "2.4 Classify file not found (ENVIRONMENT)"
run_test
input='{"tool_response":"ENOENT: no such file or directory, open /path/to/file.txt"}'
output=$(echo "$input" | .saci/hooks/check-test-output.py 2>&1)

if echo "$output" | grep -q "ENVIRONMENT"; then
    print_pass "File not found classified as ENVIRONMENT"
else
    print_fail "File not found not classified as ENVIRONMENT"
fi

# ================================================================
# TEST 3: Stop Hook - check-if-done.py
# ================================================================
print_header "TEST 3: Stop Hook (check-if-done.py)"

# Test 3.1: Run stop hook
print_test "3.1 Stop hook execution"
run_test
input='{}'
output=$(echo "$input" | .saci/hooks/check-if-done.py 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_pass "Stop hook executed successfully (exit 0)"
else
    print_fail "Stop hook failed (exit $exit_code)"
fi

# Note: This test depends on whether tests actually pass or fail
# We can't easily simulate this without a real test suite

# ================================================================
# TEST 4: UserPromptSubmit Hook - add-context.sh
# ================================================================
print_header "TEST 4: UserPromptSubmit Hook (add-context.sh)"

# Test 4.1: Run context injection
print_test "4.1 Context injection execution"
run_test
output=$(.saci/hooks/add-context.sh 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_pass "Context injection executed successfully"
else
    print_fail "Context injection failed (exit $exit_code)"
fi

# Test 4.2: Check for git context
print_test "4.2 Git context included"
run_test
if echo "$output" | grep -q "\*\*Branch\*\*:"; then
    print_pass "Git branch information included"
else
    print_fail "Git branch information missing"
fi

# Test 4.3: Check for npm scripts (only if package.json exists)
print_test "4.3 npm scripts listed (if package.json exists)"
run_test
if [ -f "package.json" ]; then
    if echo "$output" | grep -q "Available npm Scripts"; then
        print_pass "npm scripts section included"
    else
        print_fail "npm scripts section missing (package.json exists but section not found)"
    fi
else
    # No package.json, so we expect no npm scripts section
    if echo "$output" | grep -q "Available npm Scripts"; then
        print_fail "npm scripts section should not be included (no package.json)"
    else
        print_pass "npm scripts section correctly omitted (no package.json)"
    fi
fi

# ================================================================
# TEST 5: Hook Permissions
# ================================================================
print_header "TEST 5: Hook File Permissions"

# Test 5.1: Check all hooks are executable
hooks=(
    ".saci/hooks/validate-bash.py"
    ".saci/hooks/check-test-output.py"
    ".saci/hooks/check-if-done.py"
    ".saci/hooks/add-context.sh"
)

for hook in "${hooks[@]}"; do
    print_test "5.x Check $hook is executable"
    run_test

    if [ -x "$hook" ]; then
        print_pass "$hook is executable"
    else
        print_fail "$hook is NOT executable (run: chmod +x $hook)"
    fi
done

# ================================================================
# TEST 6: Configuration File
# ================================================================
print_header "TEST 6: Configuration Validation"

# Test 6.1: Check settings.json exists
print_test "6.1 .claude/settings.json exists"
run_test
if [ -f ".claude/settings.json" ]; then
    print_pass "settings.json exists"
else
    print_fail "settings.json not found"
fi

# Test 6.2: Validate JSON syntax
print_test "6.2 settings.json is valid JSON"
run_test
if jq empty .claude/settings.json 2>/dev/null; then
    print_pass "settings.json is valid JSON"
else
    print_fail "settings.json has invalid JSON syntax"
fi

# Test 6.3: Check hooks are configured
print_test "6.3 Hooks configured in settings.json"
run_test
if jq -e '.hooks' .claude/settings.json >/dev/null 2>&1; then
    print_pass "Hooks section exists in settings.json"
else
    print_fail "Hooks section missing in settings.json"
fi

# ================================================================
# SUMMARY
# ================================================================
print_header "TEST SUMMARY"

echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Hooks are ready to use! 🎉"
    echo ""
    echo "Next steps:"
    echo "1. Test with Claude Code: claude (in interactive mode)"
    echo "2. Run Saci with a simple task to verify hooks work end-to-end"
    echo "3. Monitor .claude/logs/ for hook execution details"
    exit 0
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Please fix the failures above before using hooks in production."
    exit 1
fi
