#!/bin/bash

#-------------------------------------------------------
# Group: Core
#-------------------------------------------------------

install_paru() {
     echo "Installing paru (AUR Helper)..."
     if command -v paru &>/dev/null; then
          echo "paru is already installed."
          return 0
     fi

     echo "Installing dependencies for paru (git, base-devel)..."
     sudo pacman -S --needed git base-devel --noconfirm

     local temp_dir
     temp_dir=$(mktemp -d)
     if [ -z "$temp_dir" ]; then
          _log ERROR "Could not create temporary directory."
          return 1
     fi

     echo "Cloning paru from AUR into a temporary directory..."
     if ! git clone https://aur.archlinux.org/paru.git "$temp_dir/paru"; then
          _log ERROR "Failed to clone paru repository."
          rm -rf "$temp_dir"
          return 1
     fi

     (
          cd "$temp_dir/paru" || exit 1
          echo "Building and installing paru..."
          makepkg -si --noconfirm
     )

     echo "Cleaning up..."
     rm -rf "$temp_dir"
}

install_rate_mirrors_and_rank() {
    _log INFO "Installing rate-mirrors..."
    install_paru_package "rate-mirrors" "rate-mirrors"

    _log INFO "Running cli/rank_mirrors.sh to rank mirrors..."
    if [ -f "$repo_dir/cli/rank_mirrors.sh" ]; then
        bash "$repo_dir/cli/rank_mirrors.sh"
    else
        _log ERROR "Rank mirrors script not found at $repo_dir/cli/rank_mirrors.sh"
    fi
    _log SUCCESS "rate-mirrors installed and mirrors ranked."
}

setup_git_credential_management() {
    _log INFO "Setting up Git Credential Management..."
    echo "Installing git-credential-manager-bin..."
    paru -S --needed --noconfirm git-credential-manager-bin || { _log ERROR "Failed to install git-credential-manager-bin."; return 1; }
    
    echo "Configuring Git credential helper..."
    git config --global credential.helper manager || { _log ERROR "Failed to configure credential.helper."; return 1; }
    
    echo "Configuring Git credential store..."
    git config --global credential.credentialStore secretservice || { _log ERROR "Failed to configure credential.credentialStore."; return 1; }
    
    _log SUCCESS "Git Credential Management setup completed successfully."
}

install_fish() {
    _log INFO "Installing Fish shell..."
    install_pacman_package "fish" "Fish Shell"
    
    if command -v fish &>/dev/null; then
        local user_shell=$(getent passwd $USER | cut -d: -f7)
        if [ "$user_shell" != "$(which fish)" ]; then
            _log INFO "Setting Fish as default shell..."
            chsh -s "$(which fish)"
            _log SUCCESS "Fish shell is now your default shell. Please log out and back in for changes to take effect."
        else
            _log INFO "Fish is already your default shell."
        fi
    else
        _log ERROR "Fish installation appears to have failed."
        return 1
    fi
}

install_end4_hyprland_dots() {
    _log INFO "Installing end-4's Hyprland Dots..."
    local target_dir="$HOME/dots-hyprland"

    if [ -d "$target_dir" ]; then
        _log WARN "Directory '$target_dir' already exists."
        if ask_yes_no "Do you want to remove the existing directory and reinstall?"; then
            _log INFO "Removing existing directory..."
            rm -rf "$target_dir"
        else
            _log INFO "Skipping installation of end-4's Hyprland Dots."
            return 0
        fi
    fi

    if git clone https://github.com/end-4/dots-hyprland "$target_dir"; then
        ( # Run in a subshell to avoid changing the main script's directory
            cd "$target_dir" || exit 1
            _log INFO "Running the installer script for dots-hyprland..."
            ./install.sh
        )
        _log SUCCESS "end-4's Hyprland Dots installation complete."
    else
        _log ERROR "Failed to clone the repository."
        return 1
    fi
}

install_nwg_displays() {
    _log INFO "Installing nwg-displays for screen management..."
    install_paru_package "nwg-displays" "nwg-displays"
    _log SUCCESS "nwg-displays has been installed."
    
    if command -v nwg-displays &> /dev/null; then
        _log INFO "Launching nwg-displays..."
        nwg-displays &>/dev/null &
        sleep 1
        echo ""
        _log INFO "Please configure your display settings in the nwg-displays window."
        _log INFO "Set the mode, resolution, and position for each monitor as needed."
        read -p "Once you are finished, press Enter in this terminal to continue..." 
    else
        _log ERROR "nwg-displays command not found after installation."
    fi
}

install_hyprshutdown() {
    # Run without noconfirm (false) to allow resolving package conflicts manually
    install_paru_package "hyprshutdown-git" "hyprshutdown" "false"
}

_check_grub_file_exists() {
     if [ ! -f "/etc/default/grub" ]; then
          _log ERROR "/etc/default/grub not found. Is GRUB installed?"
          return 1
     fi
     return 0
}

_regenerate_grub_config() {
     echo "Regenerating GRUB configuration..."
     sudo grub-mkconfig -o /boot/grub/grub.cfg
     _log SUCCESS "GRUB configuration updated successfully."
}

adjust_grub_menu() {
     echo "Adjusting GRUB menu resolution to 1920x1080x32..."
     _check_grub_file_exists || return 1
     local grub_file="/etc/default/grub"

     if sudo grep -q '^GRUB_GFXMODE=' "$grub_file"; then
          echo "Updating existing GRUB_GFXMODE setting."
          sudo sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080x32/' "$grub_file"
     else
          echo "Adding new GRUB_GFXMODE setting."
          echo 'GRUB_GFXMODE=1920x1080x32' | sudo tee -a "$grub_file" >/dev/null
     fi

     _regenerate_grub_config
}

enable_os_prober() {
     install_pacman_package "os-prober" "os-prober"
     echo "Enabling os-prober in GRUB configuration..."
     _check_grub_file_exists || return 1
     local grub_file="/etc/default/grub"

     if sudo grep -q '#GRUB_DISABLE_OS_PROBER=true' "$grub_file"; then
          echo "Uncommenting and setting GRUB_DISABLE_OS_PROBER to false."
          sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' "$grub_file"
     elif ! sudo grep -q '^GRUB_DISABLE_OS_PROBER=' "$grub_file"; then
          echo "Adding GRUB_DISABLE_OS_PROBER=false to the configuration."
          echo 'GRUB_DISABLE_OS_PROBER=false' | sudo tee -a "$grub_file" >/dev/null
     else
          echo "GRUB_DISABLE_OS_PROBER is already configured."
     fi

     _regenerate_grub_config
}

install_linux_headers() {
    install_pacman_package "linux-headers" "Linux Headers"
}

install_systemd_oomd() {
    echo "Installing and enabling systemd-oomd.service..."
    sudo systemctl enable --now systemd-oomd.service
    _log SUCCESS "systemd-oomd.service installed and enabled."
}

install_ananicy_cpp() {
    echo "Installing ananicy-cpp..."
    paru -S ananicy-cpp --noconfirm
    echo "Enabling ananicy-cpp.service..."
    sudo systemctl enable --now ananicy-cpp.service
    _log SUCCESS "ananicy-cpp installed and enabled."
}

install_mission_center() {
     install_paru_package "mission-center" "Mission Center"
}
