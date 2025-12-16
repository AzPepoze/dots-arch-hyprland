#!/bin/bash
#----------------------------------------------------------------------
# Config Loader
#
# Loads configuration files from this repository to the local system.
#----------------------------------------------------------------------

set -e

#-------------------------------------------------------
# Configuration
#-------------------------------------------------------
# Get the directory of the current script (e.g., /home/azpepoze/dots-arch-hyprland/cli)
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Get the parent directory of the current script (e.g., /home/azpepoze/dots-arch-hyprland)
REPO_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"
CONFIGS_DIR_SYSTEM="$HOME"
CONFIG_FILE="$REPO_DIR/config.json" # Path to the new config.json

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

# Source loader helper functions
source "$CURRENT_SCRIPT_DIR/load_helpers.sh"

#-------------------------------------------------------
# Load Configurations from a Source Directory
#-------------------------------------------------------
load_configs_from_source() {
    local source_dir=$1
    local label_suffix=$2 # e.g., " (custom)"

    if [ ! -d "$source_dir" ]; then
        # Don't log if it's the custom dir and it doesn't exist, as this is an expected scenario.
        if [[ ! "$label_suffix" == *"custom"* ]]; then
             _log WARN "Configuration source directory not found at '$source_dir'. Skipping."
        fi
        return
    fi

    echo "============================================================"
    echo "Loading configurations from: $source_dir"
    echo "============================================================"

    # Loop through each top-level directory in 'dots' (e.g., 'home', 'etc')
    for base_type_dir in "$source_dir"/*; do
        if [ ! -d "$base_type_dir" ]; then
            continue
        fi

        local base_type_name
        base_type_name=$(basename "$base_type_dir") # e.g., "home" or "etc"

        local system_base_path=""
        case "$base_type_name" in
            "home")
                system_base_path="$HOME"
                ;;
            "etc")
                system_base_path="/etc"
                ;;
            *)
                _log WARN "Unknown base configuration type '$base_type_name'. Skipping."
                continue
                ;;
        esac

        # Now iterate through all items (files and directories) within the base_type_dir
        # e.g., 'dots/base/home/config', 'dots/base/home/local', 'dots/base/etc/power-options'
        find "$base_type_dir" -mindepth 1 -print0 | while IFS= read -r -d $'\0' item; do
            local relative_path="${item#$base_type_dir/}" # Path relative to base_type_dir
            local system_dest_path=""

            echo $relative_path

            # Special handling for .gemini folder (which is under home/gemini)
            if [[ "$relative_path" == "gemini"* ]]; then
                local gemini_repo_path="$source_dir/home/gemini"
                local gemini_system_dest_path="$system_base_path/.gemini" # This will be $HOME/.gemini

                echo "--- Loading '.gemini'$label_suffix ---"
                if [ ! -d "$gemini_repo_path" ]; then
                    _log WARN "Source directory for '.gemini' not found at '$gemini_repo_path'. Skipping."
                    continue
                fi

                mkdir -p "$gemini_system_dest_path"
                rsync -av --exclude="instruction.md" "$gemini_repo_path/" "$gemini_system_dest_path/"

                if [ -f "$gemini_repo_path/instruction.md" ]; then
                    cp "$gemini_repo_path/instruction.md" "$gemini_system_dest_path/GEMINI.md"
                    _log SUCCESS "Copied instruction.md${label_suffix} to $gemini_system_dest_path/GEMINI.md"
                else
                    _log WARN "instruction.md not found in $gemini_repo_path. Skipping specific copy."
                fi
                echo "---------------------------"
                continue # Skip further processing for gemini as it's handled
            fi

            # Construct the system destination path
            if [ "$base_type_name" == "home" ]; then
                # For home, if relative_path starts with "config/" or "local/", prepend a dot
                if [[ "$relative_path" == "config/"* ]]; then
                    system_dest_path="$system_base_path/.$relative_path"
                elif [[ "$relative_path" == "local/"* ]]; then
                    system_dest_path="$system_base_path/.$relative_path"
                else
                    system_dest_path="$system_base_path/$relative_path"
                fi
            elif [ "$base_type_name" == "etc" ]; then
                system_dest_path="$system_base_path/$relative_path"
            fi

            # Call sync_files for each item
            sync_files "$item" "$system_dest_path" "$(basename "$item")$label_suffix" ""
        done
    done
}

#-------------------------------------------------------
# Update dots-hyprland
#-------------------------------------------------------
update_dots_hyprland() {
    echo
    echo "============================================================="
    echo " Updating dots-hyprland"
    echo "============================================================="

    local monitor_config_path="$HOME/.config/hypr/monitors.conf"
    local temp_dir
    temp_dir=$(mktemp -d)
    local backup_monitor_config_path="$temp_dir/monitors.conf"

    if [ -f "$monitor_config_path" ]; then
        _log INFO "Backing up '$monitor_config_path'வுகளை..."
        cp "$monitor_config_path" "$backup_monitor_config_path"
    else
        _log WARN "Warning: '$monitor_config_path' not found. Nothing to back up."
    fi

    if [ ! -d "$HOME/dots-hyprland" ]; then
        _log WARN "dots-hyprland directory not found. Skipping dots-hyprland update."
        _log INFO "Please install dots-hyprland first if you wish to update it."
        return
    fi

    cd "$HOME/dots-hyprland"
    # git reset --hard origin/main && git pull
    # _log SUCCESS "dots-hyprland repository updated."

    if [ "$FULL_MODE" = true ]; then
        _log INFO "Full mode enabled. Running full install..."
        ./setup install -c -f
        _log SUCCESS "dots-hyprland full install finished."
    else
        _log INFO "Cleaning working directory and untracked files..."
        git clean -xdf
        _log INFO "Running unstable update (automated with expect)..."

        if ! command -v expect &> /dev/null; then
            _log ERROR "Error: 'expect' command not found."
            _log INFO "This automation requires 'expect'. Please install it first."
            _log INFO "On Arch Linux, you can run: sudo pacman -Syu expect"
            cd - >/dev/null
            return 1
        fi

        expect <<'END_OF_EXPECT'
set timeout 120

spawn bash ./setup exp-update -f

expect {
    timeout {
        puts "\nError: Timeout waiting for the initial (y/N) prompt."
        exit 1
    }
    -re "\[(y/N)\]:" {
        send "y\r"
    }
}

set timeout 1
expect {
    -re "\[(y/N)\]:" {
        send "y\r"
    }
}

set timeout 120

expect {
    -re "Conflict detected:.*monitors\\.conf" {
        expect -re "Enter your choice \\(1-8\\):" {
            send "2\r"
        }
        exp_continue
    }
    -re "Enter your choice \\(1-8\\):" {
        send "1\r"
        exp_continue
    }
    eof {
        exit 0
    }
    timeout {
        puts "\nError: Timeout while waiting for a prompt or for the script to finish."
        exit 1
    }
}
END_OF_EXPECT

        _log SUCCESS "dots-hyprland unstable update finished."
    fi

    cd - >/dev/null

    if [ -f "$backup_monitor_config_path" ]; then
        _log INFO "Restoring '$monitor_config_path'..."
        mkdir -p "$(dirname "$monitor_config_path")"
        cp "$backup_monitor_config_path" "$monitor_config_path"
    fi

    rm -rf "$temp_dir"
}

#-------------------------------------------------------
# Main Logic
#-------------------------------------------------------
main() {
    # Default values for flags
    local skip_gpu=false
    local skip_cursor=false
    local FULL_MODE=false
    local POST_INSTALL_MODE=false

    # Parse command-line arguments
    for arg in "$@"; do
        case $arg in
            --skip-gpu)
            skip_gpu=true
            shift
            ;;
            --skip-cursor)
            skip_cursor=true
            shift
            ;;
            --full)
            FULL_MODE=true
            shift
            ;;
            --post)
            POST_INSTALL_MODE=true
            shift
            ;;
        esac
    done

    # Update dots-hyprland if it exists
    update_dots_hyprland

    # GPU Configuration
    if [ "$skip_gpu" = false ]; then
        "$CURRENT_SCRIPT_DIR/configs/gpu.sh"
    else
        _log INFO "Skipping GPU configuration due to --skip-gpu flag."
    fi

    # Cursor Theme Configuration
    if [ "$skip_cursor" = false ]; then
        "$CURRENT_SCRIPT_DIR/configs/cursor.sh"
    else
         _log INFO "Skipping cursor configuration due to --skip-cursor flag."
    fi

    # Get user model from config.json
    local USER_MODEL
    USER_MODEL=$(get_user_model)
    _log INFO "User model detected: $USER_MODEL"

    # Load custom configurations first if in post-install mode
    if [ "$POST_INSTALL_MODE" = true ]; then
        load_configs_from_source "$REPO_DIR/dots/post-install" " (post-install)"
    fi

    # Load base configurations
    load_configs_from_source "$REPO_DIR/dots/base" " (base)"

    # Load model-specific configurations
    if [ -n "$USER_MODEL" ]; then
        local MODEL_CONFIG_DIR="$REPO_DIR/dots/$USER_MODEL"
        if [ -d "$MODEL_CONFIG_DIR" ]; then
            load_configs_from_source "$MODEL_CONFIG_DIR" " ($USER_MODEL)"
        else
            _log WARN "Model-specific configuration directory '$MODEL_CONFIG_DIR' not found. Skipping."
        fi
    fi

    if [[ "$(get_config_bool 'remove_end4_background' 'true')" == "true" ]]; then
        patch_quickshell_background
    else
        _log INFO "Skipping QuickShell background patch based on config.json setting."
    fi

    # Handle special cases
    if [[ "$(get_config_bool 'replace_end4_color_to_catpuccin' 'true')" == "true" ]]; then
        merge_quickshell_colors
    else
        _log INFO "Skipping QuickShell color merge based on config.json setting."
    fi

    # _log INFO "Reloading Hyprland configuration..."
	# hyprctl reload 2>/dev/null || _log WARN "Hyprland is not running. Skipping reload."
	# bash "$REPO_DIR/cli/force_reload_quickshell.sh" || _log WARN "Failed to force reload QuickShell."

    echo "============================================================"
    _log SUCCESS "Configuration loading finished successfully."
    echo "============================================================"
}

#-------------------------------------------------------
# Script Execution
#-------------------------------------------------------
main "$@"
