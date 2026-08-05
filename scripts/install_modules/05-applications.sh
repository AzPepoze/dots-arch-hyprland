#!/bin/bash

#-------------------------------------------------------
# Group: Applications
#-------------------------------------------------------

install_rofi() {
    _log INFO "Installing Rofi..."
    install_paru_package "rofi" "Rofi"
}


install_vscode() {
    install_paru_package "visual-studio-code-bin" "VS Code"
}

install_discord() {
    install_paru_package "discord" "Discord"
    configure_discord
}

configure_discord() {
    echo "Configuring Discord to skip host updates..."
    local discord_config_dir="$HOME/.config/discord"
    local settings_file="$discord_config_dir/settings.json"

    mkdir -p "$discord_config_dir"

    if [ ! -f "$settings_file" ] || [ ! -s "$settings_file" ]; then
        echo '{"SKIP_HOST_UPDATE": true}' > "$settings_file"
    else
        if command -v jq &> /dev/null; then
            local temp_file=$(mktemp)
            jq '.SKIP_HOST_UPDATE = true' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
        else
            if grep -q "SKIP_HOST_UPDATE" "$settings_file"; then
                sed -i 's/"SKIP_HOST_UPDATE":\s*false/"SKIP_HOST_UPDATE": true/' "$settings_file"
            else
                sed -i 's/{/{"SKIP_HOST_UPDATE": true, /' "$settings_file"
            fi
        fi
    fi
    _log SUCCESS "Discord configuration updated."
}

install_vencord() {
    echo "Installing Vencord (Discord Mod)..."
    sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"
    _log SUCCESS "Vencord installation script executed."
}

install_steam() {
    install_paru_package "steam" "Steam"
}

install_pinta() {
    install_pacman_package "pinta" "Pinta"
}

install_nomacs() {
    install_paru_package "nomacs" "Nomacs"
}

install_youtube_music_pear() {
    install_paru_package "pear-desktop-bin" "YouTube Music (Pear)"
}

install_handbrake() {
    install_paru_package "handbrake" "HandBrake"
}

install_easyeffects() {
    install_flatpak_package "com.github.wwmm.easyeffects" "EasyEffects"

    echo "Installing and enabling EasyEffects systemd service..."
    local service_source="$repo_dir/services/easyeffects.service"
    local service_dest="$HOME/.config/systemd/user/easyeffects.service"

    if [ ! -f "$service_source" ]; then
        _log ERROR "EasyEffects service file not found at $service_source"
        return 1
    fi

    mkdir -p "$(dirname "$service_dest")"
    cp -v "$service_source" "$service_dest"

    systemctl --user enable --now easyeffects.service
    _log SUCCESS "EasyEffects service has been installed and started."
}

install_pavucontrol() {
    install_paru_package "pavucontrol-qt" "Pavucontrol"
}

install_ms_edge_stable() {
    install_paru_package "microsoft-edge-stable-bin" "Microsoft Edge (Stable)"
}

install_zen_browser() {
    install_flatpak_package "app.zen_browser.zen" "Zen Browser"
}

install_switcheroo() {
    install_paru_package "switcheroo" "Switcheroo"
}

install_bleachbit() {
    install_paru_package "bleachbit" "BleachBit"
}

install_qdirstat() {
    install_paru_package "qdirstat" "QDirStat"
}

install_gparted() {
    install_paru_package "gparted" "GParted (Partition Editor)"
}

install_flatseal() {
    install_flatpak_package "com.github.tchx84.Flatseal" "Flatseal"
}

install_gdrive_bisync() {
    install_paru_package "gdrive-bisync" "gdrive-bisync"
}

install_waydroid() {
    echo "Installing Waydroid..."
    paru -S --noconfirm waydroid
    echo "If you experience dragging issues in Waydroid, try running: waydroid prop set persist.waydroid.fake_touch '*.*' or use waydroid-helper to configure it."
}

install_waydroid_helper() {
    echo "Installing Waydroid Helper..."
    paru -S --needed --noconfirm waydroid-helper
}

install_waydroid_extra_script() {
    echo "Installing Waydroid Extra Script..."
    cd /tmp
    git clone https://github.com/casualsnek/waydroid_script
    cd waydroid_script
    python3 -m venv venv
    venv/bin/pip install -r requirements.txt
    sudo venv/bin/python3 main.py
    cd ~
    sudo rm -rf /tmp/waydroid_script
}

install_virt_packages() {
    echo "Installing virtualization packages..."
    paru -S --needed --noconfirm libvirt virt-manager qemu-full dnsmasq dmidecode edk2-ovmf
    echo "Enabling libvirtd.service..."
    sudo systemctl enable --now libvirtd.service
    echo "Adding current user to libvirt group..."
    sudo usermod -aG libvirt,kvm $USER

    echo "Checking for KVM support..."
    if [ -e "/dev/kvm" ]; then
        echo "KVM is available. Virtualization will be hardware-accelerated."
    else
        echo "KVM is not available. Virtualization might be slower."
    fi
    echo "Virtualization packages installation complete."
}

install_n8n() {
    echo "Installing n8n..."
    if ! command -v bun &> /dev/null; then
        echo "Bun is not installed. Please install Bun first."
        return 1
    fi
    bun install -g n8n
    if [ $? -eq 0 ]; then
        echo "n8n installed successfully."
    else
        echo "Failed to install n8n."
        return 1
    fi
    echo "You can now run n8n by typing 'n8n' in your terminal."
}
