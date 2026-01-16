#!/bin/bash
#
# Debug Mode Patch for Saci
# Adds error classification and environment-fixer subagent integration
#

# This script contains the functions to be added to saci.sh
# Insert after log_progress() function (around line 93)

cat <<'PATCH_EOF'

# ============================================================================
# Debug Mode Functions - Subagent Integration
# ============================================================================

classify_error_type() {
    local test_output="$1"

    # Use PostToolUse hook to classify error type
    local hook_output=$(echo "{\"tool_response\":$(echo "$test_output" | jq -Rs .)}" | \
        .saci/hooks/check-test-output.py 2>/dev/null)

    if [ -n "$hook_output" ]; then
        local error_type=$(echo "$hook_output" | jq -r '.hookSpecificOutput.errorType // "UNKNOWN"')
        local error_reason=$(echo "$hook_output" | jq -r '.hookSpecificOutput.errorReason // ""')
        local suggestion=$(echo "$hook_output" | jq -r '.hookSpecificOutput.suggestion // ""')

        echo "$error_type|$error_reason|$suggestion"
    else
        echo "UNKNOWN||"
    fi
}

invoke_environment_fixer() {
    local task_id="$1"
    local test_output="$2"
    local test_cmd="$3"

    log_warning "🤖 Environment error detected - invoking environment-fixer subagent..."

    # Build specialized prompt for environment fixer
    local fixer_prompt="You are an environment troubleshooting specialist. A task failed due to an ENVIRONMENT error.

## Task Information
- **Task ID:** $task_id
- **Test Command:** $test_cmd

## Error Output
\`\`\`
$test_output
\`\`\`

## Your Mission
1. Analyze the error above (it's an ENVIRONMENT issue, not CODE)
2. Identify the root cause (missing script, dependency, file, etc.)
3. Implement a minimal fix
4. Verify the test command now passes

## Tools Available
- Read: Read files to understand current state
- Edit: Modify files to fix configuration
- Bash: Run commands (install deps, create files, fix permissions)

## Constraints
- Focus ONLY on fixing the environment issue
- Make minimal changes
- Don't refactor or improve code
- Don't fix CODE errors (syntax, logic, etc.)

## Success Criteria
The test command must pass: \`$test_cmd\`

Start investigating and fixing now."

    # Create temporary prompt file
    local fixer_prompt_file=$(mktemp)
    echo "$fixer_prompt" > "$fixer_prompt_file"

    # Invoke Claude with environment-fixer context
    log_info "Running environment-fixer subagent..."
    local fixer_output_file=$(mktemp)

    if cat "$fixer_prompt_file" | claude --print --dangerously-skip-permissions --max-turns 3 2>&1 | tee "$fixer_output_file"; then
        rm -f "$fixer_prompt_file"

        # Test if the fix worked
        log_info "Testing if environment-fixer resolved the issue..."
        local fix_test_output=$(mktemp)

        if eval "$test_cmd" 2>&1 | tee "$fix_test_output"; then
            log_success "✅ Environment-fixer RESOLVED the issue!"
            rm -f "$fixer_output_file" "$fix_test_output"
            return 0
        else
            log_warning "Environment-fixer attempted fix but tests still fail"
            rm -f "$fixer_output_file" "$fix_test_output"
            return 1
        fi
    else
        log_error "Environment-fixer subagent failed to execute"
        rm -f "$fixer_prompt_file" "$fixer_output_file"
        return 1
    fi
}

PATCH_EOF

echo ""
echo "==================================="
echo "To apply this patch manually:"
echo "1. Add the above functions after log_progress() in saci.sh (around line 93)"
echo "2. Modify the error handling section (after 'TESTS FAILED') to:"
echo "   a. Classify error type"
echo "   b. Invoke environment-fixer if ENVIRONMENT error"
echo "   c. Commit and mark complete if fixer resolves issue"
echo "   d. Otherwise proceed with rollback as normal"
echo "==================================="
