#!/bin/bash

# This script checks if the configured GPU in ~/.config/hypr/gpu.conf is valid.
# It exits with status 0 if valid, and 1 if invalid.

#-------------------------------------------------------
# Preamble
#-------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$DIR")/.."
HELPER_SCRIPT="$PROJECT_ROOT/scripts/install_modules/helpers.sh"
if [ ! -f "$HELPER_SCRIPT" ]; then
    _log() {
        local level=$1; shift; echo "[$level] $@" >&2;
    }
    _log ERROR "Helper script not found at $HELPER_SCRIPT"
    exit 1
fi
source "$HELPER_SCRIPT"

# Source list_gpu.sh for GPU validation functions
GPU_LIST_SCRIPT="$PROJECT_ROOT/scripts/utils/list_gpu.sh"
if [ ! -f "$GPU_LIST_SCRIPT" ]; then
    _log ERROR "GPU list script not found at $GPU_LIST_SCRIPT"
    exit 1
fi
source "$GPU_LIST_SCRIPT"

#-------------------------------------------------------
# GPU Configuration Check
#-------------------------------------------------------
GPU_LUA_FILE="$HOME/.config/hypr/gpu.lua"

# Exit successfully if the config file doesn't exist or is empty
if [ ! -s "$GPU_LUA_FILE" ]; then
    exit 0
fi

CURRENT_GPU_DEVICE_STRING=$(grep 'hl.env("AQ_DRM_DEVICES"' "$GPU_LUA_FILE" | cut -d'"' -f4)

if [ -z "$CURRENT_GPU_DEVICE_STRING" ]; then
    # Exit successfully if the line is not in the file
    exit 0
fi

PRIMARY_GPU_DEVICE=$(echo "$CURRENT_GPU_DEVICE_STRING" | cut -d: -f1)

if ! check_gpu_device_path "$PRIMARY_GPU_DEVICE"; then
    _log WARN "Configured primary GPU device '$PRIMARY_GPU_DEVICE' is not detected or valid."
    exit 1
fi

exit 0

