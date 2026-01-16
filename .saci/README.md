# Saci Hooks System

This directory contains hooks that integrate with Claude Code's hook system to provide intelligent error handling and command validation.

## 📁 Structure

```
.saci/
├── hooks/
│   ├── validate-bash.py       # PreToolUse: Validates Bash commands before execution
│   ├── check-test-output.py   # PostToolUse: Classifies test errors after execution
│   ├── add-context.sh         # UserPromptSubmit: Injects repo context automatically
│   └── check-if-done.py       # Stop: Prevents premature stopping when tests fail
└── README.md                  # This file
```

## 🎯 Hook Overview

### 1. validate-bash.py (PreToolUse)
**Purpose:** Prevent invalid commands from being executed

**Validates:**
- npm scripts (checks if script exists in package.json)
- git commands (blocks dangerous operations like force push to main)
- file operations (checks if paths exist)

**Exit codes:**
- `0`: Allow command (valid)
- `2`: BLOCK command (invalid, sends feedback to Claude)

**Example:**
```bash
# Claude tries: npm run db:push
# Hook checks package.json
# Script doesn't exist → Exit 2
# Claude receives: "Script 'db:push' doesn't exist. Available: test, build, typecheck"
# Claude uses: npm run db:migrate ✓
```

### 2. check-test-output.py (PostToolUse)
**Purpose:** Classify errors after test execution

**Classifications:**
- `ENVIRONMENT`: missing scripts, wrong paths, dependencies
- `CODE`: syntax errors, type errors, test failures
- `TIMEOUT`: hanging processes
- `UNKNOWN`: unclassified errors

**Output:**
```json
{
  "decision": "block",
  "reason": "Test failed: TypeError at line 42 (CODE error)",
  "hookSpecificOutput": {
    "errorType": "CODE",
    "suggestion": "Check variable initialization"
  }
}
```

### 3. add-context.sh (UserPromptSubmit)
**Purpose:** Automatically inject useful repo context

**Injects:**
- Current git branch
- Number of uncommitted files
- Available npm scripts
- Last npm error (if any)

**Benefit:** Claude gets context without having to search for it

### 4. check-if-done.py (Stop)
**Purpose:** Prevent Claude from stopping when tests still fail

**Behavior:**
- Runs test command
- If tests fail → blocks stop with message
- If tests pass → allows stop

**Safety net:** Ensures quality before task completion

## 🔧 Configuration

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/validate-bash.py",
        "timeout": 5
      }]
    }],
    "PostToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/check-test-output.py",
        "timeout": 10
      }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/add-context.sh",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/check-if-done.py",
        "timeout": 5
      }]
    }]
  }
}
```

## 🧪 Testing Hooks

### Test PreToolUse Hook:
```bash
# Simulate Claude trying invalid npm script
echo '{"tool_name":"Bash","tool_input":{"command":"npm run db:push"}}' | \
  .saci/hooks/validate-bash.py

# Expected: Exit 2, JSON with permissionDecision: "deny"
```

### Test PostToolUse Hook:
```bash
# Simulate test failure
test_output="FAIL src/auth.ts:42
TypeError: Cannot read property 'map' of undefined"

echo "{\"tool_response\":\"$test_output\"}" | \
  .saci/hooks/check-test-output.py

# Expected: Classification as CODE error
```

### Test Stop Hook:
```bash
# Run manually
.saci/hooks/check-if-done.py

# Expected: Blocks if tests fail, allows if tests pass
```

### Test UserPromptSubmit Hook:
```bash
# Run manually
.saci/hooks/add-context.sh

# Expected: Outputs repo context (branch, scripts, etc)
```

## 📊 Impact Metrics

**Before hooks:**
- Loop efficiency: ~30% (7/10 iterations are retries)
- Commands blocked: 0
- Average iterations per task: 4-6

**After hooks (target):**
- Loop efficiency: >70%
- Commands blocked: >2 per task
- Average iterations per task: 1-3

## 🔗 References

- [hooks.md](../.claude/docs/hooks.md) - Claude Code hooks reference
- [saci-analysis.md](../.claude/docs/saci-analysis.md) - Complete Saci analysis
- [Official hooks guide](https://code.claude.com/docs/en/hooks-guide.md)
