REPO_DIR="$HOME/dots-arch-hyprland"
cd "$REPO_DIR"

if [ -z "$1" ]; then
    cowsay -f ./cowsay/amogus.cow "When imposter is sus."
else
    cowsay -f ./cowsay/amogus.cow "$1"
fi
