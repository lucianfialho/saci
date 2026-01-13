#!/bin/bash
# ============================================================================
# SACI Scanner - Analisa codebase e auto-preenche contexto no PRP
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[SCAN]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_item() { echo -e "  ${CYAN}•${NC} $1"; }

# ============================================================================
# Stack Detection
# ============================================================================

detect_stack() {
    local stack=()
    
    # Node.js / JavaScript
    if [ -f "package.json" ]; then
        # Framework detection
        if grep -q '"next"' package.json 2>/dev/null; then
            stack+=("Next.js")
        elif grep -q '"react"' package.json 2>/dev/null; then
            stack+=("React")
        elif grep -q '"vue"' package.json 2>/dev/null; then
            stack+=("Vue")
        elif grep -q '"svelte"' package.json 2>/dev/null; then
            stack+=("Svelte")
        elif grep -q '"express"' package.json 2>/dev/null; then
            stack+=("Express")
        fi
        
        # TypeScript
        if [ -f "tsconfig.json" ] || grep -q '"typescript"' package.json 2>/dev/null; then
            stack+=("TypeScript")
        else
            stack+=("JavaScript")
        fi
        
        # CSS Framework
        if grep -q '"tailwindcss"' package.json 2>/dev/null; then
            stack+=("Tailwind")
        elif grep -q '"styled-components"' package.json 2>/dev/null; then
            stack+=("styled-components")
        fi
        
        # Testing
        if grep -q '"jest"' package.json 2>/dev/null; then
            stack+=("Jest")
        elif grep -q '"vitest"' package.json 2>/dev/null; then
            stack+=("Vitest")
        fi
        
        # Database
        if grep -q '"prisma"' package.json 2>/dev/null; then
            stack+=("Prisma")
        elif grep -q '"drizzle-orm"' package.json 2>/dev/null; then
            stack+=("Drizzle")
        fi
    fi
    
    # Python
    if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        stack+=("Python")
        if grep -q 'fastapi' requirements.txt 2>/dev/null || grep -q 'fastapi' pyproject.toml 2>/dev/null; then
            stack+=("FastAPI")
        elif grep -q 'django' requirements.txt 2>/dev/null || grep -q 'django' pyproject.toml 2>/dev/null; then
            stack+=("Django")
        elif grep -q 'flask' requirements.txt 2>/dev/null || grep -q 'flask' pyproject.toml 2>/dev/null; then
            stack+=("Flask")
        fi
    fi
    
    # Go
    if [ -f "go.mod" ]; then
        stack+=("Go")
    fi
    
    # Rust
    if [ -f "Cargo.toml" ]; then
        stack+=("Rust")
    fi
    
    # Docker
    if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
        stack+=("Docker")
    fi
    
    echo "${stack[@]:-}"
}

# ============================================================================
# Directory Structure Mapping
# ============================================================================

detect_paths() {
    local paths=()
    
    # Common source directories
    [ -d "src" ] && paths+=("src:./src")
    [ -d "app" ] && paths+=("app:./app")
    [ -d "lib" ] && paths+=("lib:./lib")
    [ -d "pages" ] && paths+=("pages:./pages")
    [ -d "components" ] && paths+=("components:./components")
    [ -d "src/components" ] && paths+=("components:./src/components")
    [ -d "src/app" ] && paths+=("app:./src/app")
    
    # API
    [ -d "api" ] && paths+=("api:./api")
    [ -d "src/api" ] && paths+=("api:./src/api")
    [ -d "src/app/api" ] && paths+=("api:./src/app/api")
    
    # Tests
    [ -d "tests" ] && paths+=("tests:./tests")
    [ -d "test" ] && paths+=("tests:./test")
    [ -d "__tests__" ] && paths+=("tests:./__tests__")
    [ -d "src/__tests__" ] && paths+=("tests:./src/__tests__")
    
    # Styles
    [ -d "styles" ] && paths+=("styles:./styles")
    [ -d "src/styles" ] && paths+=("styles:./src/styles")
    
    # Utils/Lib
    [ -d "utils" ] && paths+=("utils:./utils")
    [ -d "src/utils" ] && paths+=("utils:./src/utils")
    [ -d "src/lib" ] && paths+=("lib:./src/lib")
    
    echo "${paths[@]:-}"
}

# ============================================================================
# Library Detection
# ============================================================================

