#!/usr/bin/env bash
# Collect focused suspend/resume diagnostics without printing environment data.
set -u

section() {
    printf '\n===== %s =====\n' "$1"
}

run() {
    "$@" 2>&1 || true
}

filter_log() {
    grep -Ei 'drm|amdgpu|i915|(^|[^[:alnum:]])xe([^[:alnum:]]|$)|nvidia|suspend|resume|hyprland|aquamarine|hypridle|hyprlock|portal' || true
}

section "Hyprland version"
run hyprctl version

section "Hyprland instances"
run hyprctl instances

section "Hyprland monitors"
run hyprctl monitors all

section "Failed user units"
run systemctl --user --failed

section "hypridle user-unit status (informational)"
run systemctl --user status hypridle.service

section "Kernel log, last 15 minutes (filtered)"
journalctl -b -k --since "15 minutes ago" 2>&1 | filter_log

section "User journal, last 15 minutes (filtered)"
journalctl --user -b --since "15 minutes ago" 2>&1 | filter_log
