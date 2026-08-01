#!/bin/bash
# Acheron Toolkit Installer - Portable, no hardcoded paths

set -euo pipefail

# Determine install directory from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="${ACHERON_TOOLKIT_DIR:-$HOME/.local/share/acheron-toolkit}"
BIN_DIR="${ACHERON_BIN_DIR:-$HOME/.local/bin}"

echo "[*] Installing Acheron Toolkit to $TOOLKIT_DIR"

mkdir -p "$TOOLKIT_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$TOOLKIT_DIR/bin"

# Copy only necessary files (not hidden, not build artifacts)
cp "$SCRIPT_DIR/toolkit.sh" "$TOOLKIT_DIR/"
cp "$SCRIPT_DIR/acherongen.sh" "$TOOLKIT_DIR/"
cp "$SCRIPT_DIR/listener_gen.sh" "$TOOLKIT_DIR/"
cp -r "$SCRIPT_DIR/templates" "$TOOLKIT_DIR/" 2>/dev/null || true

# Make scripts executable
chmod +x "$TOOLKIT_DIR"/*.sh

# Create global command - use literal heredoc to avoid expansion at install time
cat > "$BIN_DIR/acheron" << 'EOF'
#!/bin/bash
# Acheron Payload Toolkit launcher
export ACHERON_TOOLKIT_DIR="${ACHERON_TOOLKIT_DIR:-$HOME/.local/share/acheron-toolkit}"
exec "$ACHERON_TOOLKIT_DIR/toolkit.sh" "$@"
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
fi

# Install Metasploit module to USER directory (not system) - FIX #12
MODULE_SOURCE="$SCRIPT_DIR/bypassuac_method59.rb"
MODULE_DEST="$HOME/.msf4/modules/post/windows/escalate/bypassuac_method59.rb"

mkdir -p "$(dirname "$MODULE_DEST")"

if [ -f "$MODULE_SOURCE" ]; then
    echo "[*] Installing Metasploit module to $MODULE_DEST"
    if cp "$MODULE_SOURCE" "$MODULE_DEST" && chmod 644 "$MODULE_DEST"; then
        echo "[+] Metasploit module installed to user directory"
        echo "[*] Run 'reload_all' in msfconsole"
    else
        echo "[!] Failed to install Metasploit module"
    fi
else
    echo "[!] Metasploit module not found at $MODULE_SOURCE"
fi

echo "[+] Installed to $TOOLKIT_DIR"
echo "[*] Global command: acheron (run 'source ~/.bashrc' or restart shell)"
echo "[*] Override install dir: export ACHERON_TOOLKIT_DIR=/custom/path"
echo "[*] Override bin dir: export ACHERON_BIN_DIR=/custom/bin"
echo "[*] Akagi binary: place at \$ACHERON_TOOLKIT_DIR/bin/akagi.exe or set AKAGI_PATH"
echo "[*] Metasploit module: ~/.msf4/modules/post/windows/escalate/bypassuac_method59.rb"