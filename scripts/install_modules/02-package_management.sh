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

install_npm() {
     install_pacman_package "npm" "npm"
}

install_pnpm() {
     install_paru_package "pnpm" "pnpm"
     echo "Checking pnpm setup..."
     local fish_config="$HOME/.config/fish/config.fish"

     if [ -f "$fish_config" ] && grep -q "pnpm" "$fish_config"; then
          _log INFO "pnpm configuration already exists in $fish_config, skipping setup."
     elif command -v pnpm &>/dev/null;
 then
          _log INFO "Running pnpm setup..."
          pnpm setup
          _log SUCCESS "pnpm setup completed."
     else
          _log WARN "pnpm command not found, skipping pnpm setup."
     fi
}
