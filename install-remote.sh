#!/bin/bash
# ============================================================================
# Saci Remote Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/lucianfialho/saci/main/install-remote.sh | bash
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_URL="https://github.com/lucianfialho/saci"
BRANCH="${SACI_BRANCH:-main}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🌪️ Saci Remote Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check dependencies
check_deps() {
    local missing=()
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[✗] Missing dependencies: ${missing[*]}${NC}"
        echo ""
        echo "Install them first:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install ${missing[*]}"
        else
            echo "  sudo apt install ${missing[*]}"
        fi
        exit 1
    fi
}

check_deps

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo -e "${BLUE}[1/6]${NC} Cloning Saci..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/saci" 2>/dev/null

echo -e "${BLUE}[2/6]${NC} Installing Saci core..."

# Detect install directory
if [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
else
    mkdir -p "$HOME/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
fi

# Create Saci lib directory
SACI_LIB_DIR="$HOME/.local/share/saci"
rm -rf "$SACI_LIB_DIR"
mkdir -p "$SACI_LIB_DIR/lib"
mkdir -p "$SACI_LIB_DIR/templates"

# Copy core files
cp "$TMP_DIR/saci/lib/"*.sh "$SACI_LIB_DIR/lib/"
cp -r "$TMP_DIR/saci/templates/"* "$SACI_LIB_DIR/templates/"
cp "$TMP_DIR/saci/saci.sh" "$SACI_LIB_DIR/saci"

# Update SCRIPT_DIR in installed script
sed -i.bak "s|SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")\" && pwd)\"|SCRIPT_DIR=\"$SACI_LIB_DIR\"|g" "$SACI_LIB_DIR/saci"
rm -f "$SACI_LIB_DIR/saci.bak"

echo -e "${BLUE}[3/6]${NC} Installing intelligent hooks system..."

# Copy .saci directory with intelligent hooks
mkdir -p "$SACI_LIB_DIR/.saci/hooks"
if [ -d "$TMP_DIR/saci/.saci/hooks" ]; then
    cp "$TMP_DIR/saci/.saci/hooks/"*.py "$SACI_LIB_DIR/.saci/hooks/" 2>/dev/null || true
    cp "$TMP_DIR/saci/.saci/hooks/"*.sh "$SACI_LIB_DIR/.saci/hooks/" 2>/dev/null || true
    chmod +x "$SACI_LIB_DIR/.saci/hooks/"* 2>/dev/null || true
    echo "  ✓ 4 intelligent hooks installed"
else
    echo "  ⚠️  Intelligent hooks not found (using older version)"
fi

# Copy test scripts and documentation
cp "$TMP_DIR/saci/.saci/"*.sh "$SACI_LIB_DIR/.saci/" 2>/dev/null || true
cp "$TMP_DIR/saci/.saci/"*.md "$SACI_LIB_DIR/.saci/" 2>/dev/null || true
chmod +x "$SACI_LIB_DIR/.saci/"*.sh 2>/dev/null || true

echo -e "${BLUE}[4/6]${NC} Installing Claude Code skills & agents..."

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
CLAUDE_DOCS_DIR="$CLAUDE_DIR/docs"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

# Install skills
mkdir -p "$CLAUDE_SKILLS_DIR"
cp -r "$TMP_DIR/saci/templates/skills/"* "$CLAUDE_SKILLS_DIR/" 2>/dev/null || true
echo "  ✓ Skills installed"

# Install agents
mkdir -p "$CLAUDE_AGENTS_DIR"
if [ -d "$TMP_DIR/saci/.claude/agents" ]; then
    cp "$TMP_DIR/saci/.claude/agents/"*.md "$CLAUDE_AGENTS_DIR/" 2>/dev/null || true
    echo "  ✓ Agents installed (environment-fixer)"
fi

# Install documentation
mkdir -p "$CLAUDE_DOCS_DIR"
if [ -d "$TMP_DIR/saci/.claude/docs" ]; then
    cp "$TMP_DIR/saci/.claude/docs/"*.md "$CLAUDE_DOCS_DIR/" 2>/dev/null || true
    echo "  ✓ Claude Code knowledge base installed"
fi

echo -e "${BLUE}[5/6]${NC} Configuring hooks..."

# Install safety hook script
mkdir -p "$CLAUDE_HOOKS_DIR"
if [ -f "$TMP_DIR/saci/templates/hooks/scripts/safety-check.py" ]; then
    cp "$TMP_DIR/saci/templates/hooks/scripts/safety-check.py" "$CLAUDE_HOOKS_DIR/"
    chmod +x "$CLAUDE_HOOKS_DIR/safety-check.py"
    echo "  ✓ Safety hook installed"
fi

# Configure settings.json with all hooks
mkdir -p "$CLAUDE_DIR"

if [ -f "$TMP_DIR/saci/.claude/settings.json" ]; then
    # Use new settings.json with intelligent hooks
    if [ -f "$CLAUDE_SETTINGS" ]; then
        echo "  Backing up existing settings.json..."
        cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"

        # Merge hooks from new settings with existing settings
        tmp_settings=$(mktemp)
        jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$TMP_DIR/saci/.claude/settings.json" > "$tmp_settings"
        mv "$tmp_settings" "$CLAUDE_SETTINGS"
        echo "  ✓ Settings merged (backup saved as settings.json.backup)"
    else
        cp "$TMP_DIR/saci/.claude/settings.json" "$CLAUDE_SETTINGS"
        echo "  ✓ Settings.json created with intelligent hooks"
    fi
elif [ -f "$TMP_DIR/saci/templates/hooks/hooks.json" ]; then
    # Fallback to old hooks.json if new settings not available
    if [ -f "$CLAUDE_SETTINGS" ]; then
        tmp_settings=$(mktemp)
        jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$TMP_DIR/saci/templates/hooks/hooks.json" > "$tmp_settings"
        mv "$tmp_settings" "$CLAUDE_SETTINGS"
    else
        cp "$TMP_DIR/saci/templates/hooks/hooks.json" "$CLAUDE_SETTINGS"
    fi
    echo "  ✓ Basic hooks configured"
fi

echo -e "${BLUE}[6/6]${NC} Creating symlink..."

rm -f "$INSTALL_DIR/saci"
ln -s "$SACI_LIB_DIR/saci" "$INSTALL_DIR/saci"
chmod +x "$INSTALL_DIR/saci"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Saci installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Installed components:"
echo "  ✓ Saci core (saci.sh, lib, templates)"
echo "  ✓ 4 intelligent hooks (PreToolUse, PostToolUse, Stop, UserPromptSubmit)"
echo "  ✓ Debug mode framework (environment-fixer subagent)"
echo "  ✓ Claude Code knowledge base (11 docs)"
echo "  ✓ Skills (prp, default.md)"
echo ""
echo "Usage:"
echo "  cd your-project"
echo "  saci scan      # Detect stack & generate PRP"
echo "  saci init      # Create PRP interactively"
echo "  saci jump      # Execute autonomous loop"
echo ""
echo "Test hooks:"
echo "  ~/.local/share/saci/.saci/test-hooks.sh"
echo ""
echo "Documentation:"
echo "  ~/.claude/docs/saci-analysis.md - Complete system analysis"
echo "  ~/.local/share/saci/.saci/README.md - Hooks overview"
echo ""

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]]; then
    echo -e "${YELLOW}⚠️  Add ~/.local/bin to your PATH:${NC}"
    echo "  export PATH=\$PATH:\$HOME/.local/bin"
    echo ""
fi
