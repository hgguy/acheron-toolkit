#!/bin/bash
# Acheron Toolkit Installer - Portable, no hardcoded paths

set -euo pipefail

# Determine install directory from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="${ACHERON_TOOLKIT_DIR:-$HOME/.local/share/acheron-toolkit}"
BIN_DIR="${ACHERON_BIN_DIR:-$HOME/.local/bin}"

echo "[*] Installing Acheron Toolkit to $TOOLKIT_DIR"

mkdir -p "$TOOLKIT_DIR/templates"
mkdir -p "$(dirname "$BIN_DIR")"

# Copy all toolkit files
cp -r "$SCRIPT_DIR"/* "$TOOLKIT_DIR/" 2>/dev/null || true

# Remove files that shouldn't be installed
rm -f "$TOOLKIT_DIR/installer.sh"
rm -f "$TOOLKIT_DIR/README.md"
rm -f "$TOOLKIT_DIR/LICENSE"
rm -f "$TOOLKIT_DIR/.gitignore"
rm -rf "$TOOLKIT_DIR/.github"
rm -f "$TOOLKIT_DIR/*.md"
rm -f "$TOOLKIT_DIR/*.exe"
rm -f "$TOOLKIT_DIR/*.c"
rm -f "$TOOLKIT_DIR/*.rb"

# Make scripts executable
chmod +x "$TOOLKIT_DIR"/*.sh

# Create global command
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/acheron" << EOF
#!/bin/bash
# Acheron Payload Toolkit launcher
export ACHERON_TOOLKIT_DIR="${ACHERON_TOOLKIT_DIR:-$HOME/.local/share/acheron-toolkit}"
exec "\$ACHERON_TOOLKIT_DIR/toolkit.sh" "\$@"
EOF
chmod +x "$BIN_DIR/acheron"

# Ensure bin dir is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "[*] Adding $BIN_DIR to PATH"
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi
    if [ -n "$SHELL_RC" ] && ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        echo "[*] Added $BIN_DIR to PATH in $SHELL_RC"
    fi
done

echo "[+] Installed to $TOOLKIT_DIR"
echo "[*] Global command: acheron (run 'source ~/.bashrc' or restart shell)"
echo "[*] Override install dir: export ACHERON_TOOLKIT_DIR=/custom/path"
echo "[*] Override bin dir: export ACHERON_BIN_DIR=/custom/bin"