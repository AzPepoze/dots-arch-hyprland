#!/bin/bash

# Check if Go is installed, install if not
if ! command -v go &> /dev/null; then
    echo "Go not found. Installing..."
    sudo pacman -S --noconfirm go
fi

git pull
(cd tui && go build -o tui-app)
./tui/tui-app "$@"
