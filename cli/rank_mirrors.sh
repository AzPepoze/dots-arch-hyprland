#!/bin/bash

if ! command -v rate-mirrors &> /dev/null; then
    echo "Error: rate-mirrors is not installed."
    echo "Please install it using: sudo pacman -S rate-mirrors"
    exit 1
fi

echo
echo "Ranking Arch Linux mirrors..."
TMPFILE="$(mktemp)"
sudo true
rate-mirrors --save="$TMPFILE" arch  \
  && sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup \
  && sudo mv "$TMPFILE" /etc/pacman.d/mirrorlist
echo "Arch Linux mirrors ranked."
echo
echo "Ranking Chaotic-AUR mirrors..."
TMPFILE="$(mktemp)"
rate-mirrors --save="$TMPFILE" chaotic-aur  \
  && sudo mv /etc/pacman.d/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist-backup \
  && sudo mv "$TMPFILE" /etc/pacman.d/chaotic-mirrorlist
echo "Chaotic-AUR mirrors ranked."
echo
if grep -q "ID=cachyos" /etc/os-release; then
  echo "Ranking CachyOS mirrors..."
  TMPFILE="$(mktemp)"
  rate-mirrors --save="$TMPFILE" cachyos  \
    && sudo mv /etc/pacman.d/cachyos-mirrorlist /etc/pacman.d/cachyos-mirrorlist-backup \
    && sudo mv "$TMPFILE" /etc/pacman.d/cachyos-mirrorlist
  echo "CachyOS mirrors ranked."
fi

echo "All mirror lists updated."

