#!/bin/bash

#-------------------------------------------------------
# Preamble
#-------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$DIR/.."
HELPER_SCRIPT="$PROJECT_ROOT/scripts/install_modules/helpers.sh"
if [ ! -f "$HELPER_SCRIPT" ]; then
    echo "Error: Helper script not found at $HELPER_SCRIPT"
    exit 1
fi
source "$HELPER_SCRIPT"

#-------------------------------------------------------
# GPU Configuration Check
#-------------------------------------------------------
if ! bash "$PROJECT_ROOT/scripts/utils/check_valid_gpu.sh"; then
    if command -v notify-send &> /dev/null; then
        notify-send "GPU Configuration Error" "A configured GPU device is not detected. Please check your configuration." -i dialog-error
    fi
fi

#-------------------------------------------------------
# Helper Functions
#-------------------------------------------------------
launch_app() {
    local app_name="$1"
    local launch_command="$2"
    local sleep_after=${3:-0}

    echo "Starting $app_name..."
    eval "$launch_command"
    _log SUCCESS "$app_name started."

    if [ "$sleep_after" -gt 0 ]; then
        sleep "$sleep_after"
    fi
}

launch_messenger() {
    echo "Starting Messenger..."
    local messenger_desktop_file
    messenger_desktop_file=$(grep -l "^Name=Messenger$" ~/.local/share/applications/*.desktop /usr/share/applications/*.desktop 2>/dev/null | head -n 1)

    if [ -n "$messenger_desktop_file" ]; then
        local app_id
        app_id=$(basename "$messenger_desktop_file" .desktop)
        local launch_command="hyprctl dispatch exec \"[workspace 1 silent] gtk-launch ${app_id}\""
        launch_app "Messenger" "$launch_command" 2
    else
        _log WARN "Messenger desktop file not found. Skipping Messenger launch."
    fi
}

#-------------------------------------------------------
# Background Services
#-------------------------------------------------------
# launch_app "rclone sync" "bash $HOME/dots-arch-hyprland/scripts/rclone/sync.sh &"
# bash $HOME/dots-arch-hyprland/scripts/utils/notification_logger.sh &

#-------------------------------------------------------
# Startup Programs
#-------------------------------------------------------
launch_app "Linux Wallpaper Engine GUI" "sleep 1 && linux-wallpaperengine-gui --minimized &"
launch_messenger
# launch_app "Discord" "hyprctl dispatch exec \"[workspace 1 silent] discord\"" 2
# launch_app "Edge App" "hyprctl dispatch exec '[tile;] microsoft-edge-dev --app=chrome-extension://ophjlpahpchlmihnnnihgmmeilfjmjjc/index.html'"
launch_app "Wineboot (Delayed)" "hyprctl dispatch exec \"[workspace 4 silent] sh -c 'sleep 10 && wineboot'\""

# scratchpad
# launch_app "YouTube Music" "hyprctl dispatch exec \"[workspace special silent; float; size 30% 100%; move 0 0] youtube-music\""

# sleep 5
# hyprctl dispatch workspace 1
