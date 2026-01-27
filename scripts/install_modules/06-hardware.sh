#!/bin/bash

#-------------------------------------------------------
# Group: Hardware & Peripherals
#-------------------------------------------------------

install_v4l2loopback() {
    install_paru_package "v4l2loopback-dkms" "v4l2loopback"
    echo "Adding v4l2loopback to /etc/modules-load.d/v4l2loopback.conf to load on boot..."
    echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf > /dev/null
    _log SUCCESS "v4l2loopback module configuration completed."
}

install_droidcam() {
    install_paru_package "droidcam" "Droidcam"
}

install_mx002_driver() {
    echo "Installing MX002 Tablet Driver..."
    if ! command -v cargo &> /dev/null; then
        echo "Rust is not installed. Installing rustup..."
        if ! command -v curl &> /dev/null; then
            echo "Error: curl is required to install rustup."
            return 1
        fi
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    else
        echo "Rust is already installed."
    fi

    rm -rf "$HOME/mx002_linux_driver" 2>/dev/null
    local repo_url="https://github.com/marvinbelfort/mx002_linux_driver"
    local clone_dir=$(mktemp -d)"/mx002_linux_driver"

    if [ ! -d "$clone_dir" ]; then
        if ! git clone "$repo_url" "$clone_dir"; then
            echo "Error: Failed to clone the repository."
            return 1
        fi
    fi
    
    cd "$clone_dir"
    echo "Building driver with Cargo..."
    if cargo build --release; then
        echo "Driver built successfully."
        local built="$clone_dir/target/release"
        if [ -d "$built" ]; then
            mv "$built" "$HOME/mx002_linux_driver"
            echo "Driver is located at $HOME/mx002_linux_driver"
            echo "NOTE: You may need to run it with sudo."
        else
            echo "Error: Built driver not found at the expected location."
        fi
    else
        echo "Error: Failed to build the driver."
        cd "$repo_dir"
        return 1
    fi
    cd "$repo_dir"
    echo "MX002 Tablet Driver installation process finished."
}

install_wallpaper_engine() {
     install_paru_package "linux-wallpaperengine-git" "Wallpaper Engine"
}

install_wallpaper_engine_gui() {
     install_paru_package "linux-wallpaperengine-gui" "Wallpaper Engine GUI"
}
