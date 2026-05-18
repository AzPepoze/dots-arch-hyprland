#!/bin/bash
#----------------------------------------------------------------------
# GPU Configurator
#
# Detects GPUs and writes the selected configuration for Hyprland.
#----------------------------------------------------------------------

set -e

#-------------------------------------------------------
# Configuration
#-------------------------------------------------------
# Get the directory of the current script
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Get the root directory of the repository
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"
CONFIGS_DIR_SYSTEM="$HOME"

# Source helper functions
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
# Check if helper script exists before sourcing
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    # Define a fallback _log function if helper is not found
    _log() {
        local level=$1
        shift
        # Default log to stderr to avoid issues with command substitution
        echo "[$level] $@" >&2
    }
fi

# Source list_gpu.sh for GPU detection and validation functions
GPU_SCRIPT="$REPO_DIR/scripts/utils/list_gpu.sh"
if [ -f "$GPU_SCRIPT" ]; then
    source "$GPU_SCRIPT"
else
    _log ERROR "GPU detection script not found at '$GPU_SCRIPT'. Please ensure it exists."
    exit 1
fi

#-------------------------------------------------------
# Helper Functions
#-------------------------------------------------------
configure_gpu_device() {
    echo "Detecting available GPUs..." >&2

    declare -A lspci_line_to_device_path
    local menu_options=()

    while read -r pci_addr device_path; do
        local lspci_line
        lspci_line=$(lspci -s "$pci_addr" | head -n 1) # Get the full lspci line for display
        lspci_line_to_device_path["$lspci_line"]="$device_path"
        menu_options+=("$lspci_line")
    done <<< "$(list_available_gpus)"

    if [ ${#menu_options[@]} -eq 0 ]; then
        echo "No display controllers found. Skipping GPU configuration." >&2
        return
    fi

    menu_options+=("Exit")
    echo "Please select the primary GPU for Hyprland:" >&2
    select selected_lspci_line in "${menu_options[@]}"; do
        if [[ "$selected_lspci_line" == "Exit" ]]; then
            echo "Exiting GPU configuration." >&2
            break
        elif [[ -n "$selected_lspci_line" ]]; then
            local selected_gpu_path=${lspci_line_to_device_path["$selected_lspci_line"]}
            echo "You selected: $selected_lspci_line" >&2

            # Ensure the selected GPU is the first in the list
            local ordered_devices=("$selected_gpu_path")
            for device in "${lspci_line_to_device_path[@]}"; do
                if [[ "$device" != "$selected_gpu_path" ]]; then
                    ordered_devices+=("$device")
                fi
            done

            local final_device_string
            final_device_string=$(printf "%s:" "${ordered_devices[@]}")
            final_device_string=${final_device_string%:}
            
            echo "$final_device_string"
            break
        else
            _log ERROR "Invalid selection. Please try again."
        fi
    done
}

update_gpu_conf() {
    local gpu_device_string=$1

    if [ -z "$gpu_device_string" ]; then
        _log WARN "No GPU device provided. Skipping Hyprland GPU configuration."
        return
    fi

    # Extract the primary GPU device (the first one in the colon-separated string)
    local primary_gpu_device
    primary_gpu_device=$(echo "$gpu_device_string" | cut -d: -f1)

    # Validate the primary GPU device path before writing to config
    if ! check_gpu_device_path "$primary_gpu_device"; then
        _log ERROR "Provided primary GPU device '$primary_gpu_device' from string '$gpu_device_string' is not valid or detected. Aborting GPU configuration update."
        return 1
    fi

    local gpu_lua_file="$CONFIGS_DIR_SYSTEM/.config/hypr/gpu.lua"
    local legacy_gpu_conf="$CONFIGS_DIR_SYSTEM/.config/hypr/gpu.conf"

    mkdir -p "$(dirname "$gpu_lua_file")"

    # Remove legacy conf file if exists
    if [ -f "$legacy_gpu_conf" ]; then
        rm -f "$legacy_gpu_conf"
    fi

    _log INFO "Generating $gpu_lua_file..."
    cat > "$gpu_lua_file" <<- EOL
-- GPU settings managed by config-loader
hl.env("AQ_DRM_DEVICES", "$gpu_device_string")
EOL
}


#-------------------------------------------------------
# Main Logic
#-------------------------------------------------------
main() {
    local selected_gpu_device
    selected_gpu_device=$(configure_gpu_device)

    if [ -n "$selected_gpu_device" ]; then
        update_gpu_conf "$selected_gpu_device"
    else
        _log INFO "No GPU selected or configuration was exited. Skipping update."
    fi
}

#-------------------------------------------------------
# Script Execution
#-------------------------------------------------------
main "$@"