#!/bin/bash

# Source helper functions
# This script can be sourced by other scripts, so we need to ensure _log is available.
# If sourced, REPO_DIR_HELPER will be the directory of the sourcing script.
# If run directly, REPO_DIR_HELPER will be the directory of this script.
REPO_DIR_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HELPER_SCRIPT="$(dirname "$(dirname "$REPO_DIR_HELPER")")/scripts/install_modules/helpers.sh"

# Check if helper script exists before sourcing, otherwise define a fallback _log
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    _log() {
        local level=$1
        shift
        # Default log to stderr to avoid issues with command substitution
        echo "[$level] $@" >&2
    }
fi

#-------------------------------------------------------
# GPU Detection Functions
#-------------------------------------------------------

# Function to list available GPUs and their device paths
# Usage: list_available_gpus
# Returns: A newline-separated list of "PCI_ADDR DEVICE_PATH" for available GPUs
list_available_gpus() {
    if ! command -v lspci &>/dev/null; then
        _log ERROR "lspci command not found. Please install pciutils."
        exit 1
    fi

    # Filter for display controllers (class 03xx)
    while read -r line; do
        local pci_addr
        pci_addr=$(echo "$line" | awk '{print $1}')
        local symlink_path="/dev/dri/by-path/pci-0000:${pci_addr}-card"

        if [ -L "$symlink_path" ]; then
            local device_path
            device_path=$(readlink -f "$symlink_path")
            echo "$pci_addr $device_path"
        fi
    done <<< "$(lspci -d ::03xx)"
}

# Function to check if a specific GPU device path is valid and currently detected
# Usage: check_gpu_device_path <device_path>
# Returns: 0 if valid and detected, 1 if invalid or not detected
check_gpu_device_path() {
    local target_device_path="$1"
    if [ -z "$target_device_path" ]; then
        _log WARN "No target device path provided for check."
        return 1
    fi

    local found=false
    while read -r pci_addr device_path; do
        if [ "$device_path" == "$target_device_path" ]; then
            found=true
            break
        fi
    done <<< "$(list_available_gpus)"

    if [ "$found" = true ]; then
        _log INFO "GPU device '$target_device_path' is valid and currently detected."
        return 0
    else
        _log WARN "GPU device '$target_device_path' is NOT currently detected or valid."
        return 1
    fi
}

# Main execution for standalone script
# This block runs only if the script is executed directly, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -n "$1" ]; then
        # If an argument is provided, check that specific device path
        check_gpu_device_path "$1"
    else
        # Otherwise, list all detected GPUs
        _log INFO "Listing all detected GPU devices:"
        list_available_gpus
    fi
fi