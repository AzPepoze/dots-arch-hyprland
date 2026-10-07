#!/bin/bash

get_user_model() {
	if [ ! -f "$CONFIG_FILE" ]; then
		_log WARN "$CONFIG_FILE not found. Defaulting to 'pc'." >&2
		echo "pc"
		return
	fi

	if ! command -v jq &> /dev/null; then
		_log WARN "'jq' command not found. Defaulting to 'pc'." >&2
		echo "pc"
		return
	fi

	local model
	model=$(jq -r '.model' "$CONFIG_FILE")
	if [ "$model" == "null" ] || [ -z "$model" ]; then
		_log WARN "Model not found in $CONFIG_FILE. Defaulting to 'pc'." >&2
		echo "pc"
	else
		echo "$model"
	fi
}

append_config_content() {
	local source_file=$1
	local dest_file=$2
	local config_name=$3

	_log INFO "Appending content from '$source_file' to '$dest_file'."

	if [ ! -f "$source_file" ]; then
		_log WARN "Source file for appending not found at '$source_file'. Skipping."
		return
	fi

	local use_sudo=""
	if [[ "$dest_file" == "/etc"* ]]; then
		use_sudo="sudo"
		_log INFO "Using sudo for operations in $dest_file"
	fi

	if [ ! -f "$dest_file" ]; then
		_log INFO "Destination file '$dest_file' does not exist. Creating it."
		$use_sudo touch "$dest_file"
	fi

	if $use_sudo tee -a "$dest_file" < "$source_file" > /dev/null; then
		_log SUCCESS "Successfully appended content to '$dest_file'."
	else
		_log ERROR "Failed to append content to '$dest_file'."
	fi
}

sync_files() {
	local source_path=$1
	local dest_path=$2
	local config_name=$3
	local exclude_path=$4

	echo "--- Loading '$config_name' ---"
	if [ ! -e "$source_path" ]; then
		_log WARN "Source path for '$config_name' not found at '$source_path'. Skipping."
		return
	fi

	local use_sudo=""
	if [[ "$dest_path" == "/etc"* ]]; then
		use_sudo="sudo"
		_log INFO "Using sudo for operations in $dest_path"
	fi

	if [ -d "$source_path" ]; then
		$use_sudo mkdir -p "$dest_path"

		local rsync_args=("-av")
		if [ -n "$exclude_path" ]; then
			rsync_args+=("--exclude=$exclude_path")
		fi
		rsync_args+=("--exclude=*<add>*")

		$use_sudo rsync "${rsync_args[@]}" "$source_path/" "$dest_path/"
	elif [ -f "$source_path" ]; then
		if [[ "$source_path" == *"<add>"* ]]; then
			local actual_dest_file="${dest_path/<add>/}"
			append_config_content "$source_path" "$actual_dest_file" "$config_name"
		else
			$use_sudo mkdir -p "$(dirname "$dest_path")"
			$use_sudo cp "$source_path" "$dest_path"
		fi
	fi
	echo "---------------------------"
}

merge_quickshell_colors() {
	echo "--- Merging QuickShell colors.json ---"

	if ! command -v jq &> /dev/null; then
		_log WARN "'jq' command not found. Cannot merge colors.json. Skipping."
		return
	fi

	local repo_colors_file="$REPO_DIR/dots/end4_catppuccin_theme.json"
	local system_colors_file="$CONFIGS_DIR_SYSTEM/.local/state/quickshell/user/generated/colors.json"

	if [ ! -f "$repo_colors_file" ]; then
		repo_colors_file="$REPO_DIR/dots/base/home/local/state/quickshell/user/generated/colors.json"
		_log WARN "Catppuccin theme file not found, falling back to default repo colors.json"
		if [ ! -f "$repo_colors_file" ]; then
			_log WARN "Repo colors.json not found. Skipping."
			return
		fi
	fi

	mkdir -p "$(dirname "$system_colors_file")"

	if [ ! -f "$system_colors_file" ]; then
		_log INFO "No existing colors.json found. Copying from repo."
		if jq -e 'type == "array"' "$repo_colors_file" > /dev/null; then
			jq '.[0]' "$repo_colors_file" > "$system_colors_file"
		else
			cp "$repo_colors_file" "$system_colors_file"
		fi
		echo "------------------------------------"
		return
	fi

	_log INFO "Existing colors.json found. Merging with repo version."

	if jq -e 'type == "array"' "$system_colors_file" > /dev/null; then
		_log WARN "System colors.json is an array. Fixing by extracting first element."
		local fixed_temp
		fixed_temp=$(mktemp)
		if jq '.[0]' "$system_colors_file" > "$fixed_temp"; then
			mv "$fixed_temp" "$system_colors_file"
		else
			_log ERROR "Failed to fix system colors.json. Skipping merge."
			rm -f "$fixed_temp"
			return
		fi
	fi

	local temp_file
	temp_file=$(mktemp)

	if jq -e 'type == "array"' "$repo_colors_file" > /dev/null; then
		jq -s '.[0] * .[1][0]' "$system_colors_file" "$repo_colors_file" > "$temp_file"
	else
		jq -s '.[0] * .[1]' "$system_colors_file" "$repo_colors_file" > "$temp_file"
	fi

	if [ $? -eq 0 ] && [ -s "$temp_file" ]; then
		mv "$temp_file" "$system_colors_file"
		_log SUCCESS "Successfully merged colors.json."
	else
		_log ERROR "Failed to merge colors.json."
		rm -f "$temp_file"
	fi
	echo "------------------------------------"
}

patch_quickshell_background() {
	echo "--- Patching QuickShell Background ---"
	local shell_name qml_file patched=false
	for shell_name in ii end4-pC; do
		qml_file="$HOME/.config/quickshell/$shell_name/modules/ii/background/Background.qml"
		if [ ! -f "$qml_file" ]; then
			continue
		fi
		_log INFO "Found QuickShell Background.qml at '$qml_file'. Patching..."
		# ii pattern
		sed -i 's#visible: opacity > 0 && !blurLoader.active#visible: false // opacity > 0 \&\& !blurLoader.active#g' "$qml_file"
		# end4-pC patterns (prepend false && to keep multi-line bindings valid)
		sed -i 's#visible: !blurLoader.active#visible: false \&\& !blurLoader.active#g' "$qml_file"
		sed -i 's#visible: !bgRoot.videoRevealed#visible: false \&\& !bgRoot.videoRevealed#g' "$qml_file"
		sed -i 's#return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);#return "transparent"; // Original mix code removed#g' "$qml_file"
		patched=true
	done
	if [ "$patched" = true ]; then
		_log SUCCESS "Successfully patched QuickShell Background.qml."
	else
		_log WARN "QuickShell Background.qml not found (checked ii, end4-pC). Skipping patch."
	fi
	echo "------------------------------------"
}

ensure_end4_shell() {
	echo "--- Ensuring end4-pC QuickShell ---"
	local shell_dir="$HOME/.config/quickshell/end4-pC"
	local shell_repo="https://github.com/pctrade/end4-pC"

	if [ ! -f "$shell_dir/shell.qml" ]; then
		_log INFO "end4-pC shell not found. Installing..."
		mkdir -p "$(dirname "$shell_dir")"
		if git clone "$shell_repo" "$shell_dir"; then
			_log SUCCESS "end4-pC shell installed."
		else
			_log ERROR "Failed to clone end4-pC shell."
		fi
	elif [ -d "$shell_dir/.git" ]; then
		_log INFO "end4-pC shell found. Updating..."
		# Local tweaks (bg removal, game-mode toggle wiring) travel via stash.
		git -C "$shell_dir" stash push -qm "local tweaks" || true
		if git -C "$shell_dir" pull --ff-only; then
			_log SUCCESS "end4-pC shell updated."
		else
			_log WARN "Could not fast-forward end4-pC shell. Skipping."
		fi
		if ! git -C "$shell_dir" stash pop -q; then
			_log WARN "Could not restore local shell tweaks (conflict?). Check git status in $shell_dir."
		fi
	else
		_log WARN "end4-pC directory exists but is not a git repo. Skipping update."
	fi
	echo "------------------------------------"
}

get_config_bool() {
	local key=$1
	local default_value=$2

	if [ ! -f "$CONFIG_FILE" ]; then
		_log WARN "$CONFIG_FILE not found. Defaulting to '$default_value'." >&2
		echo "$default_value"
		return
	fi

	if ! command -v jq &> /dev/null; then
		_log WARN "'jq' command not found. Defaulting to '$default_value'." >&2
		echo "$default_value"
		return
	fi

	local value
	value=$(jq -r --arg key "$key" '.[$key]' "$CONFIG_FILE")
	if [ "$value" == "null" ] || [ -z "$value" ]; then
		_log WARN "Key '$key' not found in $CONFIG_FILE. Defaulting to '$default_value'." >&2
		echo "$default_value"
	else
		echo "$value"
	fi
}

disable_shell_overrides() {
	echo "--- Disabling shell Hyprland overrides ---"
	local hyprland_lua="$HOME/.config/hypr/hyprland.lua"
	if [ ! -f "$hyprland_lua" ]; then
		_log WARN "hyprland.lua not found. Skipping."
		return
	fi
	# dots-hyprland updates re-enable this require; the shell must stay out
	# of Hyprland settings (custom/general.lua owns kb_layout, blur, ...).
	if grep -q '^require("hyprland.shellOverrides.main")' "$hyprland_lua"; then
		sed -i 's#^require("hyprland.shellOverrides.main")#-- require("hyprland.shellOverrides.main") -- disabled: shell must not override Hyprland settings#' "$hyprland_lua"
		_log SUCCESS "Shell overrides disabled."
	else
		_log INFO "Shell overrides already disabled. Skipping."
	fi
	echo "------------------------------------"
}
