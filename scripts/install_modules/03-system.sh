#!/bin/bash

#-------------------------------------------------------
# Group: System
#-------------------------------------------------------

install_inotify_tools() {
     install_pacman_package "inotify-tools" "inotify-tools"
}
install_power_profiles() {
    _log INFO "Installing Power Profiles Daemon and removing conflicting packages..."

    if systemctl is-active --quiet tlp.service || systemctl is-enabled --quiet tlp.service; then
        _log WARN "TLP service is active or enabled. Stopping, disabling, and masking..."
        sudo systemctl disable --now tlp.service || true
        sudo systemctl mask tlp.service || true
    fi

    local conflicting_packages=("tlp" "tlp-rdw" "auto-cpufreq")

    for pkg in "${conflicting_packages[@]}"; do
        if pacman -Qs "$pkg" > /dev/null; then
            _log WARN "Conflicting package '$pkg' found. Removing..."
            sudo pacman -Rns --noconfirm "$pkg"
        fi
    done

    install_pacman_package "power-profiles-daemon" "Power Profiles Daemon"

    _log INFO "Enabling and starting power-profiles-daemon.service..."
    sudo systemctl unmask power-profiles-daemon.service 2>/dev/null || true
    sudo systemctl enable --now power-profiles-daemon.service
    _log SUCCESS "Power Profiles Daemon installed and configured. Conflicting packages removed."
}

install_fuse() {
     install_paru_package "fuse" "FUSE (Filesystem in Userspace)"
}

install_ntfs_3g() {
     install_pacman_package "ntfs-3g" "NTFS Support (ntfs-3g utilities for kernel ntfs3)"
}
