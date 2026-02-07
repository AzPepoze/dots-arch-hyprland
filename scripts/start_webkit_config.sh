#!/bin/bash
# Check for dependencies
echo "Checking dependencies for WebKit Config..."

deps_missing=0

if ! pacman -Qs python-gobject &> /dev/null; then
    echo "python-gobject not found."
    deps_missing=1
fi

if ! pacman -Qs gtk4 &> /dev/null; then
    echo "gtk4 not found."
    deps_missing=1
fi

if ! pacman -Qs webkitgtk-6.0 &> /dev/null; then
    echo "webkitgtk-6.0 not found."
    deps_missing=1
fi

if [ $deps_missing -eq 1 ]; then
    echo "Installing missing dependencies..."
    sudo pacman -S --noconfirm python-gobject gtk4 webkitgtk-6.0
fi

# Run the config app
python scripts/config_webkit.py
