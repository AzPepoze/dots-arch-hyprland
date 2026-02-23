#!/usr/bin/env bash

# Get the current value of follow_mouse
# Input: 0 (Manual), 1 (Hover), 2 (Position), 3 (Position & Hover)
# We toggle between 0 and 1 for simple hover to focus toggle
CURRENT_VALUE=$(hyprctl getoption input:follow_mouse -j | jq '.int')

if [ "$CURRENT_VALUE" -eq 1 ]; then
    hyprctl keyword input:follow_mouse 0
    notify-send -t 2000 -a "Hyprland" "Hover to Focus" "Disabled" -i "mouse"
else
    hyprctl keyword input:follow_mouse 1
    notify-send -t 2000 -a "Hyprland" "Hover to Focus" "Enabled" -i "mouse"
fi
