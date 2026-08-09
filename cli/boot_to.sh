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
    read -r -p "Configure it now and regenerate GRUB's configuration? (y/N) " configure_grub

    if [[ ! "$configure_grub" =~ ^[yY]$ ]]; then
        echo "No changes were made."
        exit 1
    fi

    if ! sudo -v; then
        _log ERROR "Administrator authentication is required to configure GRUB."
        exit 1
    fi

    backup_file="${GRUB_CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    if ! sudo cp -- "$GRUB_CONFIG_FILE" "$backup_file"; then
        _log ERROR "Could not create a backup at $backup_file."
        exit 1
    fi

    if grep -q -E "^[[:space:]]*GRUB_DEFAULT=" "$GRUB_CONFIG_FILE"; then
        if ! sudo sed -i -E 's|^[[:space:]]*GRUB_DEFAULT=.*$|GRUB_DEFAULT=saved|' "$GRUB_CONFIG_FILE"; then
            _log ERROR "Could not update $GRUB_CONFIG_FILE."
            exit 1
        fi
    elif ! printf '%s\n' 'GRUB_DEFAULT=saved' | sudo tee -a "$GRUB_CONFIG_FILE" >/dev/null; then
        _log ERROR "Could not add GRUB_DEFAULT to $GRUB_CONFIG_FILE."
        exit 1
    fi

    _log INFO "Regenerating GRUB configuration..."
    if ! sudo grub-mkconfig -o /boot/grub/grub.cfg; then
        _log ERROR "GRUB configuration generation failed. A backup is available at $backup_file."
        exit 1
    fi

    _log SUCCESS "GRUB is ready. A backup was saved to $backup_file."
fi

GRUB_CFG="/boot/grub/grub.cfg"
mapfile -t entries < <(sudo grep "^menuentry" "$GRUB_CFG" | awk -F"'" '{print $2}')

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
            sudo reboot
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
