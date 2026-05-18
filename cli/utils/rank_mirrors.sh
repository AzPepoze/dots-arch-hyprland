#!/bin/bash
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"

# Source helper functions
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
    source "$HELPER_SCRIPT"
else
    _log() {
        local type="$1"; shift
        local msg="$*"
        echo "[$type] $msg"
    }
fi

if ! command -v rate-mirrors &> /dev/null; then
    _log ERROR "rate-mirrors is not installed. Please install it first (sudo pacman -S rate-mirrors)."
    exit 1
fi

_header "Ranking Package Mirrors"

_log INFO "Authenticating for root privileges..."
sudo -v

_log INFO "Ranking Arch Linux mirrors..."
TMPFILE="$(mktemp)"
if rate-mirrors --save="$TMPFILE" arch && \
   sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup && \
   sudo mv "$TMPFILE" /etc/pacman.d/mirrorlist; then
    _log SUCCESS "Arch Linux mirrors ranked."
else
    _log ERROR "Failed to rank Arch Linux mirrors."
fi

_log INFO "Ranking Chaotic-AUR mirrors..."
TMPFILE="$(mktemp)"
if rate-mirrors --save="$TMPFILE" chaotic-aur && \
   sudo mv /etc/pacman.d/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist-backup && \
   sudo mv "$TMPFILE" /etc/pacman.d/chaotic-mirrorlist; then
    _log SUCCESS "Chaotic-AUR mirrors ranked."
else
    _log ERROR "Failed to rank Chaotic-AUR mirrors."
fi

if grep -q "ID=cachyos" /etc/os-release; then
  _log INFO "Ranking CachyOS mirrors..."
  TMPFILE="$(mktemp)"
  if rate-mirrors --save="$TMPFILE" cachyos && \
     sudo mv /etc/pacman.d/cachyos-mirrorlist /etc/pacman.d/cachyos-mirrorlist-backup && \
     sudo mv "$TMPFILE" /etc/pacman.d/cachyos-mirrorlist; then
      _log SUCCESS "CachyOS mirrors ranked."
  else
      _log ERROR "Failed to rank CachyOS mirrors."
  fi
fi

_log SUCCESS "All mirror lists updated successfully."
