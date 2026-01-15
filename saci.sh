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
    echo "" >> "$PROGRESS_FILE"
    echo "## [$(timestamp)] Task $task_id - $status" >> "$PROGRESS_FILE"
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
    # Find first task with passes: false across all features, ordered by feature then task priority
    jq -r '
        [.features[] | .tasks[] | select(.passes == false)] 
        | sort_by(.priority) 
        | first 
        | if . then .id else empty end
    ' "$PRP_FILE"
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
# Prompt Builder
# ============================================================================

build_task_prompt() {
    local task_id="$1"
    local iteration="$2"
    local previous_error="${3:-}"  # Error from previous iteration
    local title=$(get_task_field "$task_id" "title")
    local description=$(get_task_field "$task_id" "description")
    local context=$(get_task_context "$task_id")
    local acceptance=$(get_acceptance_criteria "$task_id")
    local test_cmd=$(get_test_command "$task_id")
    
    # Read system prompt
    local system_prompt=""
    if [ -f "$PROMPT_FILE" ]; then
        system_prompt=$(cat "$PROMPT_FILE")
    fi
    
    # Read progress file for previous attempts context
    local progress_context=""
    if [ -f "$PROGRESS_FILE" ] && [ -s "$PROGRESS_FILE" ]; then
        progress_context=$(tail -100 "$PROGRESS_FILE")  # Last 100 lines only
    fi
    
    # Build error section if we have previous error
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
    
    # Build the complete prompt
    cat <<EOF
$system_prompt

---

# Current Task: $title

**Task ID:** $task_id
**Iteration:** $iteration of $MAX_ITERATIONS

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
\`$test_cmd\`
$error_section
---

## Previous Progress & Learnings
$progress_context

---

## Instructions

1. Read the previous progress above to understand what has been tried before
2. Implement the task following the context hints
3. Run the test command: \`$test_cmd\`
4. If tests pass, commit with: "feat: $title [task-$task_id]"
5. If tests fail, document what you tried and the errors

**IMPORTANT:** 
- This is iteration $iteration. If previous attempts failed, try a DIFFERENT approach.
- Focus on completing ALL acceptance criteria.

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

run_single_iteration() {
    local task_id="$1"
    local iteration="$2"
    local previous_error="${3:-}"  # Error from previous iteration
    local title=$(get_task_field "$task_id" "title")
    local test_cmd=$(get_test_command "$task_id")
    
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
            cli_cmd="claude --print --dangerously-skip-permissions"
            ;;
        amp)
            cli_cmd="amp --print --dangerously-skip-permissions"
            ;;
    esac
    
    # Run CLI with the prompt - this starts a NEW session
    if cat "$prompt_file" | $cli_cmd 2>&1 | tee "$cli_output_file"; then
        rm -f "$prompt_file"
        
        # ================================================================
        # CHECK IF ANY FILES WERE ACTUALLY MODIFIED
        # ================================================================
        local changed_files=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$changed_files" -eq 0 ]; then
            # Check if task was already marked as complete (AI may have updated prp.json)
            local task_status=$(jq -r --arg id "$task_id" '.features[].tasks[] | select(.id == $id) | .passes' "$PRP_FILE")
            if [ "$task_status" = "true" ]; then
                log_success "Task already marked as complete - skipping to next"
                rm -f "$cli_output_file"
                return 0
            fi
            
            log_warning "No files were modified - AI did not make any changes"
            LAST_ERROR="No files were modified. The AI session completed but did not create or edit any files. Please ensure you actually create/modify the required files."
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
            
            # Commit changes
            git add -A 2>/dev/null || true
            git commit -m "$(cat <<EOF
feat: $title [task-$task_id]

Co-Authored-By: Saci <noreply@saci.sh>
EOF
)" 2>/dev/null || true
            
            # Mark task complete
            mark_task_complete "$task_id"
            
            # Clear error state
            LAST_ERROR=""
            LAST_APPROACH=""
            
            # Log success to progress
            log_progress "$task_id" "✅ COMPLETED" "
**Iteration:** $iteration
**Result:** All tests passed
**Commit:** feat: $title [task-$task_id]
"
            return 0
        else
            # ================================================================
            # TESTS FAILED - Capture specific error for next iteration
            # ================================================================
            local test_output=$(cat "$test_output_file" | tail -50)
            rm -f "$test_output_file"
            
            log_warning "Tests failed on iteration $iteration"
            
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
            
            # Log detailed error to progress
            log_progress "$task_id" "⚠️ TESTS FAILED" "
**Iteration:** $iteration
**Test Command:** $test_cmd
**Error Output:**
\`\`\`
$test_output
\`\`\`
**Action:** Rolled back changes, will retry with error context
"
            rm -f "$cli_output_file"
            return 1
        fi
    else
        rm -f "$prompt_file" "$cli_output_file"
        log_error "$CLI_PROVIDER session failed"
        
        # Rollback on Claude failure too
        if [ -n "$git_checkpoint" ]; then
            log_info "Rolling back to checkpoint ${git_checkpoint:0:7}..."
            git reset --hard "$git_checkpoint" 2>/dev/null || true
            git clean -fd -e prp.json -e progress.txt 2>/dev/null || true
        fi
        
        log_progress "$task_id" "❌ SESSION FAILED" "
**Iteration:** $iteration
**Result:** Claude Code session encountered an error
**Action:** Rolled back, will retry
"
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

run_reset() {
    local prp_file="${PRP_FILE:-prp.json}"
    local task_id="${1:-}"
    
    if [ ! -f "$prp_file" ]; then
        log_error "PRP file not found: $prp_file"
        exit 1
    fi
    
    if [ -n "$task_id" ]; then
        # Reset specific task
        local tmp_file=$(mktemp)
        jq --arg id "$task_id" '
            .features |= map(.tasks |= map(if .id == $id then .passes = false else . end))
        ' "$prp_file" > "$tmp_file" && mv "$tmp_file" "$prp_file"
        log_success "Reset task $task_id to passes: false"
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

show_help() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔥 SACI - Sistema Autônomo de Coding${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage: saci.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  scan              Scan codebase and auto-detect context"
    echo "  init              Interactively generate PRP from your idea"
    echo "  analyze <file>    Analyze a file and suggest patterns/hints"
    echo "  reset [task-id]   Reset all tasks (or specific task) to passes: false"
    echo "  status            Show task progress with nice TUI (requires gum)"
    echo "  run               Execute the Ralph loop (default)"
    echo ""
    echo "Run Options:"
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
    echo "  ./saci.sh run --dry-run              # Test run"
    echo "  ./saci.sh run --provider amp         # Use Amp instead of Claude"
    echo "  ./saci.sh run                        # Execute tasks"
    echo ""
}

# Main entry point with subcommand routing
case "${1:-run}" in
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
    run)
        shift 2>/dev/null || true
        main "$@"
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        # If first arg is an option, assume 'run' command
        if [[ "${1:-}" == --* ]]; then
            main "$@"
        else
            echo -e "${RED}[✗]${NC} Unknown command: $1"
            echo "Run './saci.sh --help' for usage"
            exit 1
        fi
        ;;
esac
