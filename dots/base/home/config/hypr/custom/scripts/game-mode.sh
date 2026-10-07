#!/usr/bin/env bash
# Game mode toggle: max FPS, zero eye-candy, no desktop widgets.
#
# ON:  Hyprland blur/anim/shadow/gaps/rounding off, tearing on, full opacity;
#      shell transparency to 0, desktop widgets + visualizer off.
# OFF: shell values restored from the backup file, then `hyprctl reload`
#      re-sources the lua config and brings every Hyprland value back exactly
#      as the config files define it (rounding 18, gaps 4/5, blur on, ...).
#
# The stock shell GameMode toggle only edited the unsourced shellOverrides
# file, so the fork's GameModeToggle calls this script (also bound to SUPER+G).
# Hyprland is driven via `hyprctl eval` (plain `keyword` is rejected by the
# lua config). ii config.json is edited with perl so its formatting is intact.
set -u
BACKUP="$HOME/.config/illogical-impulse/.gamemode-backup"
CONFIG="$HOME/.config/illogical-impulse/config.json"
WIDGETS="todo notes timers calendar visualizer"

eval_set() { hyprctl eval "hl.config({ $1 })" >/dev/null; }

cfg_get() { # $1=section $2=key
    perl -0777 -ne "print \$1 if /\"$1\":\s*\{[^}]*?\"$2\":\s*([0-9.]+|true|false)/s" "$CONFIG" | head -n1
}

cfg_set() { # $1=section $2=key $3=value
    perl -0777 -pi -e "s/(\"$1\":\s*\{[^}]*?\"$2\":\s*)([0-9.]+|true|false)/\${1}$3/sg" "$CONFIG"
}

widget_get() { # $1=widget
    perl -0777 -ne "print \$1 if /\"$1\":\s*\{[^}]*?\"enable\":\s*(true|false)/s" "$CONFIG" | head -n1
}

widget_set() { # $1=widget $2=true|false
    perl -0777 -pi -e "s/(\"$1\":\s*\{[^}]*?\"enable\":\s*)(true|false)/\${1}$2/sg" "$CONFIG"
}

game_on() {
    [ -f "$BACKUP" ] && { notify-send -a "Shell" "Game mode" "Already on"; exit 0; }
    {
        echo "backgroundTransparency=$(cfg_get transparency backgroundTransparency)"
        echo "contentTransparency=$(cfg_get transparency contentTransparency)"
        for w in $WIDGETS; do echo "widget:$w=$(widget_get "$w")"; done
    } > "$BACKUP"

    eval_set "animations = { enabled = false }"
    eval_set "decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0, active_opacity = 1, inactive_opacity = 1 }"
    eval_set "general = { gaps_in = 0, gaps_out = 0, allow_tearing = true }"
    # Every window class fully opaque (overrides per-app opacity rules in rules.lua,
    # since later matching rules win). `hyprctl reload` on game_off clears these.
    hyprctl eval 'hl.window_rule({match = {class = ".*"}, opacity = "1 1 1.0"})' >/dev/null
    hyprctl eval 'hl.window_rule({match = {class = ".*"}, no_blur = false})' >/dev/null
    eval_set "general = { allow_tearing = true }"

    cfg_set transparency backgroundTransparency 0
    cfg_set transparency contentTransparency 0
    for w in $WIDGETS; do widget_set "$w" false; done

    notify-send -a "Shell" "Game mode ON" "Full opacity, no blur, no widgets"
}

game_off() {
    [ -f "$BACKUP" ] || { notify-send -a "Shell" "Game mode" "Not on"; exit 0; }
    while IFS='=' read -r key val; do
        case "$key" in
            widget:*) [ -n "$val" ] && widget_set "${key#widget:}" "$val" ;;
            backgroundTransparency) [ -n "$val" ] && cfg_set transparency backgroundTransparency "$val" ;;
            contentTransparency) [ -n "$val" ] && cfg_set transparency contentTransparency "$val" ;;
        esac
    done < "$BACKUP"
    rm -f "$BACKUP"

    hyprctl reload >/dev/null 2>&1
    notify-send -a "Shell" "Game mode OFF" "Settings restored"
}

if [ -f "$BACKUP" ]; then game_off; else game_on; fi
