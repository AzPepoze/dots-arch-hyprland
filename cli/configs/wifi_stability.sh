#!/bin/bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
repo_dir="$REPO_DIR"
source "$REPO_DIR/scripts/install_modules/helpers.sh"

configure_rtw88_disable_deep_lps() {
    _header "Disable rtw88 Deep Low-Power State"
    sudo install -d -m 0755 /etc/modprobe.d
    printf '%s\n' \
        '# Prevent rtw88 USB adapters from getting stuck while leaving deep LPS.' \
        'options rtw88_core disable_lps_deep=Y' |
        sudo tee /etc/modprobe.d/rtw88-rtl8821cu-stability.conf > /dev/null
    _log SUCCESS "Deep LPS will be disabled after rebooting."
}

configure_networkmanager_disable_wifi_powersave() {
    _header "Disable NetworkManager Wi-Fi Power Saving"
    sudo install -d -m 0755 /etc/NetworkManager/conf.d
    printf '%s\n' \
        '[connection]' \
        '# 2 = disable Wi-Fi power saving for NetworkManager connections.' \
        'wifi.powersave=2' |
        sudo tee /etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf > /dev/null
    _log SUCCESS "NetworkManager Wi-Fi power saving will be disabled after rebooting."
}

configure_rtl8821cu_disable_usb_autosuspend() {
    _header "Disable USB Autosuspend for RTL8821CU"
    sudo install -d -m 0755 /etc/udev/rules.d
    printf '%s\n' \
        '# Keep Realtek RTL8821CU (0bda:c811) powered while it is connected.' \
        'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="c811", TEST=="power/control", ATTR{power/control}="on"' |
        sudo tee /etc/udev/rules.d/99-rtl8821cu-no-autosuspend.rules > /dev/null
    sudo udevadm control --reload-rules
    _log SUCCESS "USB autosuspend will be disabled after reconnecting the adapter or rebooting."
}

show_adapter_status() {
    _header "Realtek USB Wi-Fi Adapter Status"
    lsusb -d 0bda:c811 || _log WARN "No RTL8821CU adapter (0bda:c811) is currently detected."
    if command -v nmcli >/dev/null 2>&1; then
        nmcli -f DEVICE,TYPE,STATE,CONNECTION device status || true
    fi
}

apply_all_workarounds() {
    configure_rtw88_disable_deep_lps
    configure_networkmanager_disable_wifi_powersave
    configure_rtl8821cu_disable_usb_autosuspend
    _log SUCCESS "All RTL8821CU stability workarounds are configured. Reboot before testing Wi-Fi."
}

pause() {
    echo
    read -r -p "Press Enter to return to Wi-Fi workarounds..."
}

while true; do
    clear
    echo "============================================================="
    echo " Realtek RTL8821CU Wi-Fi Stability Workarounds"
    echo "============================================================="
    echo "  1) Disable rtw88 deep low-power state (recommended first)"
    echo "  2) Disable NetworkManager Wi-Fi power saving"
    echo "  3) Disable USB autosuspend for RTL8821CU (0bda:c811)"
    echo "  4) Apply all workarounds"
    echo "  5) Show adapter status"
    echo "  0) Back to main menu"
    echo
    read -r -p "Choose an option: " choice

    case "$choice" in
        1) configure_rtw88_disable_deep_lps; pause ;;
        2) configure_networkmanager_disable_wifi_powersave; pause ;;
        3) configure_rtl8821cu_disable_usb_autosuspend; pause ;;
        4) apply_all_workarounds; pause ;;
        5) show_adapter_status; pause ;;
        0) exit 0 ;;
        *) _log WARN "Choose a number from 0 to 5."; pause ;;
    esac
done
