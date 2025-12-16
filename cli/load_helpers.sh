#!/bin/bash
#----------------------------------------------------------------------
# Helper functions for the Config Loader script
#----------------------------------------------------------------------

# Function to read the user model from config.json
get_user_model() {
    if [ -f "$CONFIG_FILE" ]; then
        if command -v jq &> /dev/null; then
            local model
            model=$(jq -r '.model' "$CONFIG_FILE")
            if [ "$model" == "null" ]; then
                _log WARN "Model not found in $CONFIG_FILE. Defaulting to 'pc'."
                echo "pc"
            else
                echo "$model"
            fi
        else
            _log WARN "'jq' command not found. Cannot read model from $CONFIG_FILE. Defaulting to 'pc'."
            echo "pc"
        fi
    else
        _log WARN "$CONFIG_FILE not found. Defaulting to 'pc'."
        echo "pc"
    fi
}

# Function to append content from source file to destination file
append_config_content() {
    local source_file=$1
    local dest_file=$2
    local config_name=$3

    _log INFO "Appending content from '$source_file' to '$dest_file'."

    if [ ! -f "$source_file" ]; then
        _log WARN "Source file for appending not found at '$source_file'. Skipping."
        return
    fi

    local use_sudo=""
    if [[ "$dest_file" == "/etc"* ]]; then
        use_sudo="sudo"
        _log INFO "Using sudo for operations in $dest_file"
    fi

    # Ensure the destination file exists, create if not
    if [ ! -f "$dest_file" ]; then
        _log INFO "Destination file '$dest_file' does not exist. Creating it."
        $use_sudo touch "$dest_file"
    fi

    # Pipe to tee with sudo to handle permissions for appending
    if cat "$source_file" | $use_sudo tee -a "$dest_file" > /dev/null; then
        _log SUCCESS "Successfully appended content to '$dest_file'."
    else
        _log ERROR "Failed to append content to '$dest_file'."
    fi
}

sync_files() {
    local source_path=$1 # Can be a file or a directory
    local dest_path=$2   # Can be a file or a directory
    local config_name=$3
    local exclude_path=$4 # New optional parameter

    echo "--- Loading '$config_name' ---"
    if [ ! -e "$source_path" ]; then # Use -e to check for existence of file or directory
        _log WARN "Source path for '$config_name' not found at '$source_path'. Skipping."
        return
    fi

    local use_sudo=""
    if [[ "$dest_path" == "/etc"* ]]; then
        use_sudo="sudo"
        _log INFO "Using sudo for operations in $dest_path"
    fi

    if [ -d "$source_path" ]; then
        # If source is a directory, ensure destination directory exists
        $use_sudo mkdir -p "$dest_path"

        local rsync_args=("-av")
        if [ -n "$exclude_path" ]; then
            rsync_args+=("--exclude=$exclude_path")
        fi

        # Exclude files with the <add> pattern from rsync, as they are handled separately
        rsync_args+=("--exclude=*<add>*")

        # Removed --delete flag to prevent deleting files in the destination
        $use_sudo rsync "${rsync_args[@]}" "$source_path/" "$dest_path/"
    elif [ -f "$source_path" ]; then
        # If source is a file, check for the <add> pattern
        if [[ "$source_path" == *"<add>"* ]]; then
            local actual_dest_file="${dest_path/<add>/}"
            append_config_content "$source_path" "$actual_dest_file" "$config_name"
        else
            # For regular files, just copy
            $use_sudo mkdir -p "$(dirname "$dest_path")" # Ensure parent directory exists
            $use_sudo cp "$source_path" "$dest_path"
        fi
    fi
    echo "---------------------------"
}

