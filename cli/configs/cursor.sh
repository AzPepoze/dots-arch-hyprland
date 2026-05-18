#!/bin/bash
#----------------------------------------------------------------------
# Cursor Configurator
#
# Installs and configures cursor themes for Hyprland.
#----------------------------------------------------------------------

set -e

#-------------------------------------------------------
# Environment & Setup
#-------------------------------------------------------
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"
CONFIGS_DIR_SYSTEM="$HOME"

# Source project helpers
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    # Fallback log function to avoid capturing output during command substitution
    _log() {
        local level=$1; shift
        echo "[$level] $@" >&2
    }
fi

#-------------------------------------------------------
# Helper Functions
#-------------------------------------------------------
update_cursor_conf() {
    local theme=$1
    local size=$2

    local cursor_lua_file="$CONFIGS_DIR_SYSTEM/.config/hypr/cursor.lua"
    local legacy_cursor_conf="$CONFIGS_DIR_SYSTEM/.config/hypr/cursor.conf"
    mkdir -p "$(dirname "$cursor_lua_file")"

    # Clean up legacy configuration file if present
    rm -f "$legacy_cursor_conf"

    if [ -z "$theme" ]; then
        _log INFO "No cursor theme provided. Creating blank cursor.lua."
        cat /dev/null > "$cursor_lua_file"
        _log SUCCESS "Successfully created blank '$cursor_lua_file'."
        return
    fi
    
    _log INFO "Updating cursor configuration..."

    # Generate custom Lua configuration file
    cat > "$cursor_lua_file" <<- EOL
-- Cursor settings managed by config-loader
hl.env("XCURSOR_THEME", "$theme")
hl.env("XCURSOR_SIZE", "$size")
hl.env("HYPRCURSOR_THEME", "$theme")
hl.env("HYPRCURSOR_SIZE", "$size")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor $theme $size")
end)
EOL

    # Apply GTK cursor preferences
    if command -v gsettings &> /dev/null; then
        _log INFO "Setting GTK cursor theme and size..."
        gsettings set org.gnome.desktop.interface cursor-theme "$theme"
        gsettings set org.gnome.desktop.interface cursor-size "$size"
    fi

    # Allow Flatpaks to read local icons
    if command -v flatpak &> /dev/null; then
        _log INFO "Applying Flatpak cursor overrides..."
        flatpak override --filesystem=~/.icons:ro --user || true
    fi

    _log SUCCESS "Successfully generated '$cursor_lua_file' and applied system settings for theme '$theme' with size $size."
}



configure_cursor_theme() {
    # All status messages are redirected to stderr (>&2) to avoid being captured by command substitution.
    echo "" >&2
    echo "Starting Cursor Theme Installation..." >&2

    local built_themes_dir="$REPO_DIR/dist/cursors"
    local user_icon_dir="$HOME/.local/share/icons"

    if [ ! -d "$built_themes_dir" ] || [ -z "$(ls -A "$built_themes_dir")" ]; then
        _log ERROR "Built cursor themes not found in '$built_themes_dir'."
        echo "Please run the './build_cursors.sh' script from the project root first." >&2
        return 1
    fi

    mapfile -t themes < <(find "$built_themes_dir" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
    if [ ${#themes[@]} -eq 0 ]; then
        _log ERROR "No themes found in '$built_themes_dir'."
        return 1
    fi

    themes+=("None")
    themes+=("Exit")

    echo "Select the cursor theme to install:" >&2
    select theme_name in "${themes[@]}"; do
        case "$theme_name" in
            "None")
                echo "No cursor theme selected. Creating blank configuration." >&2
                echo "" # Return empty string to main
                return 0
                ;;
            "Exit")
                echo "Exiting without installation." >&2
                return 1
                ;;
            *)
                if [[ " ${themes[*]} " =~ " ${theme_name} " ]]; then
                    echo "Installing theme: $theme_name" >&2

                    mkdir -p "$user_icon_dir"
                    echo "Ensured icon directory exists at '$user_icon_dir'" >&2

                    cp -r "$built_themes_dir/$theme_name" "$user_icon_dir/"
                    
                    # Redirect log output to stderr to keep stdout reserved for the return value
                    _log SUCCESS "Copied '$theme_name' to '$user_icon_dir'" >&2
                    
                    # Return the selected theme name to the caller via stdout
                    echo "$theme_name"
                    break
                else
                    _log ERROR "Invalid option '$REPLY'. Please try again."
                fi
                ;;
        esac
    done
}

#-------------------------------------------------------
# Main Logic
#-------------------------------------------------------
main() {
    local selected_cursor_theme
    selected_cursor_theme=$(configure_cursor_theme)

    local configure_status=$?

    if [ "$configure_status" -eq 0 ]; then
        update_cursor_conf "$selected_cursor_theme" "24" # Default cursor size is 24
    else
        _log INFO "Cursor configuration was exited. No changes made."
    fi
}

#-------------------------------------------------------
# Script Execution
#-------------------------------------------------------
main "$@"