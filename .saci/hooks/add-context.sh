#!/bin/bash
#
# Saci UserPromptSubmit Hook: Auto Context Injection
#
# Automatically injects useful repository context at the start of each
# Claude Code iteration. This helps Claude understand the project state
# without having to search for information.
#
# Context injected:
# - Current git branch
# - Number of uncommitted files
# - Available npm scripts
# - Last npm error (if any)
# - Recent git commits
#
# Output (stdout): Context text that gets added to the prompt
# Exit code: 0 (always allow, just adding context)

# Color codes for better readability (optional, will be stripped by Claude)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "## 🔍 Repository Context"
echo ""

# Git branch and status
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "### Git Status"
    current_branch=$(git branch --show-current 2>/dev/null || echo "detached HEAD")
    echo "- **Branch**: $current_branch"

    uncommitted=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    if [ "$uncommitted" -gt 0 ]; then
        echo "- **Uncommitted changes**: $uncommitted file(s)"
    else
        echo "- **Working tree**: clean"
    fi

    # Recent commits (last 3)
    echo "- **Recent commits**:"
    git log --oneline -3 2>/dev/null | sed 's/^/  - /' || echo "  - No commits yet"

    echo ""
fi

# NPM scripts
if [ -f "package.json" ]; then
    echo "### Available npm Scripts"

    # Extract and list scripts
    scripts=$(npm run 2>&1 | grep "^  " | head -10)

    if [ -n "$scripts" ]; then
        echo "$scripts" | sed 's/^/- /'
    else
        echo "- No scripts defined"
    fi

    echo ""

    # Last npm error (if any)
    echo "### Last npm Error (if any)"
    if [ -d "$HOME/.npm/_logs" ]; then
        last_error=$(find "$HOME/.npm/_logs" -name "*.log" -type f -mtime -1 2>/dev/null | \
                     xargs grep "npm ERR!" 2>/dev/null | tail -1)

        if [ -n "$last_error" ]; then
            echo "⚠️  Recent error found:"
            echo "\`\`\`"
            echo "$last_error" | head -3
            echo "\`\`\`"
        else
            echo "✓ No recent npm errors"
        fi
    else
        echo "✓ No npm log directory"
    fi

    echo ""
fi

# Project type detection
echo "### Project Type"
if [ -f "package.json" ]; then
    # Check for frameworks
    if grep -q '"next"' package.json 2>/dev/null; then
        echo "- **Framework**: Next.js"
    elif grep -q '"react"' package.json 2>/dev/null; then
        echo "- **Framework**: React"
    elif grep -q '"vue"' package.json 2>/dev/null; then
        echo "- **Framework**: Vue.js"
    elif grep -q '"@angular/core"' package.json 2>/dev/null; then
        echo "- **Framework**: Angular"
    fi

    # Check for TypeScript
    if [ -f "tsconfig.json" ]; then
        echo "- **Language**: TypeScript"
    else
        echo "- **Language**: JavaScript"
    fi

    # Check for testing framework
    if grep -q '"jest"' package.json 2>/dev/null; then
        echo "- **Testing**: Jest"
    elif grep -q '"vitest"' package.json 2>/dev/null; then
        echo "- **Testing**: Vitest"
    elif grep -q '"mocha"' package.json 2>/dev/null; then
        echo "- **Testing**: Mocha"
    fi
fi

echo ""
echo "---"
echo ""

# Exit successfully (always allow prompt)
exit 0
