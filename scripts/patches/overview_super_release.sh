#!/bin/bash

# Stops Super+<key> from closing panels on Super release.
# Removes the searchToggleRelease onReleased handler, so a bare Super press
# no longer toggles the overview. Also sets superReleaseMightTrigger = false
# in the panel shortcuts. Safe to run more than once.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$DIR/../.."
source "$PROJECT_ROOT/scripts/install_modules/helpers.sh"

QS_DIR="${QS_DIR:-$HOME/.config/quickshell/end4-pC}"
OVERVIEW_FILE="$QS_DIR/modules/ii/overview/Overview.qml"
FLAG_LINE='            GlobalStates.superReleaseMightTrigger = false;'
PANEL_SHORTCUTS=(overviewWorkspacesToggle overviewClipboardToggle overviewEmojiToggle)

# Adds FLAG_LINE as the first line of the named shortcut's onPressed handler.
add_flag_to_shortcut() {
    local name="$1"
    local tmp_file="$OVERVIEW_FILE.tmp"

    awk -v name="$name" -v flag="$FLAG_LINE" '
        pending {
            pending = 0
            if ($0 !~ /superReleaseMightTrigger/) print flag
        }
        index($0, "name: \"" name "\"") { in_block = 1 }
        in_block && /onPressed: \{/ {
            in_block = 0
            pending = 1
        }
        { print }
    ' "$OVERVIEW_FILE" > "$tmp_file" && mv "$tmp_file" "$OVERVIEW_FILE"
}

if [ ! -f "$OVERVIEW_FILE" ]; then
    _log WARN "Overview.qml not found at $OVERVIEW_FILE. Skipping."
    exit 0
fi

# Deletes the onReleased handler of the searchToggleRelease shortcut.
remove_release_toggle() {
    local tmp_file="$OVERVIEW_FILE.tmp"

    awk '
        index($0, "name: \"searchToggleRelease\"") { in_block = 1 }
        /^    }$/ { in_block = 0 }
        in_block && /onReleased: \{/ { skipping = 1 }
        skipping {
            if ($0 ~ /^        }$/) skipping = 0
            next
        }
        { print }
    ' "$OVERVIEW_FILE" > "$tmp_file" && mv "$tmp_file" "$OVERVIEW_FILE"
}

before=$(md5sum < "$OVERVIEW_FILE")
for name in "${PANEL_SHORTCUTS[@]}"; do
    add_flag_to_shortcut "$name"
done
remove_release_toggle

if [ "$before" == "$(md5sum < "$OVERVIEW_FILE")" ]; then
    _log INFO "Overview.qml already patched."
else
    _log SUCCESS "Patched Overview.qml. Restart quickshell to apply."
fi
