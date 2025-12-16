#!/bin/bash

#-------------------------------------------------------
# Script to switch keyboard layout and send notification
#-------------------------------------------------------

# Source helper functions
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$DIR/../.."
HELPER_SCRIPT="$PROJECT_ROOT/scripts/install_modules/helpers.sh"
source "$HELPER_SCRIPT"

# รับชื่อ Keyboard ทั้งหมด
KEYBOARDS=$(hyprctl devices -j | jq -r '.keyboards[] | .name')

# สลับ Layout ของแต่ละ Keyboard
for KBD in $KEYBOARDS; do
    hyprctl switchxkblayout "$KBD" next
    echo "Switched keyboard layout for $KBD"
done

# แสดง Notification
CURRENT_LAYOUT=$(hyprctl devices -j | jq -r '.keyboards[0] | .active_keymap')
# notify-send -h string:x-canonical-private-synchronous:hypr-layout -u low "Keyboard Layout" "Changed to $CURRENT_LAYOUT"
# _log SUCCESS "Notification sent: Keyboard layout changed to $CURRENT_LAYOUT"
