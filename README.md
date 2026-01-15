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
| Interactive PRP generator | ❌ | ✅ `saci init` |
| Pattern analyzer | ❌ | ✅ `saci analyze` |
| Safety hooks | ❌ | ✅ Blocks dangerous commands |
| Global installation | ❌ | ✅ Works from any directory |
| Generates AGENTS.md | ❌ | ✅ Auto-detects context |
| Task structure | `userStories[]` flat | `features[].tasks[]` hierarchical |

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/lucianfialho/saci/main/install-remote.sh | bash
```

Now you can use `saci` from any directory!

<details>
<summary>Manual installation</summary>

```bash
git clone https://github.com/lucianfialho/saci.git
cd saci
./install.sh
```
</details>

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

```
┌─────────────────────────────────────────────────────────┐
│                    SACI LOOP                            │
├─────────────────────────────────────────────────────────┤
│  1. Get next task (passes: false)                       │
│  2. Create git checkpoint                               │
│  3. Spawn new Claude Code session (clean context)       │
│  4. Execute task + run tests                            │
│  5. If passed → commit + mark passes: true              │
│  6. If failed → git reset + save error for retry        │
│  7. Repeat until complete or max iterations             │
└─────────────────────────────────────────────────────────┘
```

### Resilience (the differentiator)

- **New session per task**: Always clean context
- **Auto rollback**: `git reset --hard` on failure
- **Error feedback**: Exact error passed to next retry
- **External memory**: `progress.txt` persists learnings

## Structure

```
saci/
├── saci.sh              # Main script
├── install.sh           # Global installer
├── lib/
│   ├── scanner.sh       # Detects stack/libs
│   ├── generator.sh     # Wizard to create PRP
│   └── analyzer.sh      # Suggests patterns
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

Saci installs a skill in Claude Code to generate PRPs:

```
> skill prp
> "I want to add a priority system"

[Saci asks questions: 1A, 2B, 3C]
> 1A, 2C, 3B

[Generates: tasks/prp-priority.md + prp.json]
```

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

## Safety Hook

Blocks dangerous commands before execution:

| Category | Examples |
|----------|----------|
| **Destructive** | `rm -rf /`, `rm -rf ~`, fork bomb |
| **Protected files** | `rm .env`, `rm .git`, `mv prp.json` |
| **Dangerous git** | `git push --force`, `git reset --hard origin/main` |
| **Remote execution** | `curl \| bash`, `wget \| sh` |
| **Package managers** | `npm publish`, `npm unpublish` |
| **Database** | `DROP DATABASE`, `DELETE FROM x;` |
| **Secrets** | `cat .env`, `echo $API_KEY` |

## Debug

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

## References

- [Ralph (inspiration)](https://github.com/snarktank/ralph)
- [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)

## License

MIT
