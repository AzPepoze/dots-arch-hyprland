#!/bin/bash

#-------------------------------------------------------
# Group: Helper Functions
#-------------------------------------------------------

# Common Directories
export USER_ICON_DIR="$HOME/.local/share/icons"
export BUILT_THEMES_DIR="$repo_dir/dist/cursors"
export CONFIG_FILE="$repo_dir/config.json"

# Logging functions
_log() {
    local type="$1"; shift
    local msg="$*"
    local color_red="[0;31m"
    local color_green="[0;32m"
    local color_yellow="[0;33m"
    local color_blue="[0;34m"
    local color_reset="[0m"

    case "$type" in
        INFO) echo -e "${color_blue}[INFO]${color_reset} $msg" ;;
        SUCCESS) echo -e "${color_green}[SUCCESS]${color_reset} $msg" ;;
        WARN) echo -e "${color_yellow}[WARN]${color_reset} $msg" ;;
        ERROR) echo -e "${color_red}[ERROR]${color_reset} $msg" >&2 ;;
        *) echo "$msg" ;;
    esac
}

_header() {
    local title="$1"
    echo
    echo "============================================================="
    echo " $title"
    echo "============================================================="
}

ask_yes_no() {
     local question="$1"
     local prompt="[y/n]"

     while true; do
          read -p "$question $prompt: " response
          case "$response" in
          [yY][eE][sS] | [yY]) return 0 ;;
          [nN][oO] | [nN]) return 1 ;;
          *) echo "Please answer yes or no." ;;
          esac
     done
}

install_pacman_package() {
     local package="$1"
     local friendly_name="$2"
     echo "Installing $friendly_name..."
     sudo pacman -S --needed "$package" --noconfirm
     echo "$friendly_name installation completed successfully."
}

install_paru_package() {
     local package="$1"
     local friendly_name="$2"
     local noconfirm="${3:-true}"
     
     if ! command -v paru &>/dev/null; then
          _log ERROR "paru is not installed. Skipping $friendly_name installation."
          return 1
     fi

     echo "Installing $friendly_name ($package) using paru..."
     
     if [ "$noconfirm" = "true" ]; then
          paru -S --needed --noconfirm "$package"
     else
          paru -S --needed "$package"
     fi

     if [ $? -eq 0 ]; then
          _log SUCCESS "$friendly_name installation completed successfully."
          return 0
     else
          _log ERROR "$friendly_name installation failed."
          return 1
     fi
}

check_flatpak() {
     if ! command -v flatpak &>/dev/null; then
          _log INFO "Flatpak is not installed. Installing Flatpak..."
          install_pacman_package "flatpak" "Flatpak"
     fi
}

install_flatpak_package() {
     local package_id="$1"
     local friendly_name="$2"
     check_flatpak
     echo "Installing $friendly_name from Flathub..."
     flatpak install flathub "$package_id" -y
     echo "$friendly_name installation completed."
}

install_jq() {
    if ! command -v jq &>/dev/null; then
        echo "jq not found. Installing..."
        install_pacman_package "jq" "jq"
    fi
}