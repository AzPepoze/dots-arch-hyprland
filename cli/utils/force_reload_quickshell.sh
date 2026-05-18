#!/bin/bash
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"

# Source helper functions
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    _log() {
        local type="$1"; shift
        local msg="$*"
        echo "[$type] $msg"
    }
fi

_header "Force Reloading QuickShell"
_log INFO "Stopping running QuickShell processes..."
quickshell -c ii kill 2>/dev/null || true
sleep 0.5
_log INFO "Starting new QuickShell instance..."
nohup quickshell -c ii > /dev/null 2>&1 &
_log SUCCESS "QuickShell reload triggered successfully."