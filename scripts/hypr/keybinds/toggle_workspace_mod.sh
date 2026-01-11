#!/usr/bin/env bash

# Paths to potential config files
CONFIG_REPO="$HOME/dots-arch-hyprland/dots/base/home/config/hypr/hyprland/keybinds.conf"
CONFIG_ACTIVE="$HOME/.config/hypr/hyprland/keybinds.conf"

# Function to toggle modifier in a file
toggle_mod() {
    local file="$1"
    if [ -f "$file" ]; then
        local current_mod=$(grep "^\$workspace =" "$file" | cut -d' ' -f3)
        if [ "$current_mod" = "Alt" ]; then
            sed -i "s/^\$workspace = Alt/\$workspace = Super/" "$file"
            echo "Super"
        else
            sed -i "s/^\$workspace = Super/\$workspace = Alt/" "$file"
            echo "Alt"
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