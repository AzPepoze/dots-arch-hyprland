#!/bin/bash
set -e

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
	DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
	SOURCE=$(readlink "$SOURCE")
	[[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
CURRENT_SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

REPO_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"
repo_dir="$REPO_DIR"
CONFIGS_DIR_SYSTEM="$HOME"
CONFIG_FILE="$REPO_DIR/config.json"

HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
	source "$HELPER_SCRIPT"
else
	_log() {
		local level=$1
		shift
		echo "[$level] $@" >&2
	}
fi

source "$CURRENT_SCRIPT_DIR/utils/load_helpers.sh"

load_configs_from_source() {
	local source_dir=$1
	local label_suffix=$2

	if [ ! -d "$source_dir" ]; then
		if [[ ! "$label_suffix" == *"custom"* ]]; then
			_log WARN "Configuration source directory not found at '$source_dir'. Skipping."
		fi
		return
	fi

	echo "============================================================"
	echo "Loading configurations from: $source_dir"
	echo "============================================================"

	for base_type_dir in "$source_dir"/*; do
		if [ ! -d "$base_type_dir" ]; then
			continue
		fi

		local base_type_name
		base_type_name=$(basename "$base_type_dir")

		local system_base_path=""
		case "$base_type_name" in
			"home")
				system_base_path="$HOME"
				;;
			"etc")
				system_base_path="/etc"
				;;
			*)
				_log WARN "Unknown base configuration type '$base_type_name'. Skipping."
				continue
				;;
		esac

		find "$base_type_dir" -mindepth 1 -print0 | while IFS= read -r -d $'\0' item; do
			local relative_path="${item#$base_type_dir/}"
			local system_dest_path=""

			echo "$relative_path"

			if [ "$base_type_name" == "home" ]; then
				if [[ "$relative_path" == "config/"* ]]; then
					system_dest_path="$system_base_path/.$relative_path"
				elif [[ "$relative_path" == "local/"* ]]; then
					system_dest_path="$system_base_path/.$relative_path"
				else
					system_dest_path="$system_base_path/$relative_path"
				fi
			elif [ "$base_type_name" == "etc" ]; then
				system_dest_path="$system_base_path/$relative_path"
			fi

			sync_files "$item" "$system_dest_path" "$(basename "$item")$label_suffix" ""
		done
	done
}

update_dots_hyprland() {
	echo
	echo "============================================================="
	echo " Updating dots-hyprland"
	echo "============================================================="

	local monitor_config_path="$HOME/.config/hypr/monitors.conf"
	local temp_dir
	temp_dir=$(mktemp -d)
	local backup_monitor_config_path="$temp_dir/monitors.conf"

	if [ -f "$monitor_config_path" ]; then
		_log INFO "Backing up '$monitor_config_path'..."
		cp "$monitor_config_path" "$backup_monitor_config_path"
	else
		_log WARN "Warning: '$monitor_config_path' not found. Nothing to back up."
	fi

	if [ ! -d "$HOME/dots-hyprland" ]; then
		_log WARN "dots-hyprland directory not found. Skipping dots-hyprland update."
		rm -rf "$temp_dir"
		return
	fi

	cd "$HOME/dots-hyprland"
	_log INFO "Pulling the latest changes for dots-hyprland..."
	git fetch --all
	git reset --hard origin/"$(git branch --show-current || echo "main")"
	git pull
	_log SUCCESS "dots-hyprland repository updated."

	if [ "$FULL_MODE" = true ]; then
		_log INFO "Full mode enabled. Running full install..."
		./setup install -c -f
		_log SUCCESS "dots-hyprland full install finished."
	else
		_log INFO "Cleaning working directory and untracked files..."
		git clean -xdf
		_log INFO "Running unstable update (automated with expect)..."

		if ! command -v expect &> /dev/null; then
			_log ERROR "Error: 'expect' command not found."
			_log INFO "This automation requires 'expect'. Please install it first."
			cd - >/dev/null
			rm -rf "$temp_dir"
			return 1
		fi

		expect <<'END_OF_EXPECT'
set timeout 120

spawn bash ./setup exp-update -f

expect {
    timeout {
        puts "\nError: Timeout waiting for the initial (y/N) prompt."
        exit 1
    }
    -re "\[(y/N)\]:" {
        send "y\r"
    }
}

set timeout 1
expect {
    -re "\[(y/N)\]:" {
        send "y\r"
    }
}

set timeout 120

expect {
    -re "Conflict detected:.*monitors\\.conf" {
        expect -re "Enter your choice \\(1-8*" {
            send "2\r"
        }
        exp_continue
    }
    -re "Enter your choice \\(1-8*" {
        send "1\r"
        exp_continue
    }
    eof {
        exit 0
    }
    timeout {
        puts "\nError: Timeout while waiting for a prompt or for the script to finish."
        exit 1
    }
}
END_OF_EXPECT

		_log SUCCESS "dots-hyprland unstable update finished."
	fi

	cd - >/dev/null

	if [ -f "$backup_monitor_config_path" ]; then
		_log INFO "Restoring '$monitor_config_path'..."
		mkdir -p "$(dirname "$monitor_config_path")"
		cp "$backup_monitor_config_path" "$monitor_config_path"
	fi

	rm -rf "$temp_dir"
}

main() {
	sudo -v

	local skip_gpu=false
	local skip_cursor=false
	local FULL_MODE=false
	local POST_INSTALL_MODE=false

	for arg in "$@"; do
		case $arg in
			--skip-gpu)
				skip_gpu=true
				;;
			--skip-cursor)
				skip_cursor=true
				;;
			--full)
				FULL_MODE=true
				;;
			--post)
				POST_INSTALL_MODE=true
				;;
		esac
	done

	update_dots_hyprland

	if [ "$skip_gpu" = false ]; then
		local gpu_lua_file="$HOME/.config/hypr/gpu.lua"
		if [ ! -f "$gpu_lua_file" ]; then
			echo -e "\n\e[1m[GPU Configurator]\e[0m Primary GPU configuration not found."
			read -p "Would you like to configure your GPU now? [y/N]: " configure_gpu_choice
			if [[ "$configure_gpu_choice" =~ ^[Yy]$ ]]; then
				"$CURRENT_SCRIPT_DIR/configs/gpu.sh"
			else
				_log INFO "Skipping GPU configuration (you can configure it anytime from Utilities menu)."
			fi
		else
			_log INFO "GPU already configured at '$gpu_lua_file'. Skipping auto-configuration."
		fi
	fi

	if [ "$skip_cursor" = false ]; then
		local cursor_lua_file="$HOME/.config/hypr/cursor.lua"
		if [ ! -f "$cursor_lua_file" ]; then
			echo -e "\n\e[1m[Cursor Configurator]\e[0m Cursor configuration not found."
			read -p "Would you like to configure your cursor theme now? [y/N]: " configure_cursor_choice
			if [[ "$configure_cursor_choice" =~ ^[Yy]$ ]]; then
				"$CURRENT_SCRIPT_DIR/configs/cursor.sh"
			else
				_log INFO "Skipping cursor configuration (you can configure it anytime from Utilities menu)."
			fi
		else
			_log INFO "Cursor already configured at '$cursor_lua_file'. Skipping auto-configuration."
		fi
	fi

	local USER_MODEL
	USER_MODEL=$(get_user_model)
	_log INFO "User model detected: $USER_MODEL"

	if [ "$POST_INSTALL_MODE" = true ]; then
		load_configs_from_source "$REPO_DIR/dots/post-install" " (post-install)"
	fi

	load_configs_from_source "$REPO_DIR/dots/base" " (base)"

	if [ -n "$USER_MODEL" ]; then
		local MODEL_CONFIG_DIR="$REPO_DIR/dots/$USER_MODEL"
		if [ -d "$MODEL_CONFIG_DIR" ]; then
			load_configs_from_source "$MODEL_CONFIG_DIR" " ($USER_MODEL)"
		else
			_log WARN "Model-specific configuration directory '$MODEL_CONFIG_DIR' not found. Skipping."
		fi
	fi

	if [[ "$(get_config_bool 'remove_end4_background' 'true')" == "true" ]]; then
		patch_quickshell_background
	else
		_log INFO "Skipping QuickShell background patch based on config.json setting."
	fi

	if [[ "$(get_config_bool 'replace_end4_color_to_catpuccin' 'true')" == "true" ]]; then
		merge_quickshell_colors
	else
		_log INFO "Skipping QuickShell color merge based on config.json setting."
	fi

	_log INFO "Reloading Hyprland configuration..."
	hyprctl reload 2>/dev/null || _log WARN "Hyprland is not running. Skipping reload."
	bash "$REPO_DIR/cli/utils/force_reload_quickshell.sh" || _log WARN "Failed to force reload QuickShell."

	echo "============================================================"
	_log SUCCESS "Configuration loading finished successfully."
	echo "============================================================"
}

main "$@"
