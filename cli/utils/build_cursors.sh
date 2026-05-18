#!/bin/bash

#===============================================================================
# CURSOR BUILD SCRIPT (using pipx)
#-------------------------------------------------------------------------------
# This script converts Windows .ani/.cur cursor themes into the Xcursor format
# by installing and using the 'win2xcur' package via pipx.
# This is the recommended approach for modern Python environments like Arch Linux
# to avoid breaking system packages (PEP 668).
#
# Dependencies: python, python-pipx
# Usage: ./build_cursors.sh
#===============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

#-------------------------------------------------------
# Variables & Setup
#-------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$(dirname "$DIR")"
SRC_DIR="$CLI_DIR/src/cursors"
DEST_DIR="$CLI_DIR/dist/cursors"

# Source helper functions (MUST be at the top)
source "$(dirname "$CLI_DIR")/scripts/install_modules/helpers.sh"



#-------------------------------------------------------
# Functions
#-------------------------------------------------------

check_and_install_deps() {
    echo "Checking for required dependencies..."
    if ! command -v pipx &> /dev/null; then
        _log ERROR "'pipx' command not found. Please install it first."
        echo "On Arch Linux, you can install it with: sudo pacman -S --noconfirm python-pipx"
        exit 1
    fi

    # Ensure pipx has a path configured
    pipx ensurepath &> /dev/null

    if ! pipx list | grep -q win2xcur; then
        _log WARN "'win2xcur' is not installed via pipx. Attempting to install..."
        pipx install win2xcur
        _log SUCCESS "Successfully installed win2xcur via pipx."
    else
        echo "'win2xcur' is already installed via pipx."
    fi

    _log SUCCESS "All dependencies are present and configured."
}

#-------------------------------------------------------
# Main Execution
#-------------------------------------------------------

echo "Starting Cursor Theme Build Process using 'pipx'..."
check_and_install_deps

# Clean and create destination directory
echo "Preparing destination directory: $DEST_DIR"
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

# Find all cursor theme source directories and build them
if [ -d "$SRC_DIR" ]; then
    for theme_path in "$SRC_DIR"/*/; do
        if [ -d "$theme_path" ]; then
            original_theme_name=$(basename "$theme_path")
            # Sanitize the name for use in paths and configs
            theme_name=$(echo "$original_theme_name" | sed 's/ /_/g' | sed 's/Mouse_cursor//g' | sed 's/_$//')
            
            echo "--------------------------------------------------"
            echo "Building theme: '$original_theme_name' -> '$theme_name'"
            echo "--------------------------------------------------"

            output_dir_base="$DEST_DIR/$theme_name"
            output_dir_cursors="$output_dir_base/cursors"
            mkdir -p "$output_dir_cursors"

            # Enable nullglob to prevent errors if a glob pattern matches no files
            shopt -s nullglob
            files_to_convert=("$theme_path"/*.{ani,cur})
            shopt -u nullglob

            if [ ${#files_to_convert[@]} -gt 0 ]; then
                pipx run win2xcur -o "$output_dir_cursors" "${files_to_convert[@]}"
            else
                _log WARN "No .ani or .cur files found in '$theme_path'. Skipping."
                continue # Skip to next theme if no files found
            fi

            # Create the index.theme file
            echo "Creating index.theme for $theme_name"
            cat > "$output_dir_base/index.theme" <<EOF
[Icon Theme]
Name=$theme_name
Comment=Converted from $original_theme_name
Inherits=hicolor
EOF

            _log SUCCESS "Successfully built theme '$theme_name' into '$output_dir_base'"
        fi
    done
else
    _log ERROR "Source directory '$SRC_DIR' not found."
    exit 1
fi

_log SUCCESS "All cursor themes have been built successfully!"
echo "The built themes are located in: $DEST_DIR"