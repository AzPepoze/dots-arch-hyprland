#!/usr/bin/env bash

# Paths to potential config files
CONFIG_REPO="$HOME/dots-arch-hyprland/dots/base/home/config/hypr/custom/keybinds.lua"
CONFIG_ACTIVE="$HOME/.config/hypr/custom/keybinds.lua"

# Function to toggle modifier in a file
toggle_mod() {
    local file="$1"
    if [ -f "$file" ]; then
        local current_mod=$(grep "^local mod = " "$file" | cut -d'"' -f2)
        if [ "$current_mod" = "ALT" ] || [ "$current_mod" = "Alt" ]; then
            sed -i 's/^local mod = "[^"]*"/local mod = "SUPER"/' "$file"
            echo "SUPER"
        else
            sed -i 's/^local mod = "[^"]*"/local mod = "ALT"/' "$file"
            echo "ALT"
        fi
    fi
}

# Toggle in both (if they exist)
NEW_MOD_REPO=$(toggle_mod "$CONFIG_REPO")
NEW_MOD_ACTIVE=$(toggle_mod "$CONFIG_ACTIVE")

# Determine which one to report (prefer active)
FINAL_MOD="${NEW_MOD_ACTIVE:-$NEW_MOD_REPO}"

if [ -n "$FINAL_MOD" ]; then
    notify-send -t 2000 -a "Hyprland" "Workspace Modifier" "Switched to ${FINAL_MOD^^}" -i "keyboard"
    hyprctl reload
fi