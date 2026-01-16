#!/bin/bash
# ============================================================================
# Saci Installer
# Installs Saci to ~/.local/bin or /usr/local/bin
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🌪️ Saci Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect install directory
if [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
else
    echo "Creating $HOME/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
fi

echo -e "${BLUE}[1/5]${NC} Installing Saci core..."

# Create directory for lib and templates
SACI_LIB_DIR="$HOME/.local/share/saci"
mkdir -p "$SACI_LIB_DIR/lib"
mkdir -p "$SACI_LIB_DIR/templates"

# Copy core files
cp lib/*.sh "$SACI_LIB_DIR/lib/"
cp templates/*.md "$SACI_LIB_DIR/templates/" 2>/dev/null || true
cp templates/*.json "$SACI_LIB_DIR/templates/" 2>/dev/null || true

# Copy main script
cp saci.sh "$SACI_LIB_DIR/saci"

# Update saci.sh to point to the correct lib dir
sed -i.bak "s|SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")\" && pwd)\"|SCRIPT_DIR=\"$SACI_LIB_DIR\"|g" "$SACI_LIB_DIR/saci"
rm -f "$SACI_LIB_DIR/saci.bak"

echo -e "${BLUE}[2/5]${NC} Installing intelligent hooks system..."

# Copy .saci directory with intelligent hooks
mkdir -p "$SACI_LIB_DIR/.saci/hooks"
if [ -d ".saci/hooks" ]; then
    cp .saci/hooks/*.py "$SACI_LIB_DIR/.saci/hooks/" 2>/dev/null || true
    cp .saci/hooks/*.sh "$SACI_LIB_DIR/.saci/hooks/" 2>/dev/null || true
    chmod +x "$SACI_LIB_DIR/.saci/hooks/"* 2>/dev/null || true
    echo "  ✓ 4 intelligent hooks installed"
else
    echo "  ⚠️  .saci/hooks not found (optional)"
fi

# Copy test scripts and documentation
cp .saci/*.sh "$SACI_LIB_DIR/.saci/" 2>/dev/null || true
cp .saci/*.md "$SACI_LIB_DIR/.saci/" 2>/dev/null || true
chmod +x "$SACI_LIB_DIR/.saci/"*.sh 2>/dev/null || true

echo -e "${BLUE}[3/5]${NC} Installing Claude Code skills & agents..."

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
CLAUDE_DOCS_DIR="$CLAUDE_DIR/docs"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

# Install skills
mkdir -p "$CLAUDE_SKILLS_DIR"
cp -r templates/skills/* "$CLAUDE_SKILLS_DIR/" 2>/dev/null || true
echo "  ✓ Skills installed"

# Install agents
mkdir -p "$CLAUDE_AGENTS_DIR"
if [ -d ".claude/agents" ]; then
    cp .claude/agents/*.md "$CLAUDE_AGENTS_DIR/" 2>/dev/null || true
    echo "  ✓ Agents installed (environment-fixer)"
fi

# Install documentation
mkdir -p "$CLAUDE_DOCS_DIR"
if [ -d ".claude/docs" ]; then
    cp .claude/docs/*.md "$CLAUDE_DOCS_DIR/" 2>/dev/null || true
    echo "  ✓ Claude Code knowledge base installed"
fi

echo -e "${BLUE}[4/5]${NC} Configuring hooks..."

# Install safety hook script
mkdir -p "$CLAUDE_HOOKS_DIR"
if [ -f "templates/hooks/scripts/safety-check.py" ]; then
    cp templates/hooks/scripts/safety-check.py "$CLAUDE_HOOKS_DIR/"
    chmod +x "$CLAUDE_HOOKS_DIR/safety-check.py"
    echo "  ✓ Safety hook installed"
fi

# Configure settings.json with all hooks
mkdir -p "$CLAUDE_DIR"

if [ -f ".claude/settings.json" ]; then
    # Use new settings.json with intelligent hooks
    if [ -f "$CLAUDE_SETTINGS" ]; then
        echo "  Backing up existing settings.json..."
        cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"

        if command -v jq >/dev/null 2>&1; then
            # Merge hooks from new settings with existing settings
            tmp_settings=$(mktemp)
            jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" ".claude/settings.json" > "$tmp_settings"
            mv "$tmp_settings" "$CLAUDE_SETTINGS"
            echo "  ✓ Settings merged (backup saved as settings.json.backup)"
        else
            echo -e "  ${YELLOW}⚠️  jq not found - copying new settings${NC}"
            cp ".claude/settings.json" "$CLAUDE_SETTINGS"
        fi
    else
        cp ".claude/settings.json" "$CLAUDE_SETTINGS"
        echo "  ✓ Settings.json created with intelligent hooks"
    fi
elif [ -f "templates/hooks/hooks.json" ]; then
    # Fallback to old hooks.json if new settings not available
    if [ -f "$CLAUDE_SETTINGS" ]; then
        if command -v jq >/dev/null 2>&1; then
            tmp_settings=$(mktemp)
            jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "templates/hooks/hooks.json" > "$tmp_settings"
            mv "$tmp_settings" "$CLAUDE_SETTINGS"
        fi
    else
        cp "templates/hooks/hooks.json" "$CLAUDE_SETTINGS"
    fi
    echo "  ✓ Basic hooks configured"
fi

echo -e "${BLUE}[5/5]${NC} Creating symlink..."

# Symlink to bin
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
echo "  saci scan      # Detect stack"
echo "  saci init      # Create PRP"
echo "  saci jump      # Execute autonomous loop"
echo ""
echo "Test hooks:"
echo "  ~/.local/share/saci/.saci/test-hooks.sh"
echo ""

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]]; then
    echo -e "${YELLOW}⚠️  Add ~/.local/bin to your PATH:${NC}"
    echo "  export PATH=\$PATH:\$HOME/.local/bin"
    echo ""
fi
