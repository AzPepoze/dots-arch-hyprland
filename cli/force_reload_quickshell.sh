#!/bin/bash
# Force reload QuickShell using specific kill command
quickshell -c ii kill
sleep 0.5
hyprctl dispatch exec "quickshell -c ii"