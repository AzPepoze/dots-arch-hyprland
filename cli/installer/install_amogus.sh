#!/bin/bash

# Define source and destination paths
SOURCE_FILE="/home/azpepoze/dots-arch-hyprland/cli/amogus.sh"
DEST_DIR="/usr/local/bin"
DEST_FILE="$DEST_DIR/amogus"

echo "Starting installation of amogus..."

# Check if cowsay is installed, if not, install it using paru
if ! command -v cowsay &> /dev/null
then
    echo "cowsay not found. Installing cowsay using paru..."
    paru -S cowsay --noconfirm
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install cowsay. Please check paru installation and permissions."
        exit 1
    fi
else
    echo "cowsay is already installed."
fi

# Check if the source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file '$SOURCE_FILE' not found."
    exit 1
fi

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory: $DEST_DIR"
    sudo mkdir -p "$DEST_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create directory '$DEST_DIR'. Please check permissions."
        exit 1
    fi
fi

# Create a symbolic link
echo "Creating symbolic link from '$SOURCE_FILE' to '$DEST_FILE'..."
sudo ln -sf "$SOURCE_FILE" "$DEST_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create symbolic link. Please check permissions."
    exit 1
fi

# Make the file executable
echo "Setting execute permissions for '$DEST_FILE'..."
sudo chmod +x "$DEST_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Failed to set execute permissions. Please check permissions."
    exit 1
fi

echo "amogus installed successfully! You can now run 'amogus' from anywhere."
echo "To uninstall, you can run: sudo rm $DEST_FILE"