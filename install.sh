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

echo -e "${BLUE}🔥 Saci Installer${NC}"

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
cp templates/* "$SACI_LIB_DIR/templates/"
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
