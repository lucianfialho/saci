#!/bin/bash
# ============================================================================
# SACI - Sistema Autônomo de Coding com Inteligência
# REAL Ralph Loop implementation - spawns NEW Claude Code sessions per task
# Based on the original Ralph Loop framework (not the Ralph Wiggum plugin)
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PRP_FILE="${PRP_FILE:-prp.json}"
PROGRESS_FILE="${PROGRESS_FILE:-progress.txt}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"
DRY_RUN="${DRY_RUN:-false}"
CLI_PROVIDER="${CLI_PROVIDER:-claude}"  # Options: claude, amp
TUI_MODE="${TUI_MODE:-false}"  # Enable TUI with gum
TUI_ENABLED="${TUI_ENABLED:-false}"  # Set by tui_init when gum is ready

# Determine PROMPT_FILE
# 1. Environment variable
# 2. Local prompt.md
# 3. Global template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${PROMPT_FILE:-}" ]; then
    # Use explicitly set PROMPT_FILE
    :
elif [ -f "prompt.md" ]; then
    PROMPT_FILE="prompt.md"
elif [ -f "$SCRIPT_DIR/templates/prompt.md" ]; then
    PROMPT_FILE="$SCRIPT_DIR/templates/prompt.md"
else
    # Fallback default
    PROMPT_FILE="prompt.md"
fi

# ============================================================================
# Helper Functions
# ============================================================================

log_info() { 
    if [ "$TUI_MODE" = "true" ] && [ "$TUI_ENABLED" = "true" ]; then
        tui_log "$1"
    else
        echo -e "${BLUE}[SACI]${NC} $1"
    fi
}
log_success() { 
    if [ "$TUI_MODE" = "true" ] && [ "$TUI_ENABLED" = "true" ]; then
        tui_log "✓ $1"
    else
        echo -e "${GREEN}[✓]${NC} $1"
    fi
}
log_warning() { 
    if [ "$TUI_MODE" = "true" ] && [ "$TUI_ENABLED" = "true" ]; then
        tui_log "⚠ $1"
    else
        echo -e "${YELLOW}[!]${NC} $1"
    fi
}
log_error() { 
    if [ "$TUI_MODE" = "true" ] && [ "$TUI_ENABLED" = "true" ]; then
        tui_log "✗ $1"
    else
        echo -e "${RED}[✗]${NC} $1"
    fi
}
log_iteration() { 
    if [ "$TUI_MODE" = "true" ] && [ "$TUI_ENABLED" = "true" ]; then
        tui_log "→ $1"
    else
        echo -e "${CYAN}[ITER]${NC} $1"
    fi
}

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_progress() {
    local task_id="$1"
    local status="$2"
    local message="$3"
    local tokens="${4:-0}"        # Optional: tokens used
    local cost_usd="${5:-0.00}"   # Optional: cost in USD

    echo "" >> "$PROGRESS_FILE"
    echo "## [$(timestamp)] Task $task_id - $status" >> "$PROGRESS_FILE"

    # Add metrics if available (tokens != 0)
    if [ "$tokens" != "0" ] && [ "$tokens" != "N/A" ]; then
        echo "**Tokens:** $tokens (\$$cost_usd USD)" >> "$PROGRESS_FILE"
    fi

    echo "$message" >> "$PROGRESS_FILE"
}

# ============================================================================
# PRP Functions
# ============================================================================

check_dependencies() {
    local missing=()
    
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    # Check for selected CLI provider
    case "$CLI_PROVIDER" in
        claude)
            command -v claude >/dev/null 2>&1 || missing+=("claude (npm install -g @anthropic-ai/claude-code)")
            ;;
        amp)
            command -v amp >/dev/null 2>&1 || missing+=("amp (https://ampcode.com)")
            ;;
        *)
            log_error "Unknown CLI provider: $CLI_PROVIDER. Valid options: claude, amp"
            exit 1
            ;;
    esac
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

get_next_task() {
    # Find first task with passes: false that has all dependencies satisfied
    # Get all candidate tasks sorted by priority
    local candidates=$(jq -r '
        [.features[] | .tasks[] | select(.passes == false)]
        | sort_by(.priority)
        | .[]
        | .id
    ' "$PRP_FILE")

    # If no candidates, return empty
    if [ -z "$candidates" ]; then
        return 0
    fi

    # Iterate through candidates and return first one with satisfied dependencies
    while IFS= read -r task_id; do
        [ -z "$task_id" ] && continue

        # Check if dependencies are met
        if check_dependencies_met "$task_id"; then
            echo "$task_id"
            return 0
        fi
    done <<< "$candidates"

    # No tasks with satisfied dependencies found
    return 0
}

get_task_field() {
    local task_id="$1"
    local field="$2"
    jq -r --arg id "$task_id" '.features[].tasks[] | select(.id == $id) | .'"$field" "$PRP_FILE"
}

get_task_context() {
    local task_id="$1"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) | .context | 
        "Files: \(.files // [] | join(", "))\n" +
        "Libraries: \(.libraries // [] | join(", "))\n" +
        "Hints:\n\(.hints // [] | map("- " + .) | join("\n"))"
    ' "$PRP_FILE"
}

get_acceptance_criteria() {
    local task_id="$1"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) | 
        .acceptance // [] | map("- " + .) | join("\n")
    ' "$PRP_FILE"
}

get_test_command() {
    local task_id="$1"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) | 
        .tests.command // "npm test"
    ' "$PRP_FILE"
}

mark_task_complete() {
    local task_id="$1"
    local tmp_file=$(mktemp)
    
    jq --arg id "$task_id" '
        .features |= map(.tasks |= map(if .id == $id then .passes = true else . end))
    ' "$PRP_FILE" > "$tmp_file" && mv "$tmp_file" "$PRP_FILE"
}

count_remaining_tasks() {
    jq '[.features[].tasks[] | select(.passes == false)] | length' "$PRP_FILE"
}

count_total_tasks() {
    jq '[.features[].tasks[]] | length' "$PRP_FILE"
}

get_feature_for_task() {
    local task_id="$1"
    jq -r --arg id "$task_id" '
        .features[] | select(.tasks[] | .id == $id) | .name
    ' "$PRP_FILE"
}

# ============================================================================
# Dependency Helper Functions
# ============================================================================

get_task_dependencies() {
    local task_id="$1"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .dependencies // [] | .[]
    ' "$PRP_FILE"
}

