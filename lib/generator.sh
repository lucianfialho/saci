#!/bin/bash
# ============================================================================
# SACI Generator - Interactively creates PRP from user input
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[GEN]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_prompt() { echo -e "${CYAN}?${NC} $1"; }

# ============================================================================
# Interactive Prompts
# ============================================================================

prompt_text() {
    local question="$1"
    local default="${2:-}"
    
    if [ -n "$default" ]; then
        log_prompt "$question [$default]"
    else
        log_prompt "$question"
    fi
    
    echo -n "> "
    read -r answer
    
    if [ -z "$answer" ] && [ -n "$default" ]; then
        echo "$default"
    else
        echo "$answer"
    fi
}

prompt_list() {
    local question="$1"
    local items=()
    
    log_prompt "$question (leave empty to finish)"
    
    while true; do
        echo -n "> "
        read -r item
        [ -z "$item" ] && break
        items+=("$item")
    done
    
    echo "${items[@]}"
}

# ============================================================================
# Feature Generator
# ============================================================================

generate_feature() {
    local feature_id="$1"
    local feature_name="$2"
    local feature_desc="$3"
    
    log_info "Generating tasks for: $feature_name"
    log_prompt "What tasks does this feature need? (leave empty to finish)"
    
    local tasks=()
    local task_num=1
    
    while true; do
        echo -n "Task $task_num> "
        read -r task_title
        [ -z "$task_title" ] && break
        
        local task_id="${feature_id}-T${task_num}"
        
        # Simple task structure
        tasks+=("{
      \"id\": \"$task_id\",
      \"title\": \"$task_title\",
      \"description\": \"TODO: Add description\",
      \"priority\": $task_num,
      \"passes\": false,
      \"context\": {
        \"files\": [],
        \"libraries\": [],
        \"hints\": []
      },
      \"acceptance\": [],
      \"tests\": {
        \"command\": \"npm test\"
      }
    }")
        
        task_num=$((task_num + 1))
    done
    
    # Build tasks JSON
    local tasks_json=""
    local first=true
    for t in "${tasks[@]}"; do
        if [ "$first" = true ]; then
            tasks_json+="$t"
            first=false
        else
            tasks_json+=",
    $t"
        fi
    done
    
    echo "{
    \"id\": \"$feature_id\",
    \"name\": \"$feature_name\",
    \"description\": \"$feature_desc\",
    \"priority\": ${feature_id#F},
    \"tasks\": [
    $tasks_json
    ]
  }"
}

# ============================================================================
# Main Generator
# ============================================================================

run_generator() {
    local output_file="${1:-prp.json}"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔥 Saci PRP Generator${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Project info
    local project_name=$(prompt_text "Project name" "my-project")
    local project_desc=$(prompt_text "Describe the project idea")
    
    echo ""
    log_info "Now let's define the main features"
    log_prompt "What are the features? (leave empty to finish)"
    echo ""
    
    local features=()
    local feature_num=1
    
    while true; do
        echo -n "Feature $feature_num name> "
        read -r feature_name
        [ -z "$feature_name" ] && break
        
        echo -n "Feature $feature_num description> "
        read -r feature_desc
        
        local feature_id="F${feature_num}"
        echo ""
        
        local feature_json=$(generate_feature "$feature_id" "$feature_name" "$feature_desc")
        features+=("$feature_json")
        
        feature_num=$((feature_num + 1))
        echo ""
    done
    
    # Build features JSON
    local features_json=""
    local first=true
    for f in "${features[@]}"; do
        if [ "$first" = true ]; then
            features_json+="$f"
            first=false
        else
            features_json+=",
  $f"
        fi
    done
    
    # Create PRP file from template
    local script_dir="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
    local template_file="$script_dir/templates/prp.json"
    
    if [ ! -f "$template_file" ]; then
        log_error "Template not found: $template_file"
        # Fallback
        cat > "$output_file" <<EOF
{
  "project": {
    "name": "$project_name",
    "description": "$project_desc",
    "stack": [],
    "paths": {}
  },
  "features": [
  $features_json
  ]
}
EOF
    else
        # Use template with sed
        # Note: features_json likely contains newlines which sed hates in replacement string
        # We'll use a placeholder file approach to avoid complex sed escaping
        
        cp "$template_file" "$output_file"
        
        # We need to escape slashes for sed
        project_desc_escaped=$(echo "$project_desc" | sed 's/\//\\\//g')
        
        # Replace simple fields
        sed -i '' "s/{{PROJECT_NAME}}/$project_name/g" "$output_file"
        sed -i '' "s/{{PROJECT_DESCRIPTION}}/$project_desc_escaped/g" "$output_file"
        sed -i '' "s/{{STACK_JSON}}/[]/g" "$output_file"
        sed -i '' "s/{{PATHS_JSON}}/{}/g" "$output_file"
        sed -i '' "s/{{LIBS_JSON}}/[]/g" "$output_file"
        
        # For the features array, we'll use a temporary placeholder and awk or perl would be safer
        # but let's try a safe sed approach by removing the placeholder line and appending content
        
        # Create a temp file with just the features content
        echo "$features_json" > features.tmp
        
        # Replace {{FEATURES_JSON}} with the file content
        # This is tricky with pure bash/sed. 
        # Simpler approach: Read template, replace everything except features in memory, then construct file
        
        local template_content=$(cat "$template_file")
        template_content="${template_content//\{\{PROJECT_NAME\}\}/$project_name}"
        template_content="${template_content//\{\{PROJECT_DESCRIPTION\}\}/$project_desc}"
        template_content="${template_content//\{\{STACK_JSON\}\}/[]}"
        template_content="${template_content//\{\{PATHS_JSON\}\}/{}}"
        template_content="${template_content//\{\{LIBS_JSON\}\}/[]}"
        template_content="${template_content//\{\{FEATURES_JSON\}\}/$features_json}"
        
        echo "$template_content" > "$output_file"
    fi
    
    echo ""
    log_success "PRP generated: $output_file"
    
    # Copy prompt.md template
    local prompt_template="$script_dir/templates/prompt.md"
    if [ -f "$prompt_template" ] && [ ! -f "prompt.md" ]; then
        cp "$prompt_template" "prompt.md"
        log_success "Created prompt.md from template"
    fi
    
    # Count stats
    local feature_count=${#features[@]}
    local task_count=$(jq '[.features[].tasks[]] | length' "$output_file")
    
    log_info "Features: $feature_count"
    log_info "Tasks: $task_count"
    echo ""
    log_info "Next steps:"
    echo "  1. Run 'saci scan' to detect stack/libs"
    echo "  2. Edit $output_file to add acceptance criteria"
    echo "  3. Run 'saci run' to start"
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_generator "$@"
fi
