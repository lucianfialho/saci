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
        exit 1
    fi
}

# ============================================================================
# Task Display Components
# ============================================================================

# Generate task list with status icons
generate_task_list() {
    local prp_file="$1"
    local current_task="$2"
    
    jq -r --arg current "$current_task" '
        .features[] | .tasks[] | 
        if .id == $current then
            "▶ \(.id): \(.title)"
        elif .passes == true then
            "■ \(.id): \(.title)"
        else
            "□ \(.id): \(.title)"
        end
    ' "$prp_file"
}

# Create styled task panel
render_task_panel() {
    local prp_file="$1"
    local current_task="$2"
    local width="${3:-30}"
    
    local completed=$(jq '[.features[].tasks[] | select(.passes == true)] | length' "$prp_file")
    local total=$(jq '[.features[].tasks[]] | length' "$prp_file")
    local percent=$((completed * 100 / total))
    
    # Build progress bar
    local bar_width=20
    local filled=$((completed * bar_width / total))
    local empty=$((bar_width - filled))
    local progress_bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) || echo "")
    progress_bar+=$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) || echo "")
    
    # Task list
    local tasks=$(generate_task_list "$prp_file" "$current_task")
    
    # Combine into panel
    echo "Tasks ($completed/$total)"
    echo ""
    echo "$tasks"
    echo ""
    echo "$progress_bar $percent%"
}

# Create styled log panel
render_log_panel() {
    local log_file="$1"
    local height="${2:-15}"
    
    if [ -f "$log_file" ]; then
        tail -n "$height" "$log_file"
    else
        echo "Waiting for logs..."
    fi
}

# ============================================================================
# Main TUI Runner
# ============================================================================

run_tui() {
    local prp_file="${1:-prp.json}"
    local log_file=$(mktemp)
    local current_task=""
    
    check_gum
    
    # Clear screen
    clear
    
    # Header
    gum style \
        --foreground 212 \
        --border-foreground 212 \
        --border double \
        --align center \
        --width 60 \
        --margin "1 2" \
        --padding "1 2" \
        "🔥 SACI - Autonomous Coding Loop" \
        "Press Ctrl+C to stop"
    
    echo ""
    
    # Get first task
    current_task=$(jq -r '[.features[].tasks[] | select(.passes == false)][0].id // empty' "$prp_file")
    
    if [ -z "$current_task" ]; then
        gum style --foreground 10 "✓ All tasks completed!"
        rm -f "$log_file"
        return 0
    fi
    
    # Main loop - render panels side by side
    while [ -n "$current_task" ]; do
        # Render task panel
        local task_panel=$(render_task_panel "$prp_file" "$current_task" | gum style \
            --border normal \
            --border-foreground 240 \
            --padding "1 2" \
            --width 35)
        
        # Render log panel
        local log_panel=$(render_log_panel "$log_file" 12 | gum style \
            --border normal \
            --border-foreground 240 \
            --padding "1 2" \
            --width 50)
        
        # Join panels horizontally
        clear
        gum join --horizontal "$task_panel" "$log_panel"
        
        # Get task info
        local title=$(jq -r --arg id "$current_task" '.features[].tasks[] | select(.id == $id) | .title' "$prp_file")
        local test_cmd=$(jq -r --arg id "$current_task" '.features[].tasks[] | select(.id == $id) | .tests.command // "npm test"' "$prp_file")
        
        # Log current task
        echo "[$(date '+%H:%M:%S')] Starting: $title" >> "$log_file"
        
        # Run task with spinner
        echo "[$(date '+%H:%M:%S')] Spawning Claude..." >> "$log_file"
        
        # Simulate task execution (replace with actual execution)
        # In real implementation, this would call run_single_iteration
        gum spin --spinner dot --title "Running $current_task..." -- sleep 2
        
        # Check result (simulated)
        echo "[$(date '+%H:%M:%S')] ✓ Task completed" >> "$log_file"
        
        # Mark complete (simulated)
        local tmp_file=$(mktemp)
        jq --arg id "$current_task" '
            .features |= map(.tasks |= map(if .id == $id then .passes = true else . end))
        ' "$prp_file" > "$tmp_file" && mv "$tmp_file" "$prp_file"
        
        # Get next task
        current_task=$(jq -r '[.features[].tasks[] | select(.passes == false)][0].id // empty' "$prp_file")
        
        sleep 1
    done
    
    # Final render
    clear
    local task_panel=$(render_task_panel "$prp_file" "" | gum style \
        --border normal \
        --border-foreground 10 \
        --padding "1 2" \
        --width 35)
    
    local log_panel=$(render_log_panel "$log_file" 12 | gum style \
        --border normal \
        --border-foreground 10 \
        --padding "1 2" \
        --width 50)
    
    gum join --horizontal "$task_panel" "$log_panel"
    
    echo ""
    gum style --foreground 10 --bold "🎉 All tasks completed!"
    
    rm -f "$log_file"
}

# ============================================================================
# Interactive Task Picker
# ============================================================================

pick_task() {
    local prp_file="${1:-prp.json}"
    
    check_gum
    
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

# ============================================================================
# Styled Status Display
# ============================================================================

show_status() {
    local prp_file="${1:-prp.json}"
    
    check_gum
    
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
    local progress_bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) || echo "")
    local remaining=$((bar_width - filled))
    progress_bar+=$(printf '░%.0s' $(seq 1 $remaining 2>/dev/null) || echo "")
    
    gum style --foreground 212 "Progress: $progress_bar $completed/$total ($percent%)"
    
    echo ""
    
    # Task list
    jq -r '.features[] | .tasks[] | 
        if .passes == true then
            "  \u001b[32m■\u001b[0m \(.id): \(.title)"
        else
            "  \u001b[90m□\u001b[0m \(.id): \(.title)"
        end
    ' "$prp_file"
    
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        run) run_tui "${2:-prp.json}" ;;
        pick) pick_task "${2:-prp.json}" ;;
        status) show_status "${2:-prp.json}" ;;
        *) echo "Usage: tui.sh [run|pick|status] [prp.json]" ;;
    esac
fi
