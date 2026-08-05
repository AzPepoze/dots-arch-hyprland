#!/usr/bin/env bash
# Restore the active Hyprland instance after a system suspend.  This script is
# called by hypridle; it neither starts nor stops any session component.
set -u

readonly TAG="hypr-resume"

log() {
    if command -v systemd-cat >/dev/null 2>&1; then
        printf '%s\n' "$*" | systemd-cat --identifier="$TAG" --priority=warning
    else
        printf '%s: %s\n' "$TAG" "$*" >&2
    fi
}

if ! command -v hyprctl >/dev/null 2>&1; then
    log "hyprctl is unavailable; cannot restore displays"
    exit 0
fi

# Avoid two overlapping wake handlers when a lid event and a sleep event land
# close together.  The lock is released automatically when this script exits.
if command -v flock >/dev/null 2>&1; then
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-resume.lock"
    flock -n 9 || exit 0
fi

ready=false
for _ in {1..10}; do
    if hyprctl monitors >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 0.2
done

if [ "$ready" != true ]; then
    log "Hyprland IPC was unavailable for two seconds after resume"
    exit 0
fi

# This configuration uses the current Hyprland Lua dispatcher syntax.  Keep a
# legacy fallback for older Arch/CachyOS Hyprland packages rather than mixing
# syntaxes in hypridle itself.
if ! hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1; then
    if ! hyprctl dispatch dpms on >/dev/null 2>&1; then
        log "could not re-enable DPMS after resume"
    fi
fi

# Renderer reload is intentionally best-effort: older Hyprland releases do
# not expose this dispatcher, while supported current releases do.
if ! hyprctl dispatch 'hl.dsp.force_renderer_reload()' >/dev/null 2>&1; then
    log "renderer reload dispatcher is unavailable or failed"
fi
