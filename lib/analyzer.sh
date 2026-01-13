#!/bin/bash
# ============================================================================
# SACI Analyzer - Analyzes existing code files to suggest context
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[ANALYZE]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_item() { echo -e "  ${CYAN}•${NC} $1"; }
log_hint() { echo -e "  ${YELLOW}→${NC} $1"; }

# ============================================================================
# File Analysis
# ============================================================================

analyze_tsx_jsx() {
    local file="$1"
    local hints=()
    local patterns=()
    
    log_info "Analyzing: $file"
    echo ""
    
    # Check for patterns
    if grep -q "forwardRef" "$file" 2>/dev/null; then
        patterns+=("Uses forwardRef")
        hints+=("Use forwardRef for component refs like in $file")
    fi
    
    if grep -q "interface.*Props" "$file" 2>/dev/null; then
        patterns+=("TypeScript Props interface")
        hints+=("Define Props interface following pattern in $file")
    fi
    
    if grep -q "'use client'" "$file" 2>/dev/null; then
        patterns+=("Client Component")
    fi
    
    if grep -q "'use server'" "$file" 2>/dev/null; then
        patterns+=("Server Actions")
        hints+=("Use Server Actions pattern from $file")
    fi
    
    if grep -q "useState\|useEffect\|useCallback\|useMemo" "$file" 2>/dev/null; then
        patterns+=("React Hooks")
    fi
    
    if grep -q "className.*cn(" "$file" 2>/dev/null; then
        patterns+=("Uses cn() for classNames")
        hints+=("Use cn() utility for conditional classes")
    fi
    
    if grep -q "variants\|cva(" "$file" 2>/dev/null; then
        patterns+=("Class Variance Authority (cva)")
        hints+=("Use cva for component variants like $file")
    fi
    
    if grep -q "clsx\|twMerge" "$file" 2>/dev/null; then
        patterns+=("Tailwind class merging")
    fi
    
    if grep -q "data-testid" "$file" 2>/dev/null; then
        patterns+=("Test IDs for testing")
        hints+=("Add data-testid attributes for testing")
    fi
    
    if grep -q "aria-" "$file" 2>/dev/null; then
        patterns+=("Accessibility attributes")
        hints+=("Include proper aria-* attributes for a11y")
    fi
    
    # Display results
    if [ ${#patterns[@]} -gt 0 ]; then
        log_info "Patterns detected:"
        for p in "${patterns[@]}"; do
            log_item "$p"
        done
        echo ""
    fi
    
    if [ ${#hints[@]} -gt 0 ]; then
        log_info "Suggested hints for new tasks:"
        for h in "${hints[@]}"; do
            log_hint "$h"
        done
        echo ""
    fi
    
    # Find related files
    local basename="${file##*/}"
    local name="${basename%.*}"
    local dir=$(dirname "$file")
    
    log_info "Related files:"
    
    # Test file
    for test_file in "$dir/$name.test.tsx" "$dir/$name.test.ts" "$dir/__tests__/$name.test.tsx"; do
        if [ -f "$test_file" ]; then
            log_item "Tests: $test_file"
        fi
    done
    
    # Types file
    if [ -f "$dir/$name.types.ts" ]; then
        log_item "Types: $dir/$name.types.ts"
    fi
    
    # Stories file (Storybook)
    if [ -f "$dir/$name.stories.tsx" ]; then
        log_item "Stories: $dir/$name.stories.tsx"
    fi
    
    echo ""
    
    # Output JSON suggestions
    log_info "Suggested context for prp.json:"
    echo ""
    echo "  \"context\": {"
    echo "    \"files\": [\"$file\"],"
    echo "    \"hints\": ["
    local first=true
    for h in "${hints[@]}"; do
        if [ "$first" = true ]; then
            echo "      \"$h\""
            first=false
        else
            echo "      ,\"$h\""
        fi
    done
    echo "    ]"
    echo "  }"
    echo ""
}

analyze_api_route() {
    local file="$1"
    local hints=()
    local patterns=()
    
    log_info "Analyzing API route: $file"
    echo ""
    
    # Check for patterns
    if grep -q "NextRequest\|NextResponse" "$file" 2>/dev/null; then
        patterns+=("Next.js App Router API")
        hints+=("Use NextRequest/NextResponse pattern")
    fi
    
    if grep -q "export async function GET\|POST\|PUT\|DELETE\|PATCH" "$file" 2>/dev/null; then
        patterns+=("Route handlers")
    fi
    
    if grep -q "zod\|z\." "$file" 2>/dev/null; then
        patterns+=("Zod validation")
        hints+=("Validate request body with zod")
    fi
    
    if grep -q "try.*catch" "$file" 2>/dev/null; then
        patterns+=("Error handling with try/catch")
        hints+=("Wrap in try/catch and return proper error responses")
    fi
    
    if grep -q "prisma\|db\." "$file" 2>/dev/null; then
        patterns+=("Database operations")
    fi
    
    # Display results
    if [ ${#patterns[@]} -gt 0 ]; then
        log_info "Patterns detected:"
        for p in "${patterns[@]}"; do
            log_item "$p"
        done
        echo ""
    fi
    
    if [ ${#hints[@]} -gt 0 ]; then
        log_info "Suggested hints:"
        for h in "${hints[@]}"; do
            log_hint "$h"
        done
        echo ""
    fi
}

# ============================================================================
# Main Analyzer
# ============================================================================

run_analyzer() {
    local target="$1"
    
    if [ ! -f "$target" ]; then
        echo -e "${RED}[✗]${NC} File not found: $target"
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔬 Saci Analyzer - Pattern Detection${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    case "$target" in
        *.tsx|*.jsx)
            analyze_tsx_jsx "$target"
            ;;
        */api/*)
            analyze_api_route "$target"
            ;;
        *.ts|*.js)
            # Generic TypeScript/JavaScript analysis
            analyze_tsx_jsx "$target"
            ;;
        *)
            log_info "Unsupported file type: $target"
            ;;
    esac
    
    log_success "Analysis complete!"
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ]; then
        echo "Usage: analyzer.sh <file>"
        exit 1
    fi
    run_analyzer "$@"
fi
