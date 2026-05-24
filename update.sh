#!/bin/bash

#-------------------------------------------------------
# Script Configuration
#-------------------------------------------------------
AUTO_MODE=false
SKIP_VSCODE=false
LOAD_CONFIGS_ARGS=()

for arg in "$@"; do
    case $arg in
        --auto)
            AUTO_MODE=true
            ;;
        --skip-vscode)
            SKIP_VSCODE=true
            ;;
        *)
            LOAD_CONFIGS_ARGS+=("$arg")
            ;;
    esac
done

#-------------------------------------------------------
# Update Functions
#-------------------------------------------------------

repo_dir=$(dirname "$(realpath "$0")")
source "$repo_dir/scripts/install_modules/helpers.sh"
source "$repo_dir/scripts/install_modules/05-applications.sh"
source "$repo_dir/scripts/utils/list_gpu.sh" # Source list_gpu.sh for GPU validation



update_system_packages() {
    resolve_pacman_file_conflicts
    if ! command -v paru &> /dev/null; then
        _log WARN "paru command not found. Skipping system package update."
        _log INFO "Please install paru to enable this feature."
        return
    fi
    
    _header "Updating System & AUR Packages (paru)"
    paru -Syu --noconfirm
}

update_vscode() {
    if [ "$SKIP_VSCODE" = true ]; then
        _log INFO "Skipping VS Code update as requested."
        return
    fi

    if ! command -v paru &> /dev/null; then
        _log WARN "paru command not found. Skipping VS Code update."
        _log INFO "Please install paru to enable this feature."
        return
    fi

    if ! command -v code &> /dev/null; then
        _log INFO "VS Code (code) command not found. Skipping update."
        return
    fi

    _header "Updating VS Code (visual-studio-code-bin)"

    # Check if visual-studio-code-bin is outdated using paru
    if paru -Qqu visual-studio-code-bin &> /dev/null; then
        _log INFO "VS Code (visual-studio-code-bin) is outdated. Updating..."
        paru -S --noconfirm visual-studio-code-bin
        _log SUCCESS "VS Code updated."
    else
        _log INFO "VS Code is already up-to-date."
    fi
}

update_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        _log WARN "flatpak command not found. Skipping Flatpak update."
        return
    fi

    _header "Updating Flatpak Packages"
    flatpak update -y
}

update_bun_global_packages() {
    if ! command -v bun &> /dev/null; then
        _log WARN "bun command not found. Skipping global package update."
        _log INFO "Please install bun to enable this feature."
        return
    fi

    _header "Updating Global Bun Packages"
    _log INFO "Updating all global bun packages..."
    bun update -g
    _log SUCCESS "Global bun packages updated."
}

load_v4l2loopback_module() {
    _header "Loading v4l2loopback module"
    sudo modprobe v4l2loopback
    _log SUCCESS "v4l2loopback module loaded."
}

load_configs() {
    local config_script="./cli/load_configs.sh"

    if [ ! -f "$config_script" ]; then
        _log WARN "'$config_script' not found. Skipping config load."
        return
    fi

    _header "Load Configurations"

    # Pass filtered arguments to load_configs.sh
    bash "$config_script" "${LOAD_CONFIGS_ARGS[@]}"
    _log SUCCESS "Configuration load process finished."
}

#-------------------------------------------------------
# Script Execution
#-------------------------------------------------------

# fastfetch


echo
_log INFO "Starting full system update process..."

echo

update_system_packages
update_vscode
fix_vscode_permissions
update_flatpak
update_bun_global_packages
load_v4l2loopback_module
load_configs
bash ./cli/utils/cleanup.sh


_log SUCCESS "Full system update and cleanup process has finished."