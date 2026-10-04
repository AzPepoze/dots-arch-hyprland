#!/usr/bin/env bash

# Toggle the quickshell/ii bar auto-hide setting.
# Quickshell watches this config file (Config.qml) and applies changes live,
# so no shell restart is needed.

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    notify-send -t 2000 -a "Hyprland" "Bar Auto-hide" "Config not found: $CONFIG_FILE" -i "dialog-error"
    exit 1
fi

# Read current state (default to disabled if the key is missing)
CURRENT_VALUE=$(jq -r '.bar.autoHide.enable // false' "$CONFIG_FILE")

if [ "$CURRENT_VALUE" = "true" ]; then
    NEW_VALUE="false"
    STATE="Disabled"
else
    NEW_VALUE="true"
    STATE="Enabled"
fi

# Atomic write so quickshell never reads a half-written file
TMP_FILE=$(mktemp)
if jq --argjson value "$NEW_VALUE" '.bar.autoHide.enable = $value' "$CONFIG_FILE" > "$TMP_FILE"; then
    mv "$TMP_FILE" "$CONFIG_FILE"
else
    rm -f "$TMP_FILE"
    notify-send -t 2000 -a "Hyprland" "Bar Auto-hide" "Failed to update config" -i "dialog-error"
    exit 1
fi

notify-send -t 2000 -a "Hyprland" "Bar Auto-hide" "$STATE" -i "shelf_auto_hide"
