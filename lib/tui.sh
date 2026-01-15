#!/bin/bash
# ============================================================================
# SACI TUI - Terminal User Interface usando Gum
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# TUI State
TUI_LOG_FILE=""
TUI_ENABLED=false

# Check if gum is installed
check_gum() {
    if ! command -v gum &> /dev/null; then
        echo -e "${RED}[✗] gum is not installed${NC}"
        echo ""
        echo "Install with:"
        echo "  brew install gum      # macOS"
        echo "  apt install gum       # Debian/Ubuntu"
        echo ""
        echo "Or see: https://github.com/charmbracelet/gum#installation"
        return 1
    fi
    return 0
}

# ============================================================================
# TUI Components
# ============================================================================

tui_init() {
    TUI_ENABLED=true
    TUI_LOG_FILE=$(mktemp)
    clear
}

tui_cleanup() {
    [ -f "$TUI_LOG_FILE" ] && rm -f "$TUI_LOG_FILE"
}

tui_log() {
    local message="$1"
    local timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] $message" >> "$TUI_LOG_FILE"
}

# Generate task list with status icons
tui_task_list() {
    local prp_file="$1"
    local current_task="$2"

    # We need to source saci.sh to use check_dependencies_met()
    # This assumes saci.sh is in the parent directory
    local saci_path="$(dirname "${BASH_SOURCE[0]}")/../saci.sh"
    if [ -f "$saci_path" ]; then
        source "$saci_path"
    fi

    # Get all tasks and check their status
    jq -r '.features[] | .tasks[] | "\(.id)|\(.title[0:25])|\(.passes // false)|\(.dependencies // [])"' "$prp_file" 2>/dev/null | while IFS='|' read -r task_id title passes deps; do
        local icon

        if [ "$task_id" = "$current_task" ]; then
            icon="▶"
        elif [ "$passes" = "true" ]; then
            icon="■"
        else
            # Check if task is blocked by unsatisfied dependencies
            if [ "$deps" != "[]" ] && [ -n "$deps" ]; then
                # Temporarily set PRP_FILE for dependency check
                local old_prp="$PRP_FILE"
                export PRP_FILE="$prp_file"

                if ! check_dependencies_met "$task_id" 2>/dev/null; then
                    icon="⊗"
                else
                    icon="□"
                fi

                export PRP_FILE="$old_prp"
            else
                icon="□"
            fi
        fi

        echo "$icon $task_id $title"
    done
}

# Render the full TUI
tui_render() {
    local prp_file="$1"
    local current_task="$2"
    local status="${3:-running}"
    
    [ "$TUI_ENABLED" != "true" ] && return
    
    local completed=$(jq '[.features[].tasks[] | select(.passes == true)] | length' "$prp_file" 2>/dev/null || echo 0)
    local total=$(jq '[.features[].tasks[]] | length' "$prp_file" 2>/dev/null || echo 0)
    local percent=0
    [ "$total" -gt 0 ] && percent=$((completed * 100 / total))
    
    # Progress bar
    local bar_width=20
    local filled=0
    [ "$total" -gt 0 ] && filled=$((completed * bar_width / total))
    local empty=$((bar_width - filled))
    local progress_bar=""
    for ((i=0; i<filled; i++)); do progress_bar+="█"; done
    for ((i=0; i<empty; i++)); do progress_bar+="░"; done
    
    # Task list
    local tasks=$(tui_task_list "$prp_file" "$current_task")
    
    # Build left panel content
    local left_content="Tasks ($completed/$total)

$tasks

$progress_bar $percent%"

    # Build right panel content (last 10 log lines)
    local right_content="Log

$(tail -10 "$TUI_LOG_FILE" 2>/dev/null || echo 'Starting...')"

    # Style panels
    local left_panel=$(echo "$left_content" | gum style \
        --border normal \
        --border-foreground 212 \
        --padding "1 2" \
        --width 35)
    
    local right_panel=$(echo "$right_content" | gum style \
        --border normal \
        --border-foreground 240 \
        --padding "1 2" \
        --width 50)
    
    # Clear and render
    clear
    
    # Header
    gum style \
        --foreground 212 \
        --bold \
        "🔥 SACI - Autonomous Coding Loop"
    
    echo ""
    
    # Panels side by side
    gum join --horizontal "$left_panel" "$right_panel"
    
    # Status bar
    echo ""
    case "$status" in
        running)
            gum style --foreground 33 "⟳ Running task $current_task..."
            ;;
        success)
            gum style --foreground 10 "✓ Task $current_task completed!"
            ;;
        failed)
            gum style --foreground 9 "✗ Task $current_task failed, retrying..."
            ;;
        complete)
            gum style --foreground 10 --bold "🎉 All tasks completed!"
            ;;
    esac
}

