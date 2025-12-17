#!/bin/bash

#-------------------------------------------------------
# Group: Core System & Package Management
#-------------------------------------------------------

install_paru() {
     echo "Installing paru (AUR Helper)..."
     if command -v paru &>/dev/null;
 then
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

install_flatpak() {
     install_pacman_package "flatpak" "Flatpak"
}

install_fuse() {
     install_paru_package "fuse" "FUSE (Filesystem in Userspace)"
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

install_npm() {
     install_pacman_package "npm" "npm"
}

install_ntfs_3g() {
     install_pacman_package "ntfs-3g" "NTFS-3G (NTFS Filesystem Driver)"
}

install_git() {
     install_pacman_package "git" "Git Version Control System"
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

install_linux_headers() {
    install_pacman_package "linux-headers" "Linux Headers"
}

install_nvidia_drivers() {
    _log INFO "Installing NVIDIA drivers and utilities..."

    # Install NVIDIA packages
    _log INFO "Installing NVIDIA packages..."
    local nvidia_packages=(
        "nvidia"           # Main NVIDIA driver
        "nvidia-utils"     # NVIDIA utilities
        "nvidia-settings" # NVIDIA settings GUI
        "libva"           # Video Acceleration API
        "libva-nvidia-driver" # NVIDIA VA-API driver
    )

    for package in "${nvidia_packages[@]}"; do
        install_paru_package "$package" "$package"
    done

    # Enable DRM kernel mode setting
    local nvidia_conf="/etc/modprobe.d/nvidia.conf"
    if [ ! -f "$nvidia_conf" ]; then
        _log INFO "Creating NVIDIA configuration for DRM KMS..."
        echo "options nvidia-drm modeset=1" | sudo tee "$nvidia_conf" > /dev/null
    fi

    # Update initramfs
    _log INFO "Updating initramfs..."
    sudo mkinitcpio -P

    _log SUCCESS "NVIDIA drivers installation completed. Please reboot your system to apply changes."
    _log INFO "After reboot, you can verify the installation by running: nvidia-smi"
}

#-------------------------------------------------------
# System Services Module
#-------------------------------------------------------

# Install and enable systemd-oomd.service
install_systemd_oomd() {
    echo "Installing and enabling systemd-oomd.service..."
    sudo systemctl enable --now systemd-oomd.service
    _log SUCCESS "systemd-oomd.service installed and enabled."
}

# Install and enable ananicy-cpp
install_ananicy_cpp() {
    echo "Installing ananicy-cpp..."
    paru -S ananicy-cpp --noconfirm # --noconfirm is added for unattended installation
    echo "Enabling ananicy-cpp.service..."
    sudo systemctl enable --now ananicy-cpp.service
    _log SUCCESS "ananicy-cpp installed and enabled."
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

install_rate_mirrors_and_rank() {
    _log INFO "Installing rate-mirrors..."
    install_paru_package "rate-mirrors" "rate-mirrors"

    _log INFO "Running cli/rank_mirrors.sh to rank mirrors..."
    bash "$repo_dir/cli/rank_mirrors.sh"
    _log SUCCESS "rate-mirrors installed and mirrors ranked."
}



#-------------------------------------------------------
# Group: System Configuration - GRUB
#-------------------------------------------------------

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

install_catppuccin_grub_theme() {
    # Use the first argument as the theme flavor, default to 'mocha'
    local flavor=${1:-mocha}
    local capitalized_flavor="$(tr '[:lower:]' '[:upper:]' <<< ${flavor:0:1})${flavor:1}"

    echo "Installing Catppuccin $capitalized_flavor theme for GRUB..."
    _check_grub_file_exists || return 1

    if ! command -v git &> /dev/null;
 then
        _log ERROR "git is not installed. Please install it first."
        return 1
    fi

    local theme_name="catppuccin-$flavor"
    local grub_themes_dir="/usr/share/grub/themes"
    local target_theme_dir="$grub_themes_dir/$theme_name"
    local grub_file="/etc/default/grub"
    local tmp_dir="/tmp/grub-catppuccin-theme"
    local theme_path="$target_theme_dir/theme.txt"

    # 1. Clone the repository
    echo "Cloning Catppuccin GRUB theme repository..."
    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
    git clone --depth 1 https://github.com/catppuccin/grub.git "$tmp_dir"
    if [ $? -ne 0 ]; then
        _log ERROR "Failed to clone the repository."
        return 1
    fi

    # 2. Copy the theme files from the correct path
    local source_theme_dir="$tmp_dir/src/catppuccin-$flavor-grub-theme"
    echo "Source theme path is: $source_theme_dir"

    if [ ! -d "$source_theme_dir" ]; then
        _log ERROR "Source theme directory for '$flavor' not found after cloning!"
        rm -rf "$tmp_dir"
        return 1
    fi

    echo "Installing theme to $target_theme_dir..."
    sudo mkdir -p "$target_theme_dir"
    sudo cp -r "$source_theme_dir/"* "$target_theme_dir/"
    if [ $? -ne 0 ]; then
        _log ERROR "Failed to copy theme files."
        rm -rf "$tmp_dir"
        return 1
    fi

    # 3. Set the GRUB_THEME variable
    echo "Setting GRUB_THEME in $grub_file..."
    if sudo grep -q '^GRUB_THEME=' "$grub_file"; then
        sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme_path\"|" "$grub_file"
    else
        echo "GRUB_THEME=\"$theme_path\"" | sudo tee -a "$grub_file" >/dev/null
    fi

    # 4. Clean up the temporary directory
    echo "Cleaning up temporary files..."
    rm -rf "$tmp_dir"

    # 5. Regenerate GRUB config
    _regenerate_grub_config

    _log SUCCESS "Catppuccin $capitalized_flavor GRUB theme installed and configured successfully."
}

select_and_install_catppuccin_grub_theme() {
    local flavors=("mocha" "latte" "frappe" "macchiato" "Exit")
    echo "Please select a Catppuccin flavor for GRUB (default is mocha):"
    
    # PS3 is the prompt for the select menu
    PS3="Enter your choice [1-5]: "
    
    select flavor in "${flavors[@]}"; do
        # Default to mocha if user just presses Enter
        if [ -z "$REPLY" ]; then
            flavor="mocha"
        fi

        if [[ " ${flavors[*]} " =~ " ${flavor} " ]]; then
            if [ "$flavor" == "Exit" ]; then
                _log WARN "Skipping GRUB theme installation."
                break
            fi
            _log INFO "You selected: $flavor"
            install_catppuccin_grub_theme "$flavor"
            break
        else
            echo "Invalid option '$REPLY'. Please try again."
        fi
    done
    # Reset PS3 to default
    PS3="#? "
}

#-------------------------------------------------------
# MX002 Tablet Driver Installer
#-------------------------------------------------------

install_mx002_driver() {
    echo "Installing MX002 Tablet Driver..."

    # Check for Rust/Cargo
    if ! command -v cargo &> /dev/null;
 then
        echo "Rust is not installed. Installing rustup..."
        if ! command -v curl &> /dev/null;
 then
            echo "Error: curl is required to install rustup but it's not installed."
            echo "Please install curl and try again."
            return 1
        fi
        # Install rustup non-interactively
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # Add cargo to PATH for the current session
        source "$HOME/.cargo/env"
    else
        echo "Rust is already installed."
    fi

    
    rm -rf "$HOME/mx002_linux_driver" 2>/dev/null

    local repo_url="https://github.com/marvinbelfort/mx002_linux_driver"
    local clone_dir=$(mktemp -d)"/mx002_linux_driver"

    if [ -d "$clone_dir" ]; then
        echo "Directory $clone_dir already exists. Skipping clone."
    else
        echo "Cloning $repo_url..."
        if ! git clone "$repo_url" "$clone_dir"; then
            echo "Error: Failed to clone the repository."
            return 1
        fi
    fi
    
    cd "$clone_dir"
    
    echo "Building driver with Cargo..."
    if cargo build --release;
 then
        echo "Driver built successfully."
        local built="$clone_dir/target/release"
        if [ -d "$built" ]; then
            echo "Moving driver binary to $clone_dir/"
            mv "$built" "$HOME/mx002_linux_driver"
            echo "Driver is located at $clone_dir"
            echo "NOTE: You may need to run it with sudo."
        else
            echo "Error: Built driver not found at the expected location."
        fi
    else
        echo "Error: Failed to build the driver."
        cd "$repo_dir" # Return to original script directory
        return 1
    fi
    
    cd "$repo_dir" # Return to original script directory
    echo "MX002 Tablet Driver installation process finished."
}
