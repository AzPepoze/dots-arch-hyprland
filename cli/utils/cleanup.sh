#!/bin/bash

#-------------------------------------------------------
# Setup & Sourcing
#-------------------------------------------------------
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"

# Source helper functions (MUST be sourced first to get _log)
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    # Fallback logging if helpers are not found
    _log() {
        local type="$1"; shift
        local msg="$*"
        echo "[$type] $msg"
    }
fi

#-------------------------------------------------------
# Cleanup Functions
#-------------------------------------------------------

cleanup_system_packages() {
    _header "Cleaning Up System Packages"
    
    if command -v paru &> /dev/null; then
        _log INFO "Removing orphan packages..."
        yes | paru -c

        _log INFO "Cleaning package cache..."
        _log INFO "Removing leftover parallel download directories in /var/cache/pacman/pkg..."
        sudo find /var/cache/pacman/pkg/ -type d -name "download-*" -exec rm -rf {} + 2>/dev/null || true
        yes | paru -Sccd
    else
        _log WARN "paru command not found. Skipping system package cleanup."
    fi
}

cleanup_flatpak() {
    _header "Cleaning Up Flatpak"
    
    if command -v flatpak &> /dev/null; then
        _log INFO "Removing unused Flatpak runtimes..."
        flatpak uninstall --unused -y
    else
        _log WARN "flatpak command not found. Skipping Flatpak cleanup."
    fi
}

cleanup_journal_logs() {
    _header "Cleaning Up Journal Logs"
    
    _log INFO "Vacuuming journal logs to keep the last 3 days..."
    sudo journalctl --vacuum-time=3d
}

cleanup_coredumps() {
    _header "Cleaning Up Systemd Coredumps"
    
    _log INFO "Removing all coredump files..."
    sudo rm -rf /var/lib/systemd/coredump/*
}

cleanup_npm_cache() {
    _header "Cleaning Up NPM Cache"
    if command -v npm &> /dev/null; then
        _log INFO "Cleaning NPM cache..."
        npm cache clean --force
    fi
}

cleanup_pnpm_cache() {
    _header "Cleaning Up PNPM Cache"
    if command -v pnpm &> /dev/null; then
        _log INFO "Pruning PNPM store..."
        pnpm store prune
    fi
}

cleanup_bun_cache() {
    _header "Cleaning Up Bun Cache"
    
    if command -v bun &> /dev/null; then
        _log INFO "Pruning Bun global cache..."
        bun pm cache clean
        _log SUCCESS "Bun cache cleaned successfully."
    else
        _log WARN "bun command not found. Skipping Bun cache cleanup."
    fi
}

#-------------------------------------------------------
# Main Execution
#-------------------------------------------------------
run_cleanup() {
    _header "Running System Cleanup"
    
    cleanup_system_packages
    cleanup_flatpak
    cleanup_journal_logs
    cleanup_coredumps
    cleanup_npm_cache
    cleanup_pnpm_cache
    cleanup_bun_cache
}

run_cleanup