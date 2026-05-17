#!/bin/bash
# Force reload QuickShell using specific kill command
quickshell -c ii kill
sleep 0.5
quickshell -c ii > /dev/null 2>&1 &