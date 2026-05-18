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
# CLI Script Discovery & Display Helpers
#-------------------------------------------------------
get_display_name() {
    local rel_path=$1
    local cleaned="${rel_path#cli/}"
    cleaned="${cleaned#utils/}"
    cleaned="${cleaned%.sh}"
    cleaned="${cleaned//_/ }"
    cleaned="${cleaned//\// - }"
    echo "$cleaned" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

#-------------------------------------------------------
# Utility CLI Submenu Display & Logic
#-------------------------------------------------------
show_utility_menu() {
    clear
    echo -e "\e[1m\e[34m========================================\e[0m"
    echo -e "\e[1m\e[32m       System Utility CLI Tools        \e[0m"
    echo -e "\e[1m\e[34m========================================\e[0m"
    
    echo -e "\e[1;36m--- Interactive Configurations ---\e[0m"
    echo -e "  \e[32m1)\e[0m Configure Cursor Theme"
    echo -e "  \e[32m2)\e[0m Configure GPU Devices"
    echo -e "  \e[32m3)\e[0m Manage Drives (fstab auto-mount)"
    echo -e "  \e[32m4)\e[0m Select Boot Entry (Reboot)"
    
    echo -e "\e[1;36m--- System Maintenance & Helpers ---\e[0m"
    echo -e "  \e[32m5)\e[0m Run System Cleanup"
    echo -e "  \e[32m6)\e[0m Empty Trash Files"
    echo -e "  \e[32m7)\e[0m Rank Package Mirrors"
    echo -e "  \e[32m8)\e[0m Compile Cursor Themes (win2xcur)"
    echo -e "  \e[32m9)\e[0m Set Kitty as Default Terminal"
    echo -e "  \e[32m10)\e[0m Force Reload QuickShell"
    
    echo -e "\e[1;36m--- Special Configurations & Fun ---\e[0m"
    echo -e "  \e[32m11)\e[0m Enable/Disable SDDM Autologin"
    echo -e "  \e[32m12)\e[0m Amogus Sus Cowsay"
    
    # Discover other scripts dynamically that are not listed above (main level only)
    other_scripts=()
    if [ -d "cli" ]; then
        while read -r script; do
            local base_name
            base_name=$(basename "$script")
            if [[ "$script" != "cli/boot_to.sh" \
               && "$script" != "cli/mount_drive_manager.sh" \
               && "$base_name" != "load_configs.sh" ]]; then
                other_scripts+=("$script")
            fi
        done < <(find cli -maxdepth 1 -type f -name "*.sh" | sort)
    fi

    local index=13
    if [ ${#other_scripts[@]} -gt 0 ]; then
        echo -e "\e[1;36m--- Other Dynamic Utilities ---\e[0m"
        for os in "${other_scripts[@]}"; do
            echo -e "  \e[32m${index})\e[0m $(get_display_name "$os")"
            index=$((index+1))
        done
    fi
    
    echo -e "\e[1;34m----------------------------------------\e[0m"
    echo -e "  \e[32b)\e[0m Back to Main Menu"
    echo -e "\e[1m\e[34m========================================\e[0m"
}

run_utility_submenu() {
    while true; do
        # Discover other scripts inside loop to support dynamic changes
        local other_scripts=()
        if [ -d "cli" ]; then
            while read -r script; do
                local base_name
                base_name=$(basename "$script")
                if [[ "$script" != "cli/boot_to.sh" \
                   && "$script" != "cli/mount_drive_manager.sh" \
                   && "$base_name" != "load_configs.sh" ]]; then
                    other_scripts+=("$script")
                fi
            done < <(find cli -maxdepth 1 -type f -name "*.sh" | sort)
        fi
        
        show_utility_menu
        local max_choice=$((12 + ${#other_scripts[@]}))
        read -p "Enter utility choice [1-$max_choice, b]: " ut_choice
        
        case "$ut_choice" in
            1)
                echo -e "\nRunning Cursor Configurator..."
                bash cli/configs/cursor.sh
                ;;
            2)
                echo -e "\nRunning GPU Configurator..."
                bash cli/configs/gpu.sh
                ;;
            3)
                echo -e "\nRunning Drive Mount Manager..."
                bash cli/mount_drive_manager.sh
                ;;
            4)
                echo -e "\nRunning Boot Entry Selector..."
                bash cli/boot_to.sh
                ;;
            5)
                echo -e "\nRunning System Cleanup..."
                bash cli/utils/cleanup.sh
                ;;
            6)
                echo -e "\nRunning Empty Trash..."
                bash cli/utils/clear_trash.sh
                ;;
            7)
                echo -e "\nRanking Mirror Lists..."
                bash cli/utils/rank_mirrors.sh
                ;;
            8)
                echo -e "\nCompiling Cursor Themes..."
                bash cli/utils/build_cursors.sh
                ;;
            9)
                echo -e "\nSetting Kitty as Default Terminal..."
                bash cli/utils/set_kitty_main_terminal.sh
                ;;
            10)
                echo -e "\nForce Reloading QuickShell..."
                bash cli/utils/force_reload_quickshell.sh
                ;;
            11)
                echo -e "\nConfigure SDDM Autologin..."
                echo "This configuration requires root privileges."
                echo "1) Enable autologin for $USER"
                echo "2) Disable autologin"
                read -p "Choose action [1-2]: " autologin_choice
                if [ "$autologin_choice" -eq 1 ]; then
                    sudo bash cli/configs/auto_login.sh enable
                elif [ "$autologin_choice" -eq 2 ]; then
                    sudo bash cli/configs/auto_login.sh disable
                fi
                ;;
            12)
                echo -e "\nAmogus Sus Cowsay..."
                read -p "Enter custom message (leave blank for default): " amogus_msg
                if [ -z "$amogus_msg" ]; then
                    bash cli/utils/amogus.sh
                else
                    bash cli/utils/amogus.sh "$amogus_msg"
                fi
                ;;
            b|B)
                break
                ;;
            *)
                # Handle dynamic other scripts
                if [[ "$ut_choice" =~ ^[0-9]+$ ]] && (( ut_choice >= 13 && ut_choice <= max_choice )); then
                    local target_idx=$((ut_choice - 13))
                    local selected_script="${other_scripts[$target_idx]}"
                    echo -e "\n\e[1m\e[32mRunning: $(get_display_name "$selected_script")...\e[0m"
                    bash "$selected_script"
                else
                    echo "Invalid selection. Please try again."
                    sleep 1
                    continue
                fi
                ;;
        esac
        echo -e "\nPress Enter to return to Utilities Menu..."
        read -r
    done
}

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
    echo -e "  \e[32m6)\e[0m Open Utility CLI Tools Menu"
    echo -e "  \e[32mq)\e[0m Quit"
    echo -e "\e[1m\e[34m----------------------------------------\e[0m"
}

#-------------------------------------------------------
# Main Script Logic
#-------------------------------------------------------
while true; do
    clear
    show_menu
    read -p "Enter your choice [1-6, q]: " choice

    case $choice in
        1)
            echo "Starting Installer..."
            bash scripts/start_webkit_install.sh
            break
            ;;
        2)
            echo "Starting Configuration Editor..."
            bash scripts/start_webkit_config.sh
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
            if [ -f "update.sh" ]; then
                bash update.sh --full
            else
                echo "Error: update.sh not found!"
            fi
            break
            ;;
        6)
            run_utility_submenu
            ;;
        q|Q)
            echo "Exiting."
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 1
            ;;
    esac
done