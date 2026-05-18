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

_header "Setting Kitty as Default Terminal"
_log INFO "Installing xdg-terminal-exec..."
paru -S --needed --noconfirm xdg-terminal-exec
_log INFO "Configuring defaults list..."
mkdir -p ~/.config
echo "kitty.desktop" > ~/.config/xdg-terminals.list
_log SUCCESS "Kitty set as default terminal successfully."