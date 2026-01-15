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
NC='\033[0m'

echo -e "${BLUE}🌪️ Saci Installer${NC}"

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

echo "Installing to $INSTALL_DIR..."

# Create directory for lib and templates
SACI_LIB_DIR="$HOME/.local/share/saci"
mkdir -p "$SACI_LIB_DIR/lib"
mkdir -p "$SACI_LIB_DIR/templates"

# Copy files
cp lib/*.sh "$SACI_LIB_DIR/lib/"
cp templates/*.md "$SACI_LIB_DIR/templates/" || true
cp templates/*.json "$SACI_LIB_DIR/templates/" || true

# ============================================================================
# Install Native Skills & Hooks (Claude Code)
# ============================================================================

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

echo "Installing Claude Code Skills to $CLAUDE_SKILLS_DIR..."
mkdir -p "$CLAUDE_SKILLS_DIR"
cp -r templates/skills/* "$CLAUDE_SKILLS_DIR/"

echo "Installing Saci safety hook script to $CLAUDE_HOOKS_DIR..."
mkdir -p "$CLAUDE_HOOKS_DIR"
if [ -f "templates/hooks/scripts/safety-check.py" ]; then
    cp templates/hooks/scripts/safety-check.py "$CLAUDE_HOOKS_DIR/"
    chmod +x "$CLAUDE_HOOKS_DIR/safety-check.py"
    echo "  - safety-check.py installed"
fi

echo "Configuring Claude Code hooks..."
mkdir -p "$CLAUDE_DIR"

SACI_HOOKS_FILE="templates/hooks/hooks.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
    echo "Merging Saci hooks into existing settings.json..."
    if command -v jq >/dev/null 2>&1; then
        tmp_settings=$(mktemp)
        jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$SACI_HOOKS_FILE" > "$tmp_settings"
        mv "$tmp_settings" "$CLAUDE_SETTINGS"
        echo "  - Hooks merged successfully"
    else
        echo -e "${RED}⚠️  jq not found! Cannot merge hooks automatically.${NC}"
        echo "Please manually add the contents of $SACI_HOOKS_FILE to $CLAUDE_SETTINGS"
    fi
else
    echo "Creating new settings.json with Saci hooks..."
    cp "$SACI_HOOKS_FILE" "$CLAUDE_SETTINGS"
    echo "  - settings.json created"
fi

cp saci.sh "$SACI_LIB_DIR/saci"

# Update saci.sh to point to the correct lib dir
# We use a sed hack to change the SCRIPT_DIR detection in the installed script
# to point to the installed location
sed -i '' "s|SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE\[0\]}\")\" && pwd)\"|SCRIPT_DIR=\"$SACI_LIB_DIR\"|g" "$SACI_LIB_DIR/saci"

# Symlink to bin
rm -f "$INSTALL_DIR/saci"
ln -s "$SACI_LIB_DIR/saci" "$INSTALL_DIR/saci"
chmod +x "$INSTALL_DIR/saci"

echo -e "${GREEN}✅ Saci installed successfully!${NC}"
echo "Run 'saci' to get started."

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]]; then
    echo -e "${RED}⚠️  Warning: $HOME/.local/bin is not in your PATH.${NC}"
    echo "Add this to your shell config (.zshrc or .bashrc):"
    echo "  export PATH=\$PATH:\$HOME/.local/bin"
fi
