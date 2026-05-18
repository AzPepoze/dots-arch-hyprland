#!/bin/bash
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"

# Source helper functions
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    _log() {
        local type="$1"; shift
        local msg="$*"
        echo "[$type] $msg"
    }
fi

_header "Select One-Time Boot Entry"

GRUB_CONFIG_FILE="/etc/default/grub"
if ! grep -q -E "^\s*GRUB_DEFAULT=saved\s*$" "$GRUB_CONFIG_FILE"; then
    _log ERROR "Your GRUB configuration is not ready for this script."
    echo "This script requires 'GRUB_DEFAULT=saved' to be set in $GRUB_CONFIG_FILE."
    echo ""
    echo "Please do the following:"
    echo "1. Edit the file: sudo nano $GRUB_CONFIG_FILE"
    echo "2. Change the line 'GRUB_DEFAULT=0' to 'GRUB_DEFAULT=saved'"
    echo "3. Save the file and run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    echo "4. Rerun this script after making the changes."
    exit 1
fi

GRUB_CFG="/boot/grub/grub.cfg"
mapfile -t entries < <(grep "^menuentry" "$GRUB_CFG" | awk -F"'" '{print $2}')

if [ ${#entries[@]} -eq 0 ]; then
    _log ERROR "Could not find any boot entries in $GRUB_CFG"
    exit 1
fi

_log INFO "Please select the OS to boot into for the next restart:"
PS3=$'\n'"Enter a number (or Ctrl+C to cancel): "

select choice in "${entries[@]}" "Quit"; do
    if [[ "$choice" == "Quit" ]]; then
        echo "Operation cancelled."
        exit 0
    fi

    if [ -z "$choice" ]; then
        _log WARN "Invalid selection. Please try again."
        continue
    fi

    echo -e "\nYou have selected to reboot into: $choice"
    read -p "Are you sure you want to proceed? (y/N) " confirm

    if [[ "$confirm" =~ ^[yY]$ ]]; then
        _log INFO "Setting GRUB to boot '$choice' on the next restart..."
        sudo grub-reboot "$choice"
        
        if [ $? -eq 0 ]; then
            _log SUCCESS "Rebooting now..."
            reboot
        else
            _log ERROR "grub-reboot command failed. Please check your permissions."
            exit 1
        fi
    else
        echo "Reboot cancelled by user."
        exit 0
    fi
    break
done