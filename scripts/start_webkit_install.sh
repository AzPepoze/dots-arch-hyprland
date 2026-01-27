#!/bin/bash
# Check for dependencies
echo "Checking dependencies for WebKit Installer..."

deps_missing=0

if ! pacman -Qs python-gobject &> /dev/null; then
    echo "python-gobject not found."
    deps_missing=1
fi

if ! pacman -Qs gtk4 &> /dev/null; then
    echo "gtk4 not found."
    deps_missing=1
fi

if ! pacman -Qs webkit2gtk &> /dev/null; then
    echo "webkit2gtk not found."
    deps_missing=1
fi

if [ $deps_missing -eq 1 ]; then
    echo "Installing missing dependencies..."
    sudo pacman -S --noconfirm python-gobject gtk3 webkit2gtk
fi

# Run the installer
python scripts/install_webkit.py
