#!/bin/bash

#-------------------------------------------------------
# Script Configuration
#-------------------------------------------------------
AUTO_MODE=false
SKIP_CODE_INSIDERS=false
LOAD_CONFIGS_ARGS=()

for arg in "$@"; do
    case $arg in
        --auto)
            AUTO_MODE=true
            ;;
        --skip-code-insiders)
            SKIP_CODE_INSIDERS=true
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
source "$repo_dir/scripts/install_modules/04-apps.sh"
source "$repo_dir/scripts/utils/list_gpu.sh" # Source list_gpu.sh for GPU validation



update_system_packages() {
    if ! command -v paru &> /dev/null; then
        _log WARN "paru command not found. Skipping system package update."
        _log INFO "Please install paru to enable this feature."
        return
    fi
    
    echo
    echo "============================================================="
    echo " Updating System & AUR Packages (paru)"
    echo "============================================================="
    paru -Syu --noconfirm
}

update_vscode_insiders() {
    if [ "$SKIP_CODE_INSIDERS" = true ]; then
        _log INFO "Skipping VS Code Insiders update as requested."
        return
    fi

    if ! command -v paru &> /dev/null; then
        _log WARN "paru command not found. Skipping VS Code Insiders update."
        _log INFO "Please install paru to enable this feature."
        return
    fi

    if ! command -v code-insiders &> /dev/null; then
        _log INFO "VS Code Insiders (code-insiders) command not found. Skipping update."
        return
    fi

    echo
    echo "============================================================="
    echo " Updating VS Code Insiders (code-insiders-bin)"
    echo "============================================================="

    # Check if code-insiders-bin is outdated using paru
    if paru -Qqu code-insiders-bin &> /dev/null; then
        _log INFO "VS Code Insiders (code-insiders-bin) is outdated. Updating..."
        paru -S --noconfirm code-insiders-bin
        _log SUCCESS "VS Code Insiders updated."
    else
        _log INFO "VS Code Insiders is already up-to-date."
    fi
}

update_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        _log WARN "flatpak command not found. Skipping Flatpak update."
        return
    fi

    echo
    echo "============================================================="
    echo " Updating Flatpak Packages"
    echo "============================================================="
    flatpak update -y
}

update_npm_global_packages() {
    if ! command -v npm &> /dev/null; then
        _log WARN "npm command not found. Skipping global package update."
        _log INFO "Please install npm to enable this feature."
        return
    fi

    echo
    echo "============================================================="
    echo " Updating Global NPM Packages"
    echo "============================================================="
    _log INFO "Updating all global npm packages..."
    sudo npm update -g
    _log SUCCESS "Global npm packages updated."

    # Check and update @google/gemini-cli
    if command -v gemini &> /dev/null; then
        _log INFO "Gemini CLI found. Updating to nightly version..."
        sudo npm install -g @google/gemini-cli@nightly
        _log SUCCESS "Gemini CLI updated to nightly."
    else
        _log INFO "Gemini CLI not found. Skipping Gemini CLI update."
    fi
}

load_v4l2loopback_module() {
    echo
    echo "============================================================="
    echo " Loading v4l2loopback module"
    echo "============================================================="
    sudo modprobe v4l2loopback
    _log SUCCESS "v4l2loopback module loaded."
}

load_configs() {
    local config_script="./cli/load_configs.sh"

    if [ ! -f "$config_script" ]; then
        _log WARN "'$config_script' not found. Skipping config load."
        return
    fi

    echo
    echo "============================================================="
    echo " Load Configurations"
    echo "============================================================="

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
update_vscode_insiders
fix_vscode_permissions
update_flatpak
update_npm_global_packages
load_v4l2loopback_module
load_configs
bash ./cli/cleanup.sh

_log SUCCESS "Full system update and cleanup process has finished."