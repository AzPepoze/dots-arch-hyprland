#!/bin/bash

#-------------------------------------------------------
# Group: Session, Power & Graphics Profiles
#-------------------------------------------------------

_profile_packages() {
    local profile_file="$1"

    if [ ! -f "$profile_file" ]; then
        _log ERROR "Package profile not found: $profile_file"
        return 1
    fi

    sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$profile_file"
}

_install_official_profile() {
    local profile_file="$1"
    local profile_name="$2"
    local packages=()
    mapfile -t packages < <(_profile_packages "$profile_file") || return 1

    if [ "${#packages[@]}" -eq 0 ]; then
        _log INFO "$profile_name has no additional packages."
        return 0
    fi

    _log INFO "$profile_name: ${packages[*]}"
    if [ "${POWER_STACK_DRY_RUN:-0}" = "1" ]; then
        return 0
    fi

    resolve_pacman_file_conflicts
    sudo pacman -S --needed --noconfirm "${packages[@]}"
}

_installed_conflicting_power_packages() {
    local remove_file="$repo_dir/packages/common/remove.txt"
    local package

    while IFS= read -r package; do
        if pacman -Qq "$package" >/dev/null 2>&1; then
            printf '%s\n' "$package"
        fi
    done < <(_profile_packages "$remove_file")
}

_power_stack_model() {
    local config_file="$repo_dir/config.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$config_file" ]; then
        local configured_model
        configured_model=$(jq -r '.model // empty' "$config_file" 2>/dev/null)
        if [ -n "$configured_model" ]; then
            printf '%s\n' "$configured_model"
            return 0
        fi
    fi

    _log WARN "No model found in config.json; defaulting to 'pc'." >&2
    printf '%s\n' "pc"
}

remove_conflicting_power_managers() {
    local conflicts=()
    mapfile -t conflicts < <(_installed_conflicting_power_packages)

    if [ "${#conflicts[@]}" -eq 0 ]; then
        _log INFO "No conflicting power managers are installed."
        return 0
    fi

    _log WARN "Installed power managers that conflict with PPD: ${conflicts[*]}"
    if [ "${POWER_STACK_DRY_RUN:-0}" = "1" ]; then
        return 0
    fi

    if ! ask_yes_no "Disable and remove these conflicting packages?"; then
        _log ERROR "Cannot enable power-profiles-daemon while a competing power manager remains."
        return 1
    fi

    local unit
    for unit in tlp.service auto-cpufreq.service tuned.service tuned-ppd.service system76-power.service laptop-mode.service; do
        sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
    done

    # No --cascade: pacman must refuse removal if another installed package
    # depends on one of these packages.
    sudo pacman -Rns --noconfirm "${conflicts[@]}"
}

install_power_session_stack() {
    local model
    model=$(_power_stack_model)

    remove_conflicting_power_managers || return 1
    _install_official_profile "$repo_dir/packages/common/official.txt" "Common session/power profile" || return 1

    case "$model" in
        laptop)
            _install_official_profile "$repo_dir/packages/laptop/official.txt" "Laptop profile" || return 1
            ;;
        pc|desktop)
            _install_official_profile "$repo_dir/packages/pc/official.txt" "PC profile" || return 1
            ;;
        *)
            _log WARN "Unknown model '$model'; installed only the common profile."
            ;;
    esac

    if [ "${POWER_STACK_DRY_RUN:-0}" != "1" ]; then
        sudo systemctl unmask power-profiles-daemon.service >/dev/null 2>&1 || true
        sudo systemctl enable --now power-profiles-daemon.service
    fi
    _log SUCCESS "The PPD session and power stack is configured for '$model'."
}

install_laptop_power_diagnostics() {
    if [ "$(_power_stack_model)" != "laptop" ]; then
        _log WARN "Power diagnostics are useful on a battery-powered laptop; continuing by request."
    fi
    _install_official_profile "$repo_dir/packages/laptop/optional-diagnostics.txt" "Power diagnostics"
}

_multilib_enabled() {
    command -v pacman-conf >/dev/null 2>&1 && pacman-conf --repo-list 2>/dev/null | grep -qx multilib
}

_nvidia_kernel_driver_installed() {
    pacman -Qq 2>/dev/null | grep -Eq '^(nvidia|nvidia-open)(-dkms)?$|^nvidia-(lts|zen|hardened)$|^linux[^[:space:]]*-nvidia(-open)?$'
}

_install_graphics_profile() {
    local vendor="$1"
    local profile_dir="$repo_dir/packages/gpu/$vendor"

    if [ "$vendor" = "nvidia" ] && ! _nvidia_kernel_driver_installed; then
        _log WARN "NVIDIA GPU detected, but no kernel-driver package is installed; skipping NVIDIA userspace libraries."
        _log WARN "Choose a driver that matches the GPU generation and installed Arch/CachyOS kernel first."
        return 0
    fi

    _install_official_profile "$profile_dir/official.txt" "${vendor^^} graphics profile" || return 1
    if _multilib_enabled; then
        _install_official_profile "$profile_dir/multilib.txt" "${vendor^^} multilib graphics profile" || return 1
    else
        _log INFO "multilib is disabled; skipping 32-bit ${vendor^^} graphics libraries."
    fi
}

install_detected_graphics_stack() {
    local detected=()
    local pci_graphics
    pci_graphics=$(lspci -nn 2>/dev/null | grep -Ei 'VGA|3D|Display' || true)

    grep -Eqi 'AMD|ATI' <<< "$pci_graphics" && detected+=(amd)
    grep -Eqi 'Intel' <<< "$pci_graphics" && detected+=(intel)
    grep -Eqi 'NVIDIA' <<< "$pci_graphics" && detected+=(nvidia)

    if [ "${#detected[@]}" -eq 0 ]; then
        _log ERROR "No supported AMD, Intel, or NVIDIA graphics device was detected."
        return 1
    fi

    local vendor
    for vendor in "${detected[@]}"; do
        _install_graphics_profile "$vendor" || return 1
    done
}
