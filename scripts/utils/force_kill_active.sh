#!/bin/bash

# Get the PID of the active window
active_window=$(hyprctl activewindow -j 2>/dev/null)

if [[ -z "$active_window" || "$active_window" == "{}" ]]; then
    notify-send -t 2000 "Kill Failed" "No active window found"
    exit 0
fi

pid=$(echo "$active_window" | jq -r '.pid // empty')

# Check if PID is valid and not 0 (usually root or special)
if [[ -n "$pid" && "$pid" != "null" && "$pid" -ne 0 ]]; then
    # Optional: notify-send "Killing $pid"
    kill -9 "$pid"
    notify-send -t 2000 "Process Killed" "Terminated process with PID $pid"
else
    notify-send -t 2000 "Kill Failed" "No active process found to kill"
fi