get_dependency_mode() {
    local task_id="$1"
    jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .dependencyMode // "all"
    ' "$PRP_FILE"
}

check_dependencies_met() {
    local task_id="$1"
    local mode=$(get_dependency_mode "$task_id")
    local dependencies=$(get_task_dependencies "$task_id")

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
        ' "$PRP_FILE")

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

get_blocked_dependencies() {
    local task_id="$1"
    local dependencies=$(get_task_dependencies "$task_id")

    # If no dependencies, return empty
    if [ -z "$dependencies" ]; then
        return 0
    fi

    local blocked=""

    while IFS= read -r dep_id; do
        [ -z "$dep_id" ] && continue

        # Check if dependency task passes
        local dep_passes=$(jq -r --arg id "$dep_id" '
            .features[].tasks[] | select(.id == $id) | .passes // false
        ' "$PRP_FILE")

        if [ "$dep_passes" != "true" ]; then
            if [ -z "$blocked" ]; then
                blocked="$dep_id"
            else
                blocked="$blocked $dep_id"
            fi
        fi
    done <<< "$dependencies"

    echo "$blocked"
}

# ============================================================================
# PRP Completion Check
# ============================================================================

check_prp_complete() {
    local total_tasks=$(jq '[.features[].tasks[]] | length' "$PRP_FILE")
    local completed_tasks=$(jq '[.features[].tasks[] | select(.passes == true)] | length' "$PRP_FILE")

    if [ "$completed_tasks" -eq "$total_tasks" ] && [ "$total_tasks" -gt 0 ]; then
        return 0  # Complete
    else
        return 1  # Not complete
    fi
}

# ============================================================================
# Circular Dependency Detection
# ============================================================================

detect_circular_dependency() {
    local task_id="$1"
    local path="${2:-}"  # Current path for cycle detection
    local visited="${3:-}"  # Space-separated list of visited nodes

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
    local dependencies=$(get_task_dependencies "$task_id")

    # If no dependencies, no cycle from this path
    if [ -z "$dependencies" ]; then
        return 0
    fi

    # Check each dependency recursively
    while IFS= read -r dep_id; do
        [ -z "$dep_id" ] && continue

        # Recursively check this dependency
        local cycle_path
        if ! cycle_path=$(detect_circular_dependency "$dep_id" "$path" "$visited"); then
            # Cycle detected in recursive call
            echo "$cycle_path"
            return 1
        fi
    done <<< "$dependencies"

    # No cycle found from this task
    return 0
}

validate_dependencies() {
    local prp_file="${1:-$PRP_FILE}"

    log_info "Validating task dependencies..."

    # Get all task IDs for existence checking
    local all_task_ids=$(jq -r '.features[].tasks[].id' "$prp_file")
    local has_errors=0

    # Get all tasks with dependencies
    local tasks_with_deps=$(jq -r '
        .features[].tasks[] |
        select(.dependencies != null and (.dependencies | length) > 0) |
        .id
    ' "$prp_file")

    # If no tasks have dependencies, nothing to validate
    if [ -z "$tasks_with_deps" ]; then
        log_success "No task dependencies to validate"
        return 0
    fi

    # Validate each task with dependencies
    while IFS= read -r task_id; do
        [ -z "$task_id" ] && continue

        # Get dependencies for this task
        local dependencies=$(jq -r --arg id "$task_id" '
            .features[].tasks[] | select(.id == $id) |
            .dependencies // [] | .[]
        ' "$prp_file")

        # Validate dependency IDs reference existing tasks
        while IFS= read -r dep_id; do
            [ -z "$dep_id" ] && continue

            # Check if dependency exists
            if ! echo "$all_task_ids" | grep -qx "$dep_id"; then
                log_error "Task $task_id: Invalid dependency reference '$dep_id' (task does not exist)"
                has_errors=1
            fi
        done <<< "$dependencies"

        # Validate dependencyMode if present
        local dep_mode=$(jq -r --arg id "$task_id" '
            .features[].tasks[] | select(.id == $id) |
            .dependencyMode // "null"
        ' "$prp_file")

        if [ "$dep_mode" != "null" ] && [ "$dep_mode" != "all" ] && [ "$dep_mode" != "any" ]; then
            log_error "Task $task_id: Invalid dependencyMode '$dep_mode' (must be 'all' or 'any')"
            has_errors=1
        fi

        # Check for circular dependencies
        local cycle_path
        if ! cycle_path=$(detect_circular_dependency "$task_id" "" ""); then
            log_error "Circular dependency detected!"
            log_error "Cycle path: $cycle_path"
            has_errors=1
        fi
    done <<< "$tasks_with_deps"

    # Return with error if any validation failed
    if [ $has_errors -eq 1 ]; then
        return 1
    fi

    log_success "All task dependencies are valid"
    return 0
}

# ============================================================================
# Prompt Builder
# ============================================================================

# Detect task domain based on context hints (files, libraries, description)
detect_task_domain() {
    local task_id="$1"

    # Get files and libraries from task context
    local files=$(jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .context.files // [] | join(" ")
    ' "$PRP_FILE" 2>/dev/null || echo "")

    local libraries=$(jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .context.libraries // [] | join(" ")
    ' "$PRP_FILE" 2>/dev/null || echo "")

    local description=$(get_task_field "$task_id" "description")

    local hints=$(jq -r --arg id "$task_id" '
        .features[].tasks[] | select(.id == $id) |
        .context.hints // [] | join(" ")
    ' "$PRP_FILE" 2>/dev/null || echo "")

    # Combine all context for domain detection
    local combined="$files $libraries $description $hints"

    # Frontend detection
    if echo "$combined" | grep -qiE "(react|component|tsx|jsx|css|ui|frontend|tailwind|styled|vue|angular|svelte)"; then
        echo "frontend"
        return
    fi

    # Backend detection
    if echo "$combined" | grep -qiE "(api|database|server|endpoint|migration|prisma|sql|postgres|mysql|mongodb|express|fastify)"; then
        echo "backend"
        return
    fi

    # DevOps detection
    if echo "$combined" | grep -qiE "(deploy|ci|cd|docker|kubernetes|infra|github.*action|workflow|terraform|aws|gcp|azure)"; then
        echo "devops"
        return
    fi

    # Testing detection
    if echo "$combined" | grep -qiE "(test|spec|jest|vitest|playwright|cypress|mocha|testing)"; then
        echo "testing"
        return
    fi

    # Documentation detection
    if echo "$combined" | grep -qiE "(readme|docs|documentation|\.md|guide|tutorial)"; then
        echo "documentation"
        return
    fi

    # Default to generic
    echo "generic"
}

# Detect task type based on title and description
detect_task_type() {
    local task_id="$1"
    local title=$(get_task_field "$task_id" "title")
    local description=$(get_task_field "$task_id" "description")

    # Combine for analysis
    local combined="$title $description"

    # Bug fix detection
    if echo "$combined" | grep -qiE "(fix|bug|issue|error|crash|broken|resolve)"; then
        echo "bugfix"
        return
    fi

    # Refactor detection
    if echo "$combined" | grep -qiE "(refactor|cleanup|improve|optimize|reorganize|restructure)"; then
        echo "refactor"
        return
    fi

    # Default to feature
    echo "feature"
}

build_task_prompt() {
    local task_id="$1"
    local iteration="$2"
    local previous_error="${3:-}"  # Error from previous iteration
    local title=$(get_task_field "$task_id" "title")
    local description=$(get_task_field "$task_id" "description")
    local context=$(get_task_context "$task_id")
    local acceptance=$(get_acceptance_criteria "$task_id")
    local test_cmd=$(get_test_command "$task_id")

    # ================================================================
    # NEW: Smart template selection based on domain and task type
    # ================================================================
    local domain=$(detect_task_domain "$task_id")
    local task_type=$(detect_task_type "$task_id")

    # Build PRP template paths
    local prp_base="$SCRIPT_DIR/templates/prp/base.md"
    local prp_domain="$SCRIPT_DIR/templates/prp/domains/${domain}.md"
    local prp_task_type="$SCRIPT_DIR/templates/prp/task-types/${task_type}.md"

    # Assemble PRP layers
    local prp_template=""

    # Layer 1: Base (System + Interaction + Response)
    if [ -f "$prp_base" ]; then
        prp_template+=$(cat "$prp_base")
        prp_template+=$'\n\n---\n\n'
    fi

    # Layer 2: Domain-specific context
    if [ -f "$prp_domain" ]; then
        prp_template+=$(cat "$prp_domain")
        prp_template+=$'\n\n---\n\n'
    fi

    # Layer 3: Task type context
    if [ -f "$prp_task_type" ]; then
        prp_template+=$(cat "$prp_task_type")
        prp_template+=$'\n\n---\n\n'
    fi

    # Fallback to legacy prompt.md if PRP templates don't exist
    if [ -z "$prp_template" ] && [ -f "$PROMPT_FILE" ]; then
        prp_template=$(cat "$PROMPT_FILE")
        prp_template+=$'\n\n---\n\n'
    fi

    # ================================================================
    # Task-specific context (from prp.json)
    # ================================================================
    local task_context="# Current Task: $title

**Task ID:** $task_id
**Iteration:** $iteration of $MAX_ITERATIONS
**Domain:** $domain
**Type:** $task_type

## Available Skills
- **prp**: For planning new features - generates spec document + prp.json.

Refer to guidelines in default.md for implementation and debugging best practices.

## Description
$description

## Context
$context

## Acceptance Criteria
$acceptance

## Test Command
\`$test_cmd\`"

    # ================================================================
    # Historical context (progress.txt + errors)
    # ================================================================
    local progress_context=""
    if [ -f "$PROGRESS_FILE" ] && [ -s "$PROGRESS_FILE" ]; then
        progress_context=$(tail -100 "$PROGRESS_FILE")
    fi

    local error_section=""
    if [ -n "$previous_error" ]; then
        error_section="
---

## ⚠️ PREVIOUS ITERATION FAILED

The last attempt failed with this error:

\`\`\`
$previous_error
\`\`\`

**CRITICAL:** You MUST try a DIFFERENT approach. The previous approach did not work.
Analyze the error above and fix the root cause, don't just retry the same thing.
"
    fi

    # ================================================================
    # Assemble final prompt
    # ================================================================
    cat <<EOF
$prp_template
$task_context
$error_section
---

## Previous Progress & Learnings
$progress_context

---

## Instructions

1. Read the previous progress above to understand what has been tried before
2. Implement the task following the context hints and domain-specific guidelines
3. Run the test command: \`$test_cmd\`
4. If tests pass, commit with: "feat: $title [task-$task_id]"
5. If tests fail, document what you tried and the errors

**IMPORTANT:**
- This is iteration $iteration. If previous attempts failed, try a DIFFERENT approach.
- Focus on completing ALL acceptance criteria.
- Follow domain-specific best practices and patterns.

Start implementing now.
EOF
}

# ============================================================================
# Core Loop - NEW SESSION per iteration (Real Ralph Loop)
# Enhanced with: error capture, git rollback, smarter retries
# ============================================================================

# Global to store last error for next iteration
LAST_ERROR=""
LAST_APPROACH=""

# ============================================================================
# Token Tracking and Metrics Functions
# ============================================================================

# Extract tokens and cost from CLI output (JSON format)
# Returns: input_tokens,output_tokens,total_tokens,model,cost_usd
extract_tokens_from_output() {
    local output_file="$1"

    # Check if file exists and is not empty
    if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
        echo "0,0,0,unknown,0.000000"
        return
    fi

    # Claude CLI with --output-format json outputs a JSON array
    # Find the result object (object with type:"result")
    local input_tokens=$(jq -r '.[] | select(.type == "result") | .usage.input_tokens // 0' "$output_file" 2>/dev/null || echo "0")
    local output_tokens=$(jq -r '.[] | select(.type == "result") | .usage.output_tokens // 0' "$output_file" 2>/dev/null || echo "0")
    local total_tokens=$((input_tokens + output_tokens))

    # Extract model from modelUsage (first model key)
    local model=$(jq -r '.[] | select(.type == "result") | .modelUsage | keys[0] // "unknown"' "$output_file" 2>/dev/null || echo "unknown")

    # Extract cost (Claude CLI calculates this for us)
    local cost_usd=$(jq -r '.[] | select(.type == "result") | .total_cost_usd // 0' "$output_file" 2>/dev/null || echo "0")

    echo "$input_tokens,$output_tokens,$total_tokens,$model,$cost_usd"
}

# Calculate cost in USD based on Claude pricing (as of 2026-01-16)
# Pricing: https://www.anthropic.com/pricing
calculate_cost() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"

    # Skip if no tokens
    if [ "$input_tokens" = "0" ] && [ "$output_tokens" = "0" ]; then
        echo "0.000000"
        return
    fi

    # Claude pricing per million tokens
    local input_cost output_cost
    case "$model" in
        *"opus"*)
            # Opus: $15/MTok input, $75/MTok output
            input_cost=$(echo "scale=6; $input_tokens * 15 / 1000000" | bc)
            output_cost=$(echo "scale=6; $output_tokens * 75 / 1000000" | bc)
            ;;
        *"haiku"*)
            # Haiku: $0.25/MTok input, $1.25/MTok output
            input_cost=$(echo "scale=6; $input_tokens * 0.25 / 1000000" | bc)
            output_cost=$(echo "scale=6; $output_tokens * 1.25 / 1000000" | bc)
            ;;
        *"sonnet"*|*)
            # Sonnet (default): $3/MTok input, $15/MTok output
            input_cost=$(echo "scale=6; $input_tokens * 3 / 1000000" | bc)
            output_cost=$(echo "scale=6; $output_tokens * 15 / 1000000" | bc)
            ;;
    esac

    echo "scale=6; $input_cost + $output_cost" | bc
}

# Log metrics to .saci/metrics.jsonl
log_metrics() {
    local task_id="$1"
    local iteration="$2"
    local input_tokens="$3"
    local output_tokens="$4"
    local total_tokens="$5"
    local model="$6"
    local result="$7"           # "success" or "failed"
    local duration_ms="$8"
    local error_type="${9:-}"   # ENVIRONMENT, CODE, TIMEOUT, UNKNOWN, or empty

    local timestamp=$(date -Iseconds)
    local cost_usd=$(calculate_cost "$model" "$input_tokens" "$output_tokens")

    # Ensure .saci directory exists
    mkdir -p .saci

    # Append to metrics.jsonl (one line per iteration)
    cat >> .saci/metrics.jsonl <<EOF
{"timestamp":"$timestamp","task_id":"$task_id","iteration":$iteration,"input_tokens":$input_tokens,"output_tokens":$output_tokens,"total_tokens":$total_tokens,"model":"$model","result":"$result","duration_ms":$duration_ms,"error_type":"$error_type","cost_usd":$cost_usd}
EOF
}

run_single_iteration() {
    local task_id="$1"
    local iteration="$2"
    local previous_error="${3:-}"  # Error from previous iteration
    local title=$(get_task_field "$task_id" "title")
    local test_cmd=$(get_test_command "$task_id")

    # Start time tracking
    # Milliseconds timestamp (macOS compatible)
    local start_time=$(($(date +%s) * 1000))

    log_iteration "Running iteration $iteration for task $task_id: $title"
    
    # ========================================================================
    # GIT CHECKPOINT - Save state before making changes
    # ========================================================================
    local git_checkpoint=""
    if command -v git &>/dev/null && [ -d ".git" ]; then
        git_checkpoint=$(git rev-parse HEAD 2>/dev/null || echo "")
        if [ -n "$git_checkpoint" ]; then
            log_info "Git checkpoint: ${git_checkpoint:0:7}"
        fi
    fi
    
    # Build the prompt for this iteration (with error context if available)
    local prompt=$(build_task_prompt "$task_id" "$iteration" "$previous_error")
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN - Would spawn NEW Claude Code session with prompt:"
        echo "---"
        echo "$prompt" | head -40
        echo "..."
        echo "---"
        return 0
    fi
    
    # ========================================================================
    # THIS IS THE KEY DIFFERENCE FROM RALPH WIGGUM PLUGIN
    # We spawn a COMPLETELY NEW Claude Code session for each iteration
    # This gives us a fresh context window every time!
    # ========================================================================
    
    # Create a temporary file with the prompt
    local prompt_file=$(mktemp)
    echo "$prompt" > "$prompt_file"
    
    log_info "Spawning NEW $CLI_PROVIDER session (fresh context window)..."
    
    # Capture output for potential debugging
    local cli_output_file=$(mktemp)
    
    # Build the CLI command based on provider
    local cli_cmd
    case "$CLI_PROVIDER" in
        claude)
            # --print: non-interactive mode
            # --dangerously-skip-permissions: auto-approve all actions (required for autonomous execution)
            # --output-format json: Get structured output with token metadata
            # --verbose: Detailed logging for debugging
            # --max-turns: Fail-safe against runaway loops
            cli_cmd="claude --print --dangerously-skip-permissions --output-format json --verbose --max-turns $MAX_ITERATIONS"
            ;;
        amp)
            cli_cmd="amp --print --dangerously-skip-permissions"
            ;;
    esac
    
    # Run CLI with the prompt - this starts a NEW session
    if cat "$prompt_file" | $cli_cmd 2>&1 | tee "$cli_output_file"; then
        rm -f "$prompt_file"

        # ================================================================
        # EXTRACT TOKENS FROM OUTPUT
        # ================================================================
        local end_time=$(($(date +%s) * 1000))
        local duration_ms=$((end_time - start_time))

        # Parse tokens and cost from CLI output
        IFS=',' read -r input_tokens output_tokens total_tokens model cost_usd <<< "$(extract_tokens_from_output "$cli_output_file")"

        # Fallback to calculate_cost if cost not available from CLI
        if [ "$cost_usd" = "0" ] || [ "$cost_usd" = "0.000000" ]; then
            cost_usd=$(calculate_cost "$model" "$input_tokens" "$output_tokens")
        fi

        # Log token info
        if [ "$total_tokens" != "0" ]; then
            log_info "Tokens: $total_tokens ($input_tokens in, $output_tokens out) - \$$cost_usd USD"
        fi

        # ================================================================
        # CHECK IF ANY FILES WERE ACTUALLY MODIFIED
        # ================================================================
        local changed_files=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$changed_files" -eq 0 ]; then
            # Check if task was already marked as complete (AI may have updated prp.json)
            local task_status=$(jq -r --arg id "$task_id" '.features[].tasks[] | select(.id == $id) | .passes' "$PRP_FILE")
            if [ "$task_status" = "true" ]; then
                log_success "Task already marked as complete - skipping to next"

                # Log metrics for this (already complete) iteration
                log_metrics "$task_id" "$iteration" "$input_tokens" "$output_tokens" \
                    "$total_tokens" "$model" "success" "$duration_ms" ""

                rm -f "$cli_output_file"
                return 0
            fi

            log_warning "No files were modified - AI did not make any changes"
            LAST_ERROR="No files were modified. The AI session completed but did not create or edit any files. Please ensure you actually create/modify the required files."

            # Log metrics for failed iteration (CODE error - didn't implement)
            log_metrics "$task_id" "$iteration" "$input_tokens" "$output_tokens" \
                "$total_tokens" "$model" "failed" "$duration_ms" "CODE"

            rm -f "$cli_output_file"
            return 1
        fi
        log_info "Files modified: $changed_files"
        
        # Run tests and CAPTURE the output
        log_info "Running tests: $test_cmd"
        local test_output_file=$(mktemp)
        
        if eval "$test_cmd" 2>&1 | tee "$test_output_file"; then
            # Tests passed!
            log_success "Tests passed!"
            rm -f "$test_output_file" "$cli_output_file"

            # Log metrics for successful iteration
            log_metrics "$task_id" "$iteration" "$input_tokens" "$output_tokens" \
                "$total_tokens" "$model" "success" "$duration_ms" ""

            # Commit changes
            git add -A 2>/dev/null || true
            git commit -m "$(cat <<EOF
feat: $title [task-$task_id]

Co-Authored-By: Saci <noreply@saci.sh>
EOF
)" 2>/dev/null || true

            # Mark task complete
            mark_task_complete "$task_id"

            # Check if all tasks are now complete
            if check_prp_complete; then
                log_success "🎉 All tasks in PRP complete!"
                log_info "Create new PRP for next feature or reset this one"
            fi

            # Clear error state
            LAST_ERROR=""
            LAST_APPROACH=""

            # Log success to progress with metrics
            log_progress "$task_id" "✅ COMPLETED" "
**Iteration:** $iteration
**Result:** All tests passed
**Commit:** feat: $title [task-$task_id]
" "$total_tokens" "$cost_usd"
            return 0
        else
            # ================================================================
            # TESTS FAILED - Capture specific error for next iteration
            # ================================================================
            local test_output=$(cat "$test_output_file" | tail -50)
            rm -f "$test_output_file"

            log_warning "Tests failed on iteration $iteration"

            # Log metrics for failed iteration
            log_metrics "$task_id" "$iteration" "$input_tokens" "$output_tokens" \
                "$total_tokens" "$model" "failed" "$duration_ms" "CODE"

            # Store error for next iteration
            LAST_ERROR="$test_output"

            # ================================================================
            # GIT ROLLBACK - Revert changes to clean state
            # ================================================================
            if [ -n "$git_checkpoint" ]; then
                log_info "Rolling back to checkpoint ${git_checkpoint:0:7}..."
                git reset --hard "$git_checkpoint" 2>/dev/null || true
                git clean -fd -e prp.json -e progress.txt 2>/dev/null || true
                log_success "Rollback complete"
            fi

            # Log detailed error to progress with metrics
            log_progress "$task_id" "⚠️ TESTS FAILED" "
**Iteration:** $iteration
**Test Command:** $test_cmd
**Error Output:**
\`\`\`
$test_output
\`\`\`
**Action:** Rolled back changes, will retry with error context
" "$total_tokens" "$cost_usd"
            rm -f "$cli_output_file"
            return 1
        fi
    else
        rm -f "$prompt_file"
        log_error "$CLI_PROVIDER session failed"

        # Calculate duration even on failure
        local end_time=$(($(date +%s) * 1000))
        local duration_ms=$((end_time - start_time))

        # Try to extract tokens and cost (may be partial or unavailable)
        IFS=',' read -r input_tokens output_tokens total_tokens model cost_usd <<< "$(extract_tokens_from_output "$cli_output_file")"

        # Fallback to calculate_cost if cost not available from CLI
        if [ "$cost_usd" = "0" ] || [ "$cost_usd" = "0.000000" ]; then
            cost_usd=$(calculate_cost "$model" "$input_tokens" "$output_tokens")
        fi

        rm -f "$cli_output_file"

        # ================================================================
        # CHECK IF USEFUL WORK WAS DONE BEFORE FAILURE
        # ================================================================
        local changed_files=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

        if [ "$changed_files" -gt 0 ]; then
            # Files were modified before the session failed
            # This could be due to API errors, timeouts, or network issues
            # PRESERVE the changes and let the next iteration decide what to do
            log_warning "Session failed but $changed_files file(s) were modified - preserving changes for retry"
            LAST_ERROR="Claude Code session failed (possibly API error), but changes were preserved. Review the changes and retry."

            # Log metrics for failed session (ENVIRONMENT error type since it's likely API/network)
            log_metrics "$task_id" "$iteration" "$input_tokens" "$output_tokens" \
                "$total_tokens" "$model" "failed" "$duration_ms" "ENVIRONMENT"

            log_progress "$task_id" "⚠️ SESSION FAILED (CHANGES PRESERVED)" "
**Iteration:** $iteration
**Result:** Claude Code session encountered an error
**Files Modified:** $changed_files
**Action:** Changes preserved, will retry with existing work
" "$total_tokens" "$cost_usd"
        else
            # No changes were made AND session failed - safe to rollback
            log_warning "Session failed with no changes made - rolling back to clean state"
            if [ -n "$git_checkpoint" ]; then
                log_info "Rolling back to checkpoint ${git_checkpoint:0:7}..."
                git reset --hard "$git_checkpoint" 2>/dev/null || true
                git clean -fd -e prp.json -e progress.txt 2>/dev/null || true
            fi
            LAST_ERROR="Claude Code session failed with no changes. This may indicate a prompt issue or API problem."

            # Log metrics for failed session
            log_metrics "$task_id" "$iteration" "$input_tokens" "$output_tokens" \
                "$total_tokens" "$model" "failed" "$duration_ms" "ENVIRONMENT"

            log_progress "$task_id" "❌ SESSION FAILED (ROLLED BACK)" "
**Iteration:** $iteration
**Result:** Claude Code session encountered an error
**Action:** Rolled back to clean state, will retry
" "$total_tokens" "$cost_usd"
        fi

        return 1
    fi
}

execute_task_with_retries() {
    local task_id="$1"
    local title=$(get_task_field "$task_id" "title")
    
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Starting task $task_id: $title"
    log_info "Max iterations: $MAX_ITERATIONS"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local iteration=1
    
    while [ $iteration -le $MAX_ITERATIONS ]; do
        log_info ""
        log_iteration "━━━ Iteration $iteration of $MAX_ITERATIONS ━━━"
        
        # Pass LAST_ERROR to the iteration
        if run_single_iteration "$task_id" "$iteration" "$LAST_ERROR"; then
            log_success "Task $task_id completed on iteration $iteration!"
            return 0
        fi
        
        iteration=$((iteration + 1))
        
        if [ $iteration -le $MAX_ITERATIONS ]; then
            log_info "Starting new iteration with fresh context window..."
            sleep 2  # Brief pause between iterations
        fi
    done
    
    log_error "Task $task_id failed after $MAX_ITERATIONS iterations"
    log_progress "$task_id" "❌ MAX ITERATIONS REACHED" "
**Iterations Attempted:** $MAX_ITERATIONS
**Result:** Could not complete task within iteration limit
**Recommendation:** Review the task requirements and try again
"
    return 1
}

# ============================================================================
# Main Loop
# ============================================================================

main() {
    # Parse arguments first (before any output)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true; shift ;;
            --tui) TUI_MODE=true; shift ;;
            --prp) PRP_FILE="$2"; shift 2 ;;
            --max-iter) MAX_ITERATIONS="$2"; shift 2 ;;
            --provider) CLI_PROVIDER="$2"; shift 2 ;;
            --help) 
                echo "Usage: saci.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run        Show what would be done without executing"
                echo "  --tui            Enable visual TUI mode (requires gum)"
                echo "  --prp FILE       Use specified PRP file (default: prp.json)"
                echo "  --max-iter N     Max iterations per task (default: 10)"
                echo "  --provider NAME  CLI provider: claude or amp (default: claude)"
                echo "  --help           Show this help"
                exit 0
                ;;
            *) shift ;;
        esac
    done
    
    # Initialize TUI if enabled
    if [ "$TUI_MODE" = "true" ]; then
        source "$SCRIPT_DIR/lib/tui.sh"
        if check_gum; then
            tui_init
        else
            TUI_MODE=false
            echo "Falling back to standard output..."
        fi
    fi
    
    # Show header (unless TUI mode)
    if [ "$TUI_MODE" != "true" ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  🔥 SACI - Sistema Autônomo de Coding${NC}"
        echo -e "${CYAN}  Real Ralph Loop Implementation${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi
    
    # Check dependencies
    check_dependencies
    
    # Check required files
    if [ ! -f "$PRP_FILE" ]; then
        log_error "PRP file not found: $PRP_FILE"
        log_info "Create a prp.json file or specify with --prp"
        exit 1
    fi

    # Validate dependencies (detect circular dependencies)
    if ! validate_dependencies "$PRP_FILE"; then
        log_error "Dependency validation failed. Please fix circular dependencies before running."
        exit 1
    fi

    # Initialize progress file
    if [ ! -f "$PROGRESS_FILE" ]; then
        cat > "$PROGRESS_FILE" <<EOF
# Saci Progress Log
# Started: $(timestamp)
# 
# This file maintains context between sessions.
# Each iteration reads this to learn from previous attempts.

EOF
    fi
    
    # Show initial status
    local total=$(count_total_tasks)
    local remaining=$(count_remaining_tasks)
    log_info "Total tasks: $total"
    log_info "Remaining: $remaining"
    log_info "Max iterations per task: $MAX_ITERATIONS"
    echo ""

    # Check if all tasks are already complete
    if check_prp_complete; then
        log_success "🎉 All tasks complete!"
        echo ""
        echo "Next steps:"
        echo "  • Create new PRP: claude /prp  OR  saci init"
        echo "  • Reset tasks: saci reset"
        echo "  • Review: cat progress.txt"
        echo ""
        exit 0
    fi

    # Main loop - process each task
    local task_id
    local completed=0
    local failed=0
    
    while task_id=$(get_next_task) && [ -n "$task_id" ]; do
        remaining=$(count_remaining_tasks)
        
        # Render TUI if enabled
        if [ "$TUI_MODE" = "true" ]; then
            tui_render "$PRP_FILE" "$task_id" "running"
        else
            log_info "📋 Tasks remaining: $remaining"
        fi
        
        if [ "$DRY_RUN" = "true" ]; then
            # In dry-run, just show what would happen and mark complete
            run_single_iteration "$task_id" "1"
            mark_task_complete "$task_id"
            completed=$((completed + 1))
        else
            if execute_task_with_retries "$task_id"; then
                completed=$((completed + 1))
                [ "$TUI_MODE" = "true" ] && tui_render "$PRP_FILE" "$task_id" "success"
            else
                failed=$((failed + 1))
                [ "$TUI_MODE" = "true" ] && tui_render "$PRP_FILE" "$task_id" "failed"
                log_warning "Skipping failed task, moving to next..."
            fi
        fi
        
        [ "$TUI_MODE" != "true" ] && echo ""
    done
    
    # Final summary
    if [ "$TUI_MODE" = "true" ]; then
        tui_render "$PRP_FILE" "" "complete"
        tui_cleanup
    else
        echo ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_success "🎉 Saci run complete!"
        log_info "Completed: $completed tasks"
        if [ $failed -gt 0 ]; then
            log_warning "Failed: $failed tasks"
        fi
        log_info "Progress log: $PROGRESS_FILE"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
}

# ============================================================================
# Subcommand Routing
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_dependent_tasks() {
    # Find all tasks that depend on the given task_id
    local target_id="$1"
    jq -r --arg id "$target_id" '
        .features[].tasks[] |
        select(.dependencies // [] | index($id)) |
        .id
    ' "$PRP_FILE"
}

reset_task_cascade() {
    # Recursively reset a task and all its dependents
    local task_id="$1"
    local reset_list="${2:-}"  # Space-separated list of already reset tasks

    # Check if already reset to avoid infinite loops
    if echo " $reset_list " | grep -q " $task_id "; then
        return 0
    fi

    # Reset this task
    local tmp_file=$(mktemp)
    jq --arg id "$task_id" '
        .features |= map(.tasks |= map(if .id == $id then .passes = false else . end))
    ' "$PRP_FILE" > "$tmp_file" && mv "$tmp_file" "$PRP_FILE"

    # Add to reset list
    reset_list="$reset_list $task_id"

    # Find all tasks that depend on this task
    local dependents=$(get_dependent_tasks "$task_id")

    # Recursively reset each dependent
    if [ -n "$dependents" ]; then
        while IFS= read -r dep_task; do
            [ -z "$dep_task" ] && continue
            reset_list=$(reset_task_cascade "$dep_task" "$reset_list")
        done <<< "$dependents"
    fi

    echo "$reset_list"
}

run_reset() {
    local prp_file="${PRP_FILE:-prp.json}"
    local task_id="${1:-}"
    local cascade_flag="${2:-}"

    if [ ! -f "$prp_file" ]; then
        log_error "PRP file not found: $prp_file"
        exit 1
    fi

    if [ -n "$task_id" ]; then
        # Reset specific task
        if [ "$cascade_flag" = "--cascade" ]; then
            # Reset with cascade
            log_info "Resetting $task_id and all dependent tasks..."
            local reset_list=$(reset_task_cascade "$task_id" "")

            # Count and display reset tasks
            local reset_count=0
            local task_names=""
            for tid in $reset_list; do
                [ -z "$tid" ] && continue
                reset_count=$((reset_count + 1))
                if [ -z "$task_names" ]; then
                    task_names="$tid"
                else
                    task_names="$task_names, $tid"
                fi
            done

            log_success "Reset $reset_count task(s) in cascade: $task_names"
        else
            # Reset single task (backward compatible)
            local tmp_file=$(mktemp)
            jq --arg id "$task_id" '
                .features |= map(.tasks |= map(if .id == $id then .passes = false else . end))
            ' "$prp_file" > "$tmp_file" && mv "$tmp_file" "$prp_file"
            log_success "Reset task $task_id to passes: false"
        fi
    else
        # Reset all tasks
        local tmp_file=$(mktemp)
        jq '.features |= map(.tasks |= map(.passes = false))' "$prp_file" > "$tmp_file" && mv "$tmp_file" "$prp_file"
        local count=$(jq '[.features[].tasks[]] | length' "$prp_file")
        log_success "Reset all $count tasks to passes: false"
    fi

    # Also clear progress file
    if [ -f "$PROGRESS_FILE" ]; then
        echo "# Progress reset at $(timestamp)" > "$PROGRESS_FILE"
        log_info "Cleared progress.txt"
    fi
}

validate_task_structure() {
    local prp_file="$1"
    local has_errors=0

    log_info "Validating task structure and uniqueness..."

    # Required task fields
    local required_fields=("id" "title" "description" "priority" "passes" "context" "acceptance" "tests")

    # Collect all task IDs to check for duplicates
    local all_task_ids=$(jq -r '.features[].tasks[].id' "$prp_file" 2>/dev/null)
    local duplicate_ids=$(echo "$all_task_ids" | sort | uniq -d)

    if [ -n "$duplicate_ids" ]; then
        log_error "Duplicate task IDs found:"
        while IFS= read -r dup_id; do
            [ -z "$dup_id" ] && continue
            echo -e "  ${RED}✗${NC} Duplicate ID: $dup_id"
            has_errors=1
        done <<< "$duplicate_ids"
    fi

    # Validate each task's required fields
    local task_count=0
    while IFS= read -r task_id; do
        [ -z "$task_id" ] && continue
        task_count=$((task_count + 1))

        # Validate ID format (F[num]-T[num])
        if ! echo "$task_id" | grep -qE '^F[0-9]+-T[0-9]+$'; then
            log_error "Task $task_id: Invalid ID format (must match F[num]-T[num])"
            has_errors=1
        fi

        # Get task data as JSON object for validation
        local task_json=$(jq --arg id "$task_id" '[.features[].tasks[] | select(.id == $id)] | .[0]' "$prp_file")

        # Check each required field
        for field in "${required_fields[@]}"; do
            if ! echo "$task_json" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
                log_error "Task $task_id: Missing required field '$field'"
                has_errors=1
            fi
        done

        # Validate priority is a number
        local priority=$(echo "$task_json" | jq -r '.priority // "null"')
        if [ "$priority" = "null" ] || ! echo "$priority" | grep -qE '^[0-9]+$'; then
            log_error "Task $task_id: Field 'priority' must be a number"
            has_errors=1
        fi

        # Validate passes is boolean
        local passes=$(echo "$task_json" | jq -r '.passes // "null"')
        if [ "$passes" != "true" ] && [ "$passes" != "false" ]; then
            log_error "Task $task_id: Field 'passes' must be boolean (true or false)"
            has_errors=1
        fi

        # Validate acceptance is non-empty array
        local acceptance_count=$(echo "$task_json" | jq '.acceptance | length' 2>/dev/null || echo "0")
        if [ "$acceptance_count" -eq 0 ]; then
            log_error "Task $task_id: Field 'acceptance' must be non-empty array"
            has_errors=1
        fi

        # Validate tests.command field exists
        if ! echo "$task_json" | jq -e '.tests.command' >/dev/null 2>&1; then
            log_error "Task $task_id: Missing required field 'tests.command'"
            has_errors=1
        fi
    done <<< "$all_task_ids"

    if [ $has_errors -eq 0 ]; then
        log_success "All $task_count tasks have valid structure"
        return 0
    else
        return 1
    fi
}

run_validate() {
    local prp_file="${1:-$PRP_FILE}"

    if [ ! -f "$prp_file" ]; then
        log_error "PRP file not found: $prp_file"
        return 1
    fi

    log_info "Validating PRP file: $prp_file"
    echo ""

    # Track validation results
    local validation_errors=0
    local validation_warnings=0
    local suggestions=()

    # ========================================================================
    # 1. Validate JSON syntax
    # ========================================================================
    local jq_error
    if ! jq_error=$(jq empty "$prp_file" 2>&1); then
        echo -e "${RED}[✗]${NC} JSON syntax validation"
        # Extract line number from jq error (format: "parse error: ... at line X, column Y")
        local line_num=$(echo "$jq_error" | grep -oE 'line [0-9]+' | grep -oE '[0-9]+' | head -1)
        if [ -n "$line_num" ]; then
            echo -e "    ${RED}Error at line $line_num${NC}"
        fi
        echo "    $jq_error"
        suggestions+=("Fix JSON syntax errors before proceeding")
        validation_errors=$((validation_errors + 1))
        echo ""
        # Early exit - can't continue without valid JSON
        display_validation_summary "$prp_file" "$validation_errors" "$validation_warnings" "${suggestions[@]}"
        return 1
    else
        echo -e "${GREEN}[✓]${NC} JSON syntax validation"
    fi

    # ========================================================================
    # 2. Validate required top-level fields
    # ========================================================================
    if ! jq -e '.project' "$prp_file" >/dev/null 2>&1; then
        echo -e "${RED}[✗]${NC} Required field 'project'"
        suggestions+=("Add 'project' field with project name")
        validation_errors=$((validation_errors + 1))
    else
        echo -e "${GREEN}[✓]${NC} Required field 'project'"
    fi

    if ! jq -e '.features' "$prp_file" >/dev/null 2>&1; then
        echo -e "${RED}[✗]${NC} Required field 'features'"
        suggestions+=("Add 'features' array with at least one feature")
        validation_errors=$((validation_errors + 1))
    else
        # Verify 'features' is an array
        if ! jq -e '.features | type == "array"' "$prp_file" >/dev/null 2>&1; then
            echo -e "${RED}[✗]${NC} Field 'features' must be an array"
            suggestions+=("Change 'features' to be an array of feature objects")
            validation_errors=$((validation_errors + 1))
        else
            # Verify features array is not empty
            local features_count=$(jq '.features | length' "$prp_file")
            if [ "$features_count" -eq 0 ]; then
                echo -e "${RED}[✗]${NC} Field 'features' array cannot be empty"
                suggestions+=("Add at least one feature to the 'features' array")
                validation_errors=$((validation_errors + 1))
            else
                echo -e "${GREEN}[✓]${NC} Features array structure"
            fi
        fi
    fi

    # ========================================================================
    # 3. Validate task structure and uniqueness
    # ========================================================================
    if ! validate_task_structure "$prp_file"; then
        echo -e "${RED}[✗]${NC} Task structure and uniqueness"
        suggestions+=("Fix task structure issues (see errors above)")
        validation_errors=$((validation_errors + 1))
    else
        echo -e "${GREEN}[✓]${NC} Task structure and uniqueness"
    fi

    # ========================================================================
    # 4. Validate dependencies
    # ========================================================================
    if ! validate_dependencies "$prp_file"; then
        echo -e "${RED}[✗]${NC} Task dependencies"
        suggestions+=("Fix dependency issues (see errors above)")
        validation_errors=$((validation_errors + 1))
    else
        echo -e "${GREEN}[✓]${NC} Task dependencies"
    fi

    echo ""

    # ========================================================================
    # Display validation summary
    # ========================================================================
    display_validation_summary "$prp_file" "$validation_errors" "$validation_warnings" "${suggestions[@]+"${suggestions[@]}"}"

    if [ "$validation_errors" -gt 0 ]; then
        return 1
    fi

    return 0
}

display_validation_summary() {
    local prp_file="$1"
    local errors="$2"
    local warnings="$3"
    shift 3
    local suggestions=("$@")

    # Count statistics
    local features_count=$(jq '.features | length' "$prp_file" 2>/dev/null || echo "0")
    local tasks_count=$(jq '[.features[].tasks[]] | length' "$prp_file" 2>/dev/null || echo "0")
    local total_deps=$(jq '[.features[].tasks[].dependencies // [] | length] | add // 0' "$prp_file" 2>/dev/null || echo "0")

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Validation Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Statistics:"
    echo "  • Features: $features_count"
    echo "  • Tasks: $tasks_count"
    echo "  • Total dependencies: $total_deps"
    echo ""

    if [ "$errors" -gt 0 ]; then
        echo -e "${RED}Errors: $errors${NC}"
    fi

    if [ "$warnings" -gt 0 ]; then
        echo -e "${YELLOW}Warnings: $warnings${NC}"
    fi

    # Display suggestions if any
    if [ ${#suggestions[@]} -gt 0 ]; then
        echo ""
        echo "Suggestions:"
        for suggestion in "${suggestions[@]}"; do
            [ -z "$suggestion" ] && continue
            echo -e "  ${YELLOW}→${NC} $suggestion"
        done
    fi

    echo ""

    if [ "$errors" -eq 0 ]; then
        echo -e "${GREEN}✓ PRP is valid and ready to use${NC}"
        echo ""
    else
        echo -e "${RED}✗ PRP validation failed - please fix the errors above${NC}"
        echo ""
        exit 1
    fi
}

show_help() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔥 SACI - Sistema Autônomo de Coding${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage: saci.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  scan                     Scan codebase and auto-detect context"
    echo "  init                     Interactively generate PRP from your idea"
    echo "  analyze <file>           Analyze a file and suggest patterns/hints"
    echo "  reset [task-id]          Reset all tasks (or specific task) to passes: false"
    echo "  reset <task-id> --cascade Reset task and all dependent tasks recursively"
    echo "  status                   Show task progress with nice TUI (requires gum)"
    echo "  validate [file]          Validate PRP file structure and dependencies (default: prp.json)"
    echo "  jump                     Execute the Ralph loop (default)"
    echo ""
    echo "Jump Options:"
    echo "  --dry-run           Show what would be done without executing"
    echo "  --prp FILE          Use specified PRP file (default: prp.json)"
    echo "  --max-iter N        Max iterations per task (default: 10)"
    echo "  --provider NAME     CLI provider: claude or amp (default: claude)"
    echo ""
    echo "Environment Variables:"
    echo "  CLI_PROVIDER        Set default provider (claude or amp)"
    echo ""
    echo "Examples:"
    echo "  ./saci.sh scan                       # Detect stack and libs"
    echo "  ./saci.sh init                       # Create PRP interactively"
    echo "  ./saci.sh analyze src/Button.tsx     # Analyze patterns"
    echo "  ./saci.sh validate                   # Validate prp.json"
    echo "  ./saci.sh validate custom.json       # Validate custom PRP file"
    echo "  ./saci.sh jump --dry-run              # Test run"
    echo "  ./saci.sh jump --provider amp         # Use Amp instead of Claude"
    echo "  ./saci.sh jump                        # Execute tasks"
    echo ""
}

# Main entry point with subcommand routing
case "${1:-jump}" in
    scan)
        source "$SCRIPT_DIR/lib/scanner.sh"
        shift
        run_scan "$@"
        ;;
    init)
        source "$SCRIPT_DIR/lib/generator.sh"
        shift
        run_generator "$@"
        ;;
    analyze)
        source "$SCRIPT_DIR/lib/analyzer.sh"
        shift
        run_analyzer "$@"
        ;;
    reset)
        shift
        run_reset "$@"
        ;;
    status)
        source "$SCRIPT_DIR/lib/tui.sh"
        shift
        show_status "${1:-prp.json}"
        ;;
    validate)
        shift
        run_validate "$@"
        ;;
    jump)
        shift 2>/dev/null || true
        main "$@"
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        # If first arg is an option, assume 'jump' command
        if [[ "${1:-}" == --* ]]; then
            main "$@"
        else
            echo -e "${RED}[✗]${NC} Unknown command: $1"
            echo "Run './saci.sh --help' for usage"
            exit 1
        fi
        ;;
esac
