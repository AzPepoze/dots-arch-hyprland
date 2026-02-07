#!/bin/bash

#-------------------------------------------------------
# Group: System
#-------------------------------------------------------

install_inotify_tools() {
     install_pacman_package "inotify-tools" "inotify-tools"
}

install_power_options() {
    _log INFO "Installing Power Options (TLP) and removing conflicting packages..."

    local conflicting_packages=("power-profiles-daemon" "auto-cpufreq")

    for pkg in "${conflicting_packages[@]}"; do
        if pacman -Qs "$pkg" > /dev/null; then
            _log WARN "Conflicting package '$pkg' found. Removing..."
            sudo pacman -Rns --noconfirm "$pkg"
        fi
    done

    install_paru_package "tlp" "TLP"
    install_paru_package "tlp-rdw" "TLP Radio Device Wizard"

    _log INFO "Enabling and starting tlp.service..."
    sudo systemctl enable --now tlp.service
    _log SUCCESS "TLP installed and configured. Conflicting packages removed."
}

install_fuse() {
     install_paru_package "fuse" "FUSE (Filesystem in Userspace)"
}

install_ntfs_3g() {
     install_pacman_package "ntfs-3g" "NTFS Support (ntfs-3g utilities for kernel ntfs3)"
}
