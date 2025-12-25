#!/bin/bash

#-------------------------------------------------------
# Cleanup Functions
#-------------------------------------------------------

cleanup_system_packages() {
    echo
    echo "============================================================="
    echo " Cleaning Up System Packages"
    echo "============================================================="
    if command -v paru &> /dev/null; then
        echo "Removing orphan packages..."
        yes | paru -c

        echo
        echo "Cleaning package cache..."
        yes | paru -Sccd
    else
        echo "paru command not found. Skipping system package cleanup."
    fi
}

cleanup_flatpak() {
    echo
    echo "============================================================="
    echo " Cleaning Up Flatpak"
    echo "============================================================="
    if command -v flatpak &> /dev/null; then
        echo "Removing unused Flatpak runtimes..."
        flatpak uninstall --unused -y
    else
        echo "flatpak command not found. Skipping Flatpak cleanup."
    fi
}

cleanup_journal_logs() {
    echo
    echo "============================================================="
    echo " Cleaning Up Journal Logs"
    echo "============================================================="
    echo "Vacuuming journal logs to keep the last 3 days..."
    sudo journalctl --vacuum-time=3d
}

cleanup_coredumps() {
    echo
    echo "============================================================="
    echo " Cleaning Up Systemd Coredumps"
    echo "============================================================="
    echo "Removing all coredump files..."
    sudo rm -rf /var/lib/systemd/coredump/*
}

cleanup_pnpm_store() {
    echo
    echo "============================================================="
    echo " Cleaning Up pnpm Store"
    echo "============================================================="
    if command -v pnpm &> /dev/null; then
        echo "Pruning pnpm store..."
        pnpm store prune
    else
        echo "pnpm command not found. Skipping pnpm store cleanup."
    fi
}


#-------------------------------------------------------
# Main Execution
#-------------------------------------------------------
run_cleanup() {
    echo
    echo "============================================================="
    echo " Running System Cleanup"
    echo "============================================================="
    cleanup_system_packages
    cleanup_flatpak
    cleanup_journal_logs
    cleanup_coredumps
    cleanup_pnpm_store
}

run_cleanup