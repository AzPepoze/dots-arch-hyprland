#!/bin/bash

#-------------------------------------------------------
# Group: Desktop & Theming
#-------------------------------------------------------

install_nwg_look() {
    _log INFO "Installing nwg-look..."
    install_paru_package "nwg-look" "nwg-look"
}

install_qt5ct() {
    install_paru_package "qt5ct" "Qt5 Configuration Tool"
}

install_qt6ct() {
    _log INFO "Installing qt6ct..."
    install_paru_package "qt6ct" "qt6ct"
}

install_sddm_theme() {
     echo "Installing SDDM Astronaut Theme..."
     sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
     echo "SDDM Astronaut Theme installation attempted."
}

install_catppuccin_grub_theme() {
    # Use the first argument as the theme flavor, default to 'mocha'
    local flavor=${1:-mocha}
    local capitalized_flavor="$(tr '[:lower:]' '[:upper:]' <<< ${flavor:0:1})${flavor:1}"

    echo "Installing Catppuccin $capitalized_flavor theme for GRUB..."
    _check_grub_file_exists || return 1

    if ! command -v git &> /dev/null;
 then
        _log ERROR "git is not installed. Please install it first."
        return 1
    fi

    local theme_name="catppuccin-$flavor"
    local grub_themes_dir="/usr/share/grub/themes"
    local target_theme_dir="$grub_themes_dir/$theme_name"
    local grub_file="/etc/default/grub"
    local tmp_dir="/tmp/grub-catppuccin-theme"
    local theme_path="$target_theme_dir/theme.txt"

    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
    git clone --depth 1 https://github.com/catppuccin/grub.git "$tmp_dir"
    if [ $? -ne 0 ]; then
        _log ERROR "Failed to clone the repository."
        return 1
    fi

    local source_theme_dir="$tmp_dir/src/catppuccin-$flavor-grub-theme"

    if [ ! -d "$source_theme_dir" ]; then
        _log ERROR "Source theme directory for '$flavor' not found after cloning!"
        rm -rf "$tmp_dir"
        return 1
    fi

    echo "Installing theme to $target_theme_dir..."
    sudo mkdir -p "$target_theme_dir"
    sudo cp -r "$source_theme_dir/"* "$target_theme_dir/"
    if [ $? -ne 0 ]; then
        _log ERROR "Failed to copy theme files."
        rm -rf "$tmp_dir"
        return 1
    fi

    echo "Setting GRUB_THEME in $grub_file..."
    if sudo grep -q '^GRUB_THEME=' "$grub_file"; then
        sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme_path\"|" "$grub_file"
    else
        echo "GRUB_THEME=\"$theme_path\"" | sudo tee -a "$grub_file" >/dev/null
    fi

    echo "Cleaning up temporary files..."
    rm -rf "$tmp_dir"

    _regenerate_grub_config

    _log SUCCESS "Catppuccin $capitalized_flavor GRUB theme installed and configured successfully."
}

select_and_install_catppuccin_grub_theme() {
    local flavors=("mocha" "latte" "frappe" "macchiato" "Exit")
    echo "Please select a Catppuccin flavor for GRUB (default is mocha):"
    
    PS3="Enter your choice [1-5]: "
    
    select flavor in "${flavors[@]}"; do
        if [ -z "$REPLY" ]; then
            flavor="mocha"
        fi

        if [[ " ${flavors[*]} " =~ " ${flavor} " ]]; then
            if [ "$flavor" == "Exit" ]; then
                _log WARN "Skipping GRUB theme installation."
                break
            fi
            _log INFO "You selected: $flavor"
            install_catppuccin_grub_theme "$flavor"
            break
        else
            echo "Invalid option '$REPLY'. Please try again."
        fi
    done
    PS3="#? "
}

install_cursors() {
    echo "Starting Cursor Theme Installation..."
    if [ ! -d "$BUILT_THEMES_DIR" ] || [ -z "$(ls -A "$BUILT_THEMES_DIR")" ]; then
        _log ERROR "Built cursor themes not found in '$BUILT_THEMES_DIR'."
        echo "Please run the './build_cursors.sh' script from the project root first."
        return 1
    fi

    mapfile -t themes < <(find "$BUILT_THEMES_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
    if [ ${#themes[@]} -eq 0 ]; then
        _log ERROR "No themes found in '$BUILT_THEMES_DIR'."
        return 1
    fi

    themes+=("Exit")
    echo "Select the cursor theme to install:"
    select theme_name in "${themes[@]}"; do
        case "$theme_name" in
            "Exit")
                echo "Exiting without installation."
                return 0
                ;; 
            *)
                if [[ " ${themes[*]} " =~ " ${theme_name} " ]]; then
                    echo "Installing theme: $theme_name"
                    mkdir -p "$USER_ICON_DIR"
                    cp -r "$BUILT_THEMES_DIR/$theme_name" "$USER_ICON_DIR/"
                    _log SUCCESS "Copied '$theme_name' to '$USER_ICON_DIR'"
                    jq --arg theme "$theme_name" '.cursor.theme = $theme' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                    _log SUCCESS "Updated cursor theme in config file."

                    # Immediately apply GTK settings
                    if command -v gsettings &> /dev/null; then
                        _log INFO "Setting GTK cursor theme..."
                        gsettings set org.gnome.desktop.interface cursor-theme "$theme_name"
                    fi

                    # Apply Flatpak overrides
                    if command -v flatpak &> /dev/null; then
                        _log INFO "Applying Flatpak cursor overrides..."
                        flatpak override --filesystem=~/.icons:ro --user || true
                    fi

                    break
                else
                    _log ERROR "Invalid option '$REPLY'. Please try again."
                fi
                ;; 
        esac
    done
}

copy_thai_fonts_css() {
    local source_file="$repo_dir/settings/thai_fonts.css"
    local dest_file="$HOME/.var/app/dev.vencord.Vesktop/config/vesktop/settings/quickCss.css"
    local dest_dir
    dest_dir=$(dirname "$dest_file")
    echo "Copying Thai fonts CSS for Vesktop..."
    if [ ! -f "$source_file" ]; then
        _log ERROR "Source file not found at $source_file"
        return 1
    fi
    mkdir -p "$dest_dir"
    cp -v "$source_file" "$dest_file"
    _log SUCCESS "Successfully copied thai_fonts.css to the Vesktop directory."
}