merge_quickshell_colors() {
    echo "--- Merging QuickShell colors.json ---"

    if ! command -v jq &> /dev/null; then
        _log WARN "'jq' command not found. Cannot merge colors.json. Please install it first (e.g., 'sudo pacman -S jq'). Skipping."
        return
    fi

    # Use the catppuccin theme file as the source, based on user's request context
    local repo_colors_file="$REPO_DIR/dots/end4_catppuccin_theme.json"
    local system_colors_file="$CONFIGS_DIR_SYSTEM/.local/state/quickshell/user/generated/colors.json"

    if [ ! -f "$repo_colors_file" ]; then
        # Fallback to the original colors.json if the theme is not found
        repo_colors_file="$REPO_DIR/dots/base/home/local/state/quickshell/user/generated/colors.json"
        _log WARN "Catppuccin theme file not found, falling back to default repo colors.json"
        if [ ! -f "$repo_colors_file" ]; then
            _log WARN "Repo colors.json not found. Skipping."
            return
        fi
    fi

    mkdir -p "$(dirname "$system_colors_file")"

    if [ ! -f "$system_colors_file" ]; then
        _log INFO "No existing colors.json found. Copying from repo."
        if jq -e 'type == "array"' "$repo_colors_file" > /dev/null; then
            jq '.[0]' "$repo_colors_file" > "$system_colors_file"
        else
            cp "$repo_colors_file" "$system_colors_file"
        fi
    else
        _log INFO "Existing colors.json found. Merging with repo version."

        # Fix for potentially corrupted system colors.json (if it's an array)
        if jq -e 'type == "array"' "$system_colors_file" > /dev/null; then
            _log WARN "System colors.json is an array. Fixing by extracting first element."
            local fixed_temp=$(mktemp)
            if jq '.[0]' "$system_colors_file" > "$fixed_temp"; then
                mv "$fixed_temp" "$system_colors_file"
            else
                _log ERROR "Failed to fix system colors.json. Skipping merge."
                rm -f "$fixed_temp"
                return
            fi
        fi

        local temp_file=$(mktemp)
        local merge_failed=false

        # Merge system file (object) with the theme file.
        if jq -e 'type == "array"' "$repo_colors_file" > /dev/null; then
            # Source is an array, extract first element to merge
            jq -s '.[0] * .[1][0]' "$system_colors_file" "$repo_colors_file" > "$temp_file" || merge_failed=true
        else
            # Source is an object, merge directly
            jq -s '.[0] * .[1]' "$system_colors_file" "$repo_colors_file" > "$temp_file" || merge_failed=true
        fi

        if [ "$merge_failed" = false ]; then
            mv "$temp_file" "$system_colors_file"
            _log SUCCESS "Successfully merged colors.json."
        else
            _log ERROR "Failed to merge colors.json with jq. One of the files might have an unexpected format."
            rm -f "$temp_file"
        fi
    fi
    echo "------------------------------------"
}

patch_quickshell_background() {
    echo "--- Patching QuickShell Background ---"
    local qml_file="$HOME/.config/quickshell/ii/modules/ii/background/Background.qml"

    if [ -f "$qml_file" ]; then
        _log INFO "Found QuickShell Background.qml at '$qml_file'. Patching..."
        sed -i 's#visible: opacity > 0#visible: false // opacity > 0#g' "$qml_file"
        sed -i 's#CF.ColorUtils.transparentize(CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75), (bgRoot.wallpaperIsVideo ? 1 : 0))#"transparent"#' "$qml_file"
        _log SUCCESS "Successfully patched QuickShell Background.qml."
    else
        _log WARN "QuickShell Background.qml not found at '$qml_file'. Skipping patch."
    fi
    echo "------------------------------------"
}

# Function to read a boolean value from config.json
get_config_bool() {
    local key=$1
    local default_value=$2

    if [ -f "$CONFIG_FILE" ]; then
        if command -v jq &> /dev/null; then
            local value
            value=$(jq -r --arg key "$key" '.[$key]' "$CONFIG_FILE")
            if [ "$value" == "null" ] || [ -z "$value" ]; then
                _log WARN "Key '$key' not found in $CONFIG_FILE. Defaulting to '$default_value'."
                echo "$default_value"
            else
                echo "$value"
            fi
        else
            _log WARN "'jq' command not found. Cannot read key '$key' from $CONFIG_FILE. Defaulting to '$default_value'."
            echo "$default_value"
        fi
    else
        _log WARN "$CONFIG_FILE not found. Defaulting to '$default_value'."
        echo "$default_value"
    fi
}