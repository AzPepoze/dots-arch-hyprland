#!/bin/bash
# Check for dependencies
echo "Checking dependencies for WebKit Config..."

deps_missing=0

if ! pacman -Qs python-gobject &> /dev/null; then
    echo "python-gobject not found."
    deps_missing=1
fi

if ! pacman -Qs gtk4 &> /dev/null; then
    # Checking gtk4 as generic check, though script uses gtk3 via gi
    echo "gtk4 (or gtk3) check..."
fi

if ! pacman -Qs webkit2gtk &> /dev/null; then
    echo "webkit2gtk not found."
    deps_missing=1
fi

if [ $deps_missing -eq 1 ]; then
    echo "Installing missing dependencies..."
    sudo pacman -S --noconfirm python-gobject gtk3 webkit2gtk
fi

# Run the config app
python scripts/config_webkit.py