# ============================================================================
# TUI-aware logging functions (replace standard ones when TUI is active)
# ============================================================================

tui_log_info() {
    local message="$1"
    if [ "$TUI_ENABLED" = "true" ]; then
        tui_log "$message"
    else
        echo -e "${BLUE}[SACI]${NC} $message"
    fi
}

tui_log_success() {
    local message="$1"
    if [ "$TUI_ENABLED" = "true" ]; then
        tui_log "✓ $message"
    else
        echo -e "${GREEN}[✓]${NC} $message"
    fi
}

tui_log_warning() {
    local message="$1"
    if [ "$TUI_ENABLED" = "true" ]; then
        tui_log "⚠ $message"
    else
        echo -e "${YELLOW}[!]${NC} $message"
    fi
}

tui_log_error() {
    local message="$1"
    if [ "$TUI_ENABLED" = "true" ]; then
        tui_log "✗ $message"
    else
        echo -e "${RED}[✗]${NC} $message"
    fi
}

tui_log_iteration() {
    local message="$1"
    if [ "$TUI_ENABLED" = "true" ]; then
        tui_log "→ $message"
    else
        echo -e "${CYAN}[ITER]${NC} $message"
    fi
}

# ============================================================================
# Styled Status Display (standalone)
# ============================================================================

show_status() {
    local prp_file="${1:-prp.json}"
    
    if ! check_gum; then
        # Fallback without gum
        echo "=== SACI Status ==="
        jq -r '.features[].tasks[] | "\(if .passes then "✓" else "○" end) \(.id): \(.title)"' "$prp_file"
        return
    fi
    
    local project_name=$(jq -r '.project.name // "Unknown"' "$prp_file")
    local completed=$(jq '[.features[].tasks[] | select(.passes == true)] | length' "$prp_file")
    local total=$(jq '[.features[].tasks[]] | length' "$prp_file")
    local percent=$((total > 0 ? completed * 100 / total : 0))
    
    # Header
    gum style \
        --foreground 212 \
        --border-foreground 212 \
        --border double \
        --align center \
        --width 50 \
        --margin "1" \
        --padding "1" \
        "🔥 SACI Status" \
        "$project_name"
    
    echo ""
    
    # Progress
    local bar_width=30
    local filled=$((total > 0 ? completed * bar_width / total : 0))
    local progress_bar=""
    for ((i=0; i<filled; i++)); do progress_bar+="█"; done
    local remaining=$((bar_width - filled))
    for ((i=0; i<remaining; i++)); do progress_bar+="░"; done
    
    gum style --foreground 212 "Progress: $progress_bar $completed/$total ($percent%)"
    
    echo ""
    
    # Task list - source saci.sh for dependency functions
    local saci_path="$(dirname "${BASH_SOURCE[0]}")/../saci.sh"
    if [ -f "$saci_path" ]; then
        source "$saci_path"
    fi

    # Show tasks with dependency information
    jq -r '.features[] | .tasks[] | "\(.id)|\(.title)|\(.passes // false)|\(.dependencies // [])"' "$prp_file" | while IFS='|' read -r task_id title passes deps; do
        if [ "$passes" = "true" ]; then
            echo "  ✓ $task_id: $title"
        else
            # Check if blocked
            local status_line="  ○ $task_id: $title"

            if [ "$deps" != "[]" ] && [ -n "$deps" ]; then
                # Temporarily set PRP_FILE for dependency check
                local old_prp="$PRP_FILE"
                export PRP_FILE="$prp_file"

                if ! check_dependencies_met "$task_id" 2>/dev/null; then
                    # Get blocked dependencies
                    local blocked=$(get_blocked_dependencies "$task_id" 2>/dev/null)
                    if [ -n "$blocked" ]; then
                        status_line="$status_line [depends on: $blocked]"
                    fi
                fi

                export PRP_FILE="$old_prp"
            fi

            echo "$status_line"
        fi
    done
    
    echo ""
}

# ============================================================================
# Interactive Task Picker
# ============================================================================

pick_task() {
    local prp_file="${1:-prp.json}"
    
    check_gum || return 1
    
    local tasks=$(jq -r '.features[].tasks[] | "\(.id): \(.title) [\(if .passes then "✓" else "○" end)]"' "$prp_file")
    
    if [ -z "$tasks" ]; then
        echo "No tasks found in $prp_file"
        return 1
    fi
    
    local selected=$(echo "$tasks" | gum filter --placeholder "Select a task...")
    
    if [ -n "$selected" ]; then
        echo "${selected%%:*}"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        status) show_status "${2:-prp.json}" ;;
        pick) pick_task "${2:-prp.json}" ;;
        *) echo "Usage: tui.sh [status|pick] [prp.json]" ;;
    esac
fi
