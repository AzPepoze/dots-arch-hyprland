#!/bin/bash
install_dependencies() {
    echo "Checking for Python and python-pyqt6..."

    if ! command -v python &> /dev/null; then
        echo "Python not found. Installing..."
        sudo pacman -S --noconfirm python
    fi

    if ! pacman -Qs python-pyqt6 &> /dev/null; then
        echo "python-pyqt6 not found. Installing..."
        sudo pacman -S --noconfirm python-pyqt6
    fi

    if ! command -v fastfetch &> /dev/null; then
        echo "fastfetch not found. Installing..."
        sudo pacman -S --noconfirm fastfetch
    fi

    echo "Dependencies check complete."
}

install_dependencies

#-------------------------------------------------------
# Menu Display
#-------------------------------------------------------

show_menu() {
    fastfetch
    echo -e "\e[1m\e[34m========================================\e[0m"
    echo -e "\e[1m\e[32m  Az Arch Hyprland Management Script  \e[0m"
    echo -e "\e[1m\e[34m========================================\e[0m"
    echo -e "\e[1mPlease choose an option:\e[0m"
    echo -e "  \e[32m1)\e[0m Run Installer"
    echo -e "  \e[32m2)\e[0m Open Configuration Editor"
    echo -e "  \e[32m3)\e[0m Load Dotfile Configurations"
    echo -e "  \e[32m4)\e[0m Update"
    echo -e "  \e[32m5)\e[0m Update (Full)"
    echo -e "  \e[32mq)\e[0m Quit"
    echo -e "\e[1m\e[34m----------------------------------------\e[0m"
}

#-------------------------------------------------------
# Main Script Logic
#-------------------------------------------------------
while true; do
    clear # Clear the screen before showing the menu
    show_menu
    read -p "Enter your choice [1-5, q]: " choice

    case $choice in
        1)
            echo "Starting Installer..."
            python scripts/install.py
            break
            ;;
        2)
            echo "Starting Configuration Editor..."
            python scripts/config.py
            ;;
        3)
            echo "Loading configurations..."
            if [ -f "cli/load_configs.sh" ]; then
                bash cli/load_configs.sh
            else
                echo "Error: cli/load_configs.sh not found!"
            fi
            break
            ;;
        4)
            echo "Starting Update..."
            if [ -f "update.sh" ]; then
                bash update.sh --skip-cursor --skip-gpu
            else
                echo "Error: update.sh not found!"
            fi
            break
            ;;
        5)
            echo "Starting Full Update..."
            if [ -f "cli/rank-mirrors.sh" ]; then
                bash cli/rank-mirrors.sh
            else
                echo "Error: cli/rank-mirrors.sh not found!"
            fi
            if [ -f "update.sh" ]; then
                bash update.sh --full
            else
                echo "Error: update.sh not found!"
            fi
            break
            ;;
        q|Q)
            echo "Exiting."
            break
            ;;
        *)
            echo "Invalid option. Please try again.
"
            ;;
    esac
done