# 🌪️ Saci

**The Brazilian fork of Ralph**

Saci is an autonomous loop that runs [Claude Code](https://docs.anthropic.com/en/docs/claude-code) repeatedly until all tasks are complete. Inspired by [Ralph](https://github.com/snarktank/ralph), with resilience improvements and extra tooling.

> Like the Saci Pererê (Brazilian folklore): mischievous, agile, and solves problems its own way.

## Saci vs Ralph

| Feature | Ralph | Saci |
|---------|-------|------|
| Autonomous loop | ✅ | ✅ |
| New session per task | ✅ | ✅ |
| Auto rollback (git reset) | ❌ | ✅ |
| Pass previous error to retry | ❌ | ✅ |
| Stack scanner | ❌ | ✅ `saci scan` |
| Interactive PRP generator | ❌ | ✅ `saci init` + `/prp` skill (native mode) |
| Pattern analyzer | ❌ | ✅ `saci analyze` |
| **Intelligent hooks** | ❌ | ✅ **4 hooks: validate, classify, prevent stop, context** |
| **Error classification** | ❌ | ✅ **ENVIRONMENT vs CODE auto-detection** |
| **Debug mode** | ❌ | ✅ **Auto-fix ENVIRONMENT errors with subagents** |
| Safety hooks | ❌ | ✅ Blocks dangerous commands |
| Global installation | ❌ | ✅ Works from any directory |
| Generates AGENTS.md | ❌ | ✅ Auto-detects context |
| Task structure | `userStories[]` flat | `features[].tasks[]` hierarchical |
| Task dependencies | ❌ | ✅ DAG with circular detection |

## Installation

### One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/lucianfialho/saci/main/install.sh | bash
```

This downloads and installs Saci globally. You can then use `saci` from any directory!

### From source

```bash
git clone https://github.com/lucianfialho/saci.git
cd saci
./install.sh
```

Same installer script auto-detects if you're in the repo or installing remotely.

### Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- Git
- `gum` (optional, for TUI mode - `brew install gum` on macOS)

## Commands

| Command | Description |
|---------|-------------|
| `saci scan` | Detects stack, generates `prp.json` and `AGENTS.md` |
| `saci init` | Creates a PRP interactively |
| `saci analyze <file>` | Analyzes a file and suggests patterns |
| `saci reset [task-id]` | Resets all tasks (or specific task) to `passes: false` |
| `saci jump` | Starts the Autonomous Loop |

## Workflow

```bash
cd my-project

# 1. Detect project context
saci scan

# 2. Plan feature (uses prp skill)
# In Claude Code: "skill prp" → answer questions → generates prp.json

# 3. Execute
saci jump
```

### Jump Options

```bash
saci jump                    # Jump with defaults
saci jump --tui              # Enable visual TUI mode (requires gum)
saci jump --dry-run          # Show what would happen without executing
saci jump --prp custom.json  # Use different PRP file
saci jump --max-iter 20      # Max iterations (default: 10)
```

## How It Works

### Saci Flow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                     SETUP PHASE                                │
└────────────────────────────────────────────────────────────────┘

   ┌──────────────────────┐
   │ 1. Create PRP        │  You: claude /prp  OR  saci init
   │ (Product Req Plan)   │  Define features & tasks
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 2. Generate          │  Tasks with dependencies (DAG)
   │ prp.json             │  Cross-feature deps supported
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 3. Run saci jump     │  Validate dependencies
   │                      │  Detect circular refs
   └──────────┬───────────┘
              │
              ▼

┌────────────────────────────────────────────────────────────────┐
│                      LOOP PHASE                                │
└────────────────────────────────────────────────────────────────┘

   ┌──────────────────────┐
   │ 4. Pick next task    │  Respect dependencies
   │                      │  Find ready task (passes: false)
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 5. Detect domain     │  frontend/backend/devops/testing/docs
   │    & task type       │  feature/bugfix/refactor
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 6. Build PRP prompt  │  5 layers:
   │                      │  • base.md (System + Interaction + Response)
   │                      │  • domain.md (frontend/backend/devops/etc)
   │                      │  • task-type.md (feature/bugfix/refactor)
   │                      │  • task context (from prp.json)
   │                      │  • progress history (last 100 lines)
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 7. Git checkpoint    │  Create checkpoint before changes
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 🪝 UserPromptSubmit  │  Auto-inject context:
   │                      │  • Branch, uncommitted files
   │                      │  • Available npm scripts
   │                      │  • Framework, language
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 8. Spawn Claude Code │  New session (clean context)
   │                      │  Send PRP prompt
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 9. Claude implements │
   │                      │  ┌──────────────────┐
   │                      │  │ 🪝 PreToolUse    │  Validate commands BEFORE
   │                      │  │ (validate-bash)  │  • npm scripts exist?
   │                      │  │                  │  • git push safe?
   │                      │  │                  │  • file paths valid?
   │                      │  └──────────────────┘
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │ 10. Run tests        │  Execute test command
   └──────────┬───────────┘
              │
              ▼
   ┌──────────────────────┐
   │                      │  ┌──────────────────┐
   │ 🪝 PostToolUse       │  │ Error classifier │  ENVIRONMENT vs CODE
   │ (check-test-output)  │  │                  │  • Missing script?
   │                      │  │                  │  • Syntax error?
   │                      │  │                  │  • Type error?
   │                      │  └──────────────────┘
   └──────────┬───────────┘
              │
              ▼

┌────────────────────────────────────────────────────────────────┐
│                    DECISION POINT                              │
└────────────────────────────────────────────────────────────────┘

              ┌─────────────┐
              │ Tests pass? │
              └──────┬──────┘
                     │
        ┌────────────┴────────────┐
        │ YES                     │ NO
        ▼                         ▼
   ┌─────────────┐          ┌──────────────┐
   │ 11. Commit  │          │ 12. Rollback │  git reset --hard
   │ + Mark OK   │          │ + Retry      │  Save error context
   │             │          │              │
   │ passes:true │          │ Max retries? │
   └──────┬──────┘          └──────┬───────┘
          │                        │
          │                        ├─ YES → Give up, next task
          │                        │
          │                        └─ NO → Loop back to step 6
          │                                 (with error feedback)
          │
          ▼
   ┌──────────────────────┐
   │ 13. Log progress +   │  Learnings + token metrics
   │     metrics          │  Append to progress.txt
   └──────────┬───────────┘
              │
              ▼

┌────────────────────────────────────────────────────────────────┐
│                    COMPLETION CHECK                            │
└────────────────────────────────────────────────────────────────┘

              ┌─────────────┐
              │ More tasks? │
              └──────┬──────┘
                     │
        ┌────────────┴────────────┐
        │ YES                     │ NO
        │                         ▼
        │                    ┌────────────┐
        └──────────────────► │ 14. Done!  │  All tasks complete
           (back to step 4)  │            │  Review progress.txt
                             └────────────┘
```

### Key Differences from Ralph

| Feature | Ralph | Saci |
|---------|-------|------|
| **Task Selection** | Linear (first `passes: false`) | DAG-based (respects dependencies) |
| **Prompt System** | Generic `prompt.md` | 🎯 **PRP 5-layer** (base + domain + task-type) |
| **Domain Detection** | None | 🔍 Auto-detects frontend/backend/devops/testing/docs |
| **Error Handling** | Continues with error | 🔄 Git rollback + retry with error context |
| **Error Classification** | None | 🏷️ ENVIRONMENT vs CODE (enables auto-fix) |
| **Hooks** | None | 🪝 4 hooks (validate, classify, prevent stop, context) |
| **Metrics** | None | 📊 Token tracking + cost tracking |
| **Validation** | None | ✅ Circular dependency detection |

### Resilience (the differentiator)

- **New session per task**: Always clean context
- **Auto rollback**: `git reset --hard` on failure
- **Error feedback**: Exact error passed to next retry
- **External memory**: `progress.txt` persists learnings
- **🪝 Intelligent hooks**: Prevent invalid commands, classify errors, auto-context
- **🤖 Debug mode**: Auto-fix ENVIRONMENT errors with specialized subagents

## Structure

```
saci/
├── saci.sh              # Main script
├── install.sh           # Global installer
├── lib/
│   ├── scanner.sh       # Detects stack/libs
│   ├── generator.sh     # Wizard to create PRP
│   └── analyzer.sh      # Suggests patterns
├── .saci/               # Hooks and utilities
│   ├── hooks/
│   │   ├── validate-bash.py       # PreToolUse: Command validator
│   │   ├── check-test-output.py   # PostToolUse: Error classifier
│   │   ├── check-if-done.py       # Stop: Quality gate
│   │   └── add-context.sh         # UserPromptSubmit: Auto context
│   ├── test-hooks.sh               # Automated test suite (19 tests)
│   ├── hooks-integration-test.sh   # Integration tests (7 scenarios)
│   ├── TESTING.md                  # Testing guide
│   ├── DEBUG-MODE.md               # Debug mode documentation
│   └── README.md                   # Hooks overview
├── .claude/
│   ├── settings.json               # Hooks configuration
│   ├── agents/
│   │   └── environment-fixer.md    # Subagent for auto-fixing
│   └── docs/
│       ├── saci-analysis.md        # Complete system analysis
│       ├── hooks.md                # Claude Code hooks reference
│       └── cli-reference.md        # CLI flags documentation
└── templates/
    ├── prompt.md        # Instructions per iteration
    ├── AGENTS.md        # Context template
    ├── hooks/
    │   ├── hooks.json
    │   └── scripts/
    │       └── safety-check.py
    └── skills/
        ├── prp/         # Skill to generate PRP
        └── default.md   # Execution guidelines
```

## PRP Format

```json
{
  "project": {
    "name": "MyApp",
    "description": "Description",
    "branchName": "saci/feature-name"
  },
  "features": [
    {
      "id": "F1",
      "name": "Feature",
      "tasks": [
        {
          "id": "F1-T1",
          "title": "Task title",
          "priority": 1,
          "passes": false,
          "dependencies": [],
          "dependencyMode": "all",
          "context": {
            "files": ["src/file.ts"],
            "hints": ["Use pattern X"]
          },
          "acceptance": ["Criterion 1", "Typecheck passes"],
          "tests": { "command": "npm test" }
        }
      ]
    }
  ]
}
```

## Task Dependencies

Saci supports task dependencies, allowing you to define execution order and relationships between tasks.

### Dependency Fields

- **`dependencies`**: Array of task IDs that must complete before this task can run
  - Example: `["F1-T1", "F1-T2"]`
  - Empty array `[]` means no dependencies (task can run immediately)
  - Can reference tasks from other features (cross-feature dependencies)

- **`dependencyMode`**: How dependencies are evaluated (default: `"all"`)
  - `"all"`: **ALL** dependencies must complete (AND logic)
  - `"any"`: **ANY** dependency must complete (OR logic)

### Dependency Examples

#### Linear Dependencies (Sequential Tasks)

```json
{
  "tasks": [
    {
      "id": "F1-T1",
      "title": "Setup database schema",
      "dependencies": [],
      "passes": false
    },
    {
      "id": "F1-T2",
      "title": "Add migration scripts",
      "dependencies": ["F1-T1"],
      "dependencyMode": "all",
      "passes": false
    },
    {
      "id": "F1-T3",
      "title": "Seed initial data",
      "dependencies": ["F1-T2"],
      "dependencyMode": "all",
      "passes": false
    }
  ]
}
```

**Result**: Tasks execute in order: T1 → T2 → T3

#### Parallel Dependencies (Multiple Prerequisites)

```json
{
  "tasks": [
    {
      "id": "F1-T1",
      "title": "Create API endpoint",
      "dependencies": [],
      "passes": false
    },
    {
      "id": "F1-T2",
      "title": "Create UI component",
      "dependencies": [],
      "passes": false
    },
    {
      "id": "F1-T3",
      "title": "Integration test",
      "dependencies": ["F1-T1", "F1-T2"],
      "dependencyMode": "all",
      "passes": false
    }
  ]
}
```

**Result**: T1 and T2 can run in any order, T3 waits for both

#### Cross-Feature Dependencies

```json
{
  "features": [
    {
      "id": "F1",
      "tasks": [
        {
          "id": "F1-T1",
          "title": "Authentication system",
          "dependencies": [],
          "passes": false
        }
      ]
    },
    {
      "id": "F2",
      "tasks": [
        {
          "id": "F2-T1",
          "title": "User profile page",
          "dependencies": ["F1-T1"],
          "dependencyMode": "all",
          "passes": false
        }
      ]
    }
  ]
}
```

**Result**: F2-T1 cannot start until F1-T1 completes

#### OR Dependencies (Any Mode)

```json
{
  "tasks": [
    {
      "id": "F1-T1",
      "title": "Setup PostgreSQL",
      "dependencies": [],
      "passes": false
    },
    {
      "id": "F1-T2",
      "title": "Setup MySQL",
      "dependencies": [],
      "passes": false
    },
    {
      "id": "F1-T3",
      "title": "Run database tests",
      "dependencies": ["F1-T1", "F1-T2"],
      "dependencyMode": "any",
      "passes": false
    }
  ]
}
```

**Result**: T3 can run when **either** T1 **or** T2 completes (not both required)

### Dependency Validation

Saci automatically validates dependencies on startup:

- **Circular dependencies**: Detects cycles like T1 → T2 → T3 → T1
- **Missing task IDs**: Warns if dependency references non-existent task
- **Execution order**: Only selects tasks with satisfied dependencies

### Cascade Reset

Reset a task and all tasks that depend on it:

```bash
# Reset single task only
saci reset F1-T3

# Reset task + all dependent tasks recursively
saci reset F1-T1 --cascade
```

**Example**: If T1 → T2 → T3, then `saci reset F1-T1 --cascade` resets all three tasks.

### Visual Indicators (TUI Mode)

When running `saci jump --tui`, dependency status is shown:

- `■` Task complete
- `▶` Task currently running
- `□` Task ready (dependencies met)
- `⊗` Task blocked (dependencies not met)

Tasks blocked by dependencies show: `⊗ F1-T3 [depends on: F1-T1, F1-T2]`

## PRP Skill

Saci installs a skill in Claude Code to generate PRPs with **native interactive mode**:

```
> claude /prp
> "I want to add a priority system"

[Interactive UI appears with native questions:]
○ What is the scope? → Minimal MVP ✓
○ What is the goal? → New capability ✓
○ Who is the target user? → All users ✓
☑ Success criteria → [x] Faster workflows, [x] Better metrics

[Generates: tasks/prp-priority.md + prp.json]
```

**Why native mode?**
- ✨ Rich UI with descriptions for each option
- ⚡ Faster input (click vs type)
- ✅ Structured answers (no parsing errors)
- 🔄 Easy to change selections

**Alternative:** You can still use `saci init` for terminal-based questionnaire.

## Visual UI Verification (Optional)

For frontend tasks, you can use tools that allow Claude to verify UI in the browser:

| Tool | Type | Installation |
|------|------|--------------|
| **[Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp)** | MCP Server (Google official) | Config in `settings.json` |
| **[dev-browser](https://github.com/SawyerHood/dev-browser)** | Plugin/Skill | `/plugin install dev-browser` |

**Chrome DevTools MCP** (recommended):
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}
```

With this, UI tasks can have in acceptance criteria:
> "Verify in browser that the change works"

Claude opens the browser, navigates, clicks, sees console errors, and validates visually.

## 🪝 Intelligent Hooks System

Saci integrates with Claude Code's hook system to provide intelligent command validation, error classification, and automatic context injection.

### 4 Production Hooks

#### 1. PreToolUse: Command Validator (`.saci/hooks/validate-bash.py`)

**Blocks invalid commands BEFORE execution** to prevent infinite loops:

```bash
# Example: Claude tries invalid npm script
Claude: npm run db:push
Hook:   ❌ BLOCKED - Script 'db:push' doesn't exist
        Available scripts: test, build, typecheck
Claude: npm run db:migrate ✓
```

**Validates:**
- ✅ npm scripts (checks package.json)
- ✅ git operations (blocks force push to main)
- ✅ file operations (checks paths exist)

**Impact:** Reduces wasted iterations by ~40%

#### 2. PostToolUse: Error Classifier (`.saci/hooks/check-test-output.py`)

**Classifies errors automatically** for smarter retry strategies:

| Error Type | Examples | Next Action |
|-----------|----------|-------------|
| **ENVIRONMENT** | Missing script, dependency, file | 🤖 Invoke auto-fixer subagent |
| **CODE** | Syntax error, type error, test failure | 🔄 Retry with error context |
| **TIMEOUT** | Hanging process, infinite loop | ⏱️ Increase timeout or fix logic |
| **UNKNOWN** | Unclassified | 🔍 Manual review |

**Example output:**
```json
{
  "errorType": "CODE",
  "reason": "TypeError at file.ts:42",
  "suggestion": "Check variable initialization",
  "details": {"file": "file.ts", "line": "42"}
}
```

**Impact:** Enables debug mode with targeted fixes

#### 3. UserPromptSubmit: Auto Context (`.saci/hooks/add-context.sh`)

**Automatically injects repo context** so Claude doesn't have to search:

```markdown
## 🔍 Repository Context
- Branch: main
- Uncommitted: 3 files
- Available npm Scripts: test, build, typecheck
- Last npm error: None
- Framework: Next.js
- Language: TypeScript
```

**Impact:** Saves 1-2 tool calls per iteration

#### 4. Stop: Quality Gate (`.saci/hooks/check-if-done.py`)

**Prevents premature task completion** when tests still fail:

```bash
Claude: "Task is complete, stopping..."
Hook:   ❌ BLOCKED - Tests are still failing
        You must fix the errors before stopping.
Claude: [Continues fixing]
```

**Impact:** Ensures quality before marking tasks complete

### Safety Validations

In addition to intelligent hooks, safety checks block dangerous operations:

| Category | Examples |
|----------|----------|
| **Destructive** | `rm -rf /`, `rm -rf ~`, fork bomb |
| **Protected files** | `rm .env`, `rm .git`, `mv prp.json` |
| **Dangerous git** | `git push --force origin/main` |
| **Remote execution** | `curl \| bash`, `wget \| sh` |
| **Package managers** | `npm publish`, `npm unpublish` |
| **Database** | `DROP DATABASE`, `DELETE FROM x;` |

### 🤖 Debug Mode (Optional)

When ENVIRONMENT errors are detected, Saci can invoke a specialized subagent to auto-fix:

```bash
Iteration 1: npm run test
             → Error: npm ERR! missing script: test
             → Classified as: ENVIRONMENT
             → 🤖 Invoking environment-fixer subagent...
             → Subagent adds: "test": "echo 'No tests yet'"
             → Tests pass ✓
             → Task complete!
```

**When to use:** Enable when you want fully autonomous error recovery

**Documentation:** See `.saci/DEBUG-MODE.md` for setup instructions

### Testing Hooks

Run the test suite to validate all hooks:

```bash
# Automated tests (19 tests)
.saci/test-hooks.sh

# Integration tests (7 scenarios)
.saci/hooks-integration-test.sh

# Expected: ✓ ALL TESTS PASSED!
```

**Documentation:**
- `.saci/README.md` - Hooks overview
- `.saci/TESTING.md` - Comprehensive testing guide
- `.claude/docs/saci-analysis.md` - Complete system analysis

## Debug

### Task Management

```bash
# See pending tasks
cat prp.json | jq '.features[].tasks[] | select(.passes == false) | .title'

# See progress
cat progress.txt

# Dry jump
saci jump --dry-run

# Reset all tasks to retry
saci reset

# Reset specific task
saci reset F1-T3

# Reset task and all dependent tasks
saci reset F1-T1 --cascade

# Check task dependencies
cat prp.json | jq '.features[].tasks[] | select(.id == "F1-T3") | .dependencies'

# List tasks blocked by dependencies
cat prp.json | jq '.features[].tasks[] | select(.passes == false and (.dependencies // [] | length > 0)) | {id, title, dependencies}'

# Find all tasks that depend on a specific task
cat prp.json | jq --arg id "F1-T1" '.features[].tasks[] | select(.dependencies // [] | index($id)) | {id, title}'

# Visualize dependency graph (requires jq)
cat prp.json | jq -r '.features[].tasks[] | select((.dependencies // [] | length) > 0) | .id + " depends on: " + (.dependencies | join(", "))'
```

### Hooks Testing & Validation

```bash
# Run all hook tests (automated)
.saci/test-hooks.sh

# Run integration tests
.saci/hooks-integration-test.sh

# Test individual hooks manually
echo '{"tool_name":"Bash","tool_input":{"command":"npm run invalid"}}' | .saci/hooks/validate-bash.py
echo '{"tool_response":"npm ERR! missing script: test"}' | .saci/hooks/check-test-output.py
.saci/hooks/add-context.sh
.saci/hooks/check-if-done.py

# Check hooks configuration
cat .claude/settings.json | jq '.hooks'

# View hook execution (if verbose enabled)
tail -f ~/.claude/logs/claude-*.log
```

## References

- [Ralph (inspiration)](https://github.com/snarktank/ralph)
- [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)

## License

MIT
