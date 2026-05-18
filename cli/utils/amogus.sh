#!/bin/bash
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname "$(dirname "$CURRENT_SCRIPT_DIR")")"
cd "$REPO_DIR"

if [ -z "$1" ]; then
    cowsay -f ./cowsay/amogus.cow "When imposter is sus."
else
    cowsay -f ./cowsay/amogus.cow "$1"
fi
