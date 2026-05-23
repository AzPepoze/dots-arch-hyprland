#!/bin/bash

#-------------------------------------------------------
# Group: Package Management
#-------------------------------------------------------

install_flatpak() {
     install_pacman_package "flatpak" "Flatpak"
}

install_downgrade() {
    echo "Installing downgrade utility..."
    install_paru_package "downgrade" "downgrade"
    _log SUCCESS "downgrade utility installation completed successfully."
}

install_bun() {
     install_paru_package "bun-bin" "Bun"
}

install_npm() {
     install_pacman_package "npm" "npm"
}

install_pnpm() {
     install_pacman_package "pnpm" "pnpm"
}
