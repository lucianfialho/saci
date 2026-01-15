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
echo -e "${BLUE}  🔥 Saci Installer${NC}"
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

echo -e "${BLUE}[1/4]${NC} Cloning Saci..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/saci" 2>/dev/null

echo -e "${BLUE}[2/4]${NC} Installing files..."

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

# Copy files
cp "$TMP_DIR/saci/lib/"*.sh "$SACI_LIB_DIR/lib/"
cp "$TMP_DIR/saci/templates/"*.md "$SACI_LIB_DIR/templates/" 2>/dev/null || true
cp "$TMP_DIR/saci/templates/"*.json "$SACI_LIB_DIR/templates/" 2>/dev/null || true
cp "$TMP_DIR/saci/saci.sh" "$SACI_LIB_DIR/saci"

# Update SCRIPT_DIR in installed script
sed -i.bak "s|SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")\" && pwd)\"|SCRIPT_DIR=\"$SACI_LIB_DIR\"|g" "$SACI_LIB_DIR/saci"
rm -f "$SACI_LIB_DIR/saci.bak"

echo -e "${BLUE}[3/4]${NC} Installing Claude Code skills..."

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_SKILLS_DIR"
cp -r "$TMP_DIR/saci/templates/skills/"* "$CLAUDE_SKILLS_DIR/"

mkdir -p "$CLAUDE_HOOKS_DIR"
if [ -f "$TMP_DIR/saci/templates/hooks/scripts/safety-check.py" ]; then
    cp "$TMP_DIR/saci/templates/hooks/scripts/safety-check.py" "$CLAUDE_HOOKS_DIR/"
    chmod +x "$CLAUDE_HOOKS_DIR/safety-check.py"
fi

# Configure hooks
mkdir -p "$CLAUDE_DIR"
SACI_HOOKS_FILE="$TMP_DIR/saci/templates/hooks/hooks.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
    tmp_settings=$(mktemp)
    jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$SACI_HOOKS_FILE" > "$tmp_settings"
    mv "$tmp_settings" "$CLAUDE_SETTINGS"
else
    cp "$SACI_HOOKS_FILE" "$CLAUDE_SETTINGS"
fi

echo -e "${BLUE}[4/4]${NC} Creating symlink..."

rm -f "$INSTALL_DIR/saci"
ln -s "$SACI_LIB_DIR/saci" "$INSTALL_DIR/saci"
chmod +x "$INSTALL_DIR/saci"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Saci installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Usage:"
echo "  cd your-project"
echo "  saci scan      # Detect stack"
echo "  saci init      # Create PRP"
echo "  saci run       # Execute loop"
echo ""

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]]; then
    echo -e "${YELLOW}⚠️  Add ~/.local/bin to your PATH:${NC}"
    echo "  export PATH=\$PATH:\$HOME/.local/bin"
    echo ""
fi
