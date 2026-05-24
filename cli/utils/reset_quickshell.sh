#!/bin/bash
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"

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

_header "Resetting QuickShell Settings"
read -p "Are you sure you want to reset all Illogical Impulse QuickShell settings? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
	_log INFO "Reset cancelled."
	exit 0
fi

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
	_log INFO "Deleting configuration file at $CONFIG_FILE..."
	rm -f "$CONFIG_FILE"
	_log SUCCESS "Configuration file deleted successfully."
else
	_log WARN "No configuration file found at $CONFIG_FILE."
fi

bash "$CURRENT_SCRIPT_DIR/force_reload_quickshell.sh"