detect_libraries() {
    local libs=()
    
    if [ -f "package.json" ]; then
        # State management
        grep -q '"zustand"' package.json && libs+=("zustand")
        grep -q '"@reduxjs/toolkit"' package.json && libs+=("redux-toolkit")
        grep -q '"jotai"' package.json && libs+=("jotai")
        grep -q '"recoil"' package.json && libs+=("recoil")
        
        # Forms
        grep -q '"react-hook-form"' package.json && libs+=("react-hook-form")
        grep -q '"formik"' package.json && libs+=("formik")
        
        # Validation
        grep -q '"zod"' package.json && libs+=("zod")
        grep -q '"yup"' package.json && libs+=("yup")
        
        # HTTP
        grep -q '"axios"' package.json && libs+=("axios")
        grep -q '"@tanstack/react-query"' package.json && libs+=("react-query")
        grep -q '"swr"' package.json && libs+=("swr")
        
        # Auth
        grep -q '"next-auth"' package.json && libs+=("next-auth")
        grep -q '"@clerk"' package.json && libs+=("clerk")
        grep -q '"@supabase"' package.json && libs+=("supabase")
        
        # UI Components
        grep -q '"@radix-ui"' package.json && libs+=("radix-ui")
        grep -q '"@shadcn"' package.json && libs+=("shadcn")
        grep -q '"@chakra-ui"' package.json && libs+=("chakra-ui")
        grep -q '"@mui"' package.json && libs+=("material-ui")
        
        # Animation
        grep -q '"framer-motion"' package.json && libs+=("framer-motion")
        
        # Date
        grep -q '"date-fns"' package.json && libs+=("date-fns")
        grep -q '"dayjs"' package.json && libs+=("dayjs")
    fi
    
    echo "${libs[@]:-}"
}

# ============================================================================
# Pattern Detection
# ============================================================================

detect_patterns() {
    local patterns=()
    
    # Component patterns
    if find . -name "*.tsx" -o -name "*.jsx" 2>/dev/null | head -1 | xargs grep -l "forwardRef" 2>/dev/null | head -1 > /dev/null; then
        patterns+=("Uses forwardRef for component refs")
    fi
    
    # API patterns (Next.js)
    if [ -d "src/app/api" ] || [ -d "app/api" ]; then
        patterns+=("Next.js App Router API routes")
    elif [ -d "pages/api" ]; then
        patterns+=("Next.js Pages Router API routes")
    fi
    
    # Hooks pattern
    if [ -d "src/hooks" ] || [ -d "hooks" ]; then
        patterns+=("Custom hooks in dedicated folder")
    fi
    
    # Context pattern
    if find . -name "*Context*" -o -name "*Provider*" 2>/dev/null | head -1 > /dev/null; then
        patterns+=("React Context for state")
    fi
    
    # Server components
    if find . -name "*.tsx" 2>/dev/null | xargs grep -l "use server" 2>/dev/null | head -1 > /dev/null; then
        patterns+=("Uses Server Actions")
    fi
    
    # Testing patterns
    if find . -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | head -1 > /dev/null; then
        patterns+=("Co-located test files")
    fi
    
    echo "${patterns[@]:-}"
}

# ============================================================================
# Main Scanner
# ============================================================================

run_scan() {
    local target_dir="${1:-.}"
    local output_file="${2:-prp.json}"
    
    cd "$target_dir"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔍 Saci Scanner - Analyzing Codebase${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    log_info "Detecting stack..."
    local stack_raw=$(detect_stack)
    local stack=()
    if [ -n "$stack_raw" ]; then
        read -ra stack <<< "$stack_raw"
    fi
    for s in "${stack[@]:-}"; do
        [ -n "$s" ] && log_item "$s"
    done
    
    log_info "Mapping directory structure..."
    local paths_raw=$(detect_paths)
    local paths=()
    if [ -n "$paths_raw" ]; then
        read -ra paths <<< "$paths_raw"
    fi
    for p in "${paths[@]:-}"; do
        [ -n "$p" ] && log_item "$p"
    done
    
    log_info "Detecting libraries..."
    local libs_raw=$(detect_libraries)
    local libs=()
    if [ -n "$libs_raw" ]; then
        read -ra libs <<< "$libs_raw"
    fi
    for l in "${libs[@]:-}"; do
        [ -n "$l" ] && log_item "$l"
    done
    
    # Detect patterns
    log_info "Analyzing code patterns..."
    local patterns_raw=$(detect_patterns)
    # patterns are strings with spaces, handle differently
    
    # Generate JSON
    log_info "Generating project context..."
    
    # Get project name from package.json or folder name
    local project_name
    if [ -f "package.json" ]; then
        project_name=$(jq -r '.name // "my-project"' package.json)
    else
        project_name=$(basename "$PWD")
    fi
    
    local stack_json="["
    local first=true
    for s in "${stack[@]:-}"; do
        [ -z "$s" ] && continue
        if [ "$first" = true ]; then
            stack_json+="\"$s\""
            first=false
        else
            stack_json+=", \"$s\""
        fi
    done
    stack_json+="]"
    
    local paths_json="{"
    first=true
    for p in "${paths[@]:-}"; do
        [ -z "$p" ] && continue
        local key="${p%%:*}"
        local val="${p#*:}"
        if [ "$first" = true ]; then
            paths_json+="\"$key\": \"$val\""
            first=false
        else
            paths_json+=", \"$key\": \"$val\""
        fi
    done
    paths_json+="}"
    
    local libs_json="["
    first=true
    for l in "${libs[@]:-}"; do
        [ -z "$l" ] && continue
        if [ "$first" = true ]; then
            libs_json+="\"$l\""
            first=false
        else
            libs_json+=", \"$l\""
        fi
    done
    libs_json+="]"
    
    # Create or update prp.json
    local script_dir="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
    local template_file="$script_dir/templates/prp.json"
    
    if [ ! -f "$template_file" ]; then
        log_error "Template not found: $template_file"
        # Fallback to simple default if template missing
        echo "{ \"project\": { \"name\": \"$project_name\" }, \"features\": [] }" > "$output_file"
    else
        # Use template
        if [ -f "$output_file" ]; then
             # If exists, we only update specific fields using jq
             local tmp_file=$(mktemp)
             jq --argjson stack "$stack_json" \
                --argjson paths "$paths_json" \
                --argjson libs "$libs_json" \
                '.project.stack = $stack | .project.paths = $paths | .project.detected_libraries = $libs' \
                "$output_file" > "$tmp_file" && mv "$tmp_file" "$output_file"
             log_success "Updated $output_file with detected context"
        else
            # Create new from template
            sed -e "s|{{PROJECT_NAME}}|$project_name|g" \
                -e "s|{{PROJECT_DESCRIPTION}}|TODO: Add project description|g" \
                -e "s|{{STACK_JSON}}|$stack_json|g" \
                -e "s|{{PATHS_JSON}}|$paths_json|g" \
                -e "s|{{LIBS_JSON}}|$libs_json|g" \
                -e "s|{{FEATURES_JSON}}||g" \
                "$template_file" > "$output_file"
            log_success "Created $output_file from template"
        fi
    fi
     
    # ========================================================================
    # Generate AGENTS.md
    # ========================================================================
    local agents_template_file="$script_dir/templates/AGENTS.md"
    local agents_output_file="AGENTS.md"
    
    if [ -f "$agents_template_file" ] && [ ! -f "$agents_output_file" ]; then
        log_info "Generating AGENTS.md..."
        
        # Detect scripts/commands
        local commands_list=""
        if [ -f "package.json" ]; then
             commands_list=$(jq -r '.scripts | to_entries[] | "- \(.key): npm run \(.key)"' package.json 2>/dev/null || echo "")
        fi
        
        # Format stack list
        local stack_list=$(echo "${stack[@]:-}" | sed 's/ /, /g')
        
        # Determine language/framework/test
        local language="JavaScript"
        [[ "${stack[*]:-}" == *"TypeScript"* ]] && language="TypeScript"
        [[ "${stack[*]:-}" == *"Python"* ]] && language="Python"
        
        local framework="None"
        [[ "${stack[*]:-}" == *"Next.js"* ]] && framework="Next.js"
        [[ "${stack[*]:-}" == *"React"* ]] && framework="React"
        [[ "${stack[*]:-}" == *"Vue"* ]] && framework="Vue"
        
        local test_framework="None"
        [[ "${stack[*]:-}" == *"Jest"* ]] && test_framework="Jest"
        [[ "${stack[*]:-}" == *"Vitest"* ]] && test_framework="Vitest"
        
        # Replace in template (using perl/awk for safer block replacement or loop)
        # We'll use simple sed for single lines and loop for block
        
        cp "$agents_template_file" "$agents_output_file"
        
        sed -i '' "s|{{PROJECT_NAME}}|$project_name|g" "$agents_output_file"
        sed -i '' "s|{{PROJECT_DESCRIPTION}}|TODO: Add description|g" "$agents_output_file"
        sed -i '' "s|{{STACK_LIST}}|$stack_list|g" "$agents_output_file"
        sed -i '' "s|{{LANGUAGE}}|$language|g" "$agents_output_file"
        sed -i '' "s|{{FRAMEWORK}}|$framework|g" "$agents_output_file"
        sed -i '' "s|{{TEST_FRAMEWORK}}|$test_framework|g" "$agents_output_file"
        
        # Replace commands list (multiline)
        if [ -n "$commands_list" ]; then
            echo "$commands_list" > commands.tmp
            awk 'FNR==NR{a[NR]=$0;next} /{{COMMANDS_LIST}}/{for(i=1;i<=length(a);i++)print a[i];next} 1' commands.tmp "$agents_output_file" > "${agents_output_file}.tmp" && mv "${agents_output_file}.tmp" "$agents_output_file"
            rm commands.tmp
        else
            sed -i '' "s|{{COMMANDS_LIST}}|- build: npm run build\n- test: npm test|g" "$agents_output_file"
        fi
        
        log_success "Created AGENTS.md with detected context"
    fi
    
    echo ""
    log_success "Scan complete!"
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_scan "$@"
fi
