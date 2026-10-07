#!/usr/bin/env python3
"""Pin selected illogical-impulse config keys so the shell can't change them.

The shell rewrites config.json wholesale (wallpaper switches, preset
applies, ...). This script snapshots whitelisted keys and restores them.

Usage:
  pin-ii-config.py save      # snapshot current pinned values
  pin-ii-config.py restore   # write pinned values back into config.json
  pin-ii-config.py diff      # show what the shell changed in pinned keys

Edit PIN_KEYS below to choose what persists.
"""
import json
import sys
from pathlib import Path

CONFIG = Path.home() / ".config/illogical-impulse/config.json"
PINFILE = Path.home() / ".config/illogical-impulse/pinned.json"

# Only these persist. Everything else the shell may change freely.
PIN_KEYS = [
    "background.wallpaperPath",
    "background.thumbnailPath",
]


def get_path(data, key):
    node = data
    for part in key.split("."):
        if not isinstance(node, dict) or part not in node:
            return None, False
        node = node[part]
    return node, True


def set_path(data, key, value):
    node = data
    parts = key.split(".")
    for part in parts[:-1]:
        if not isinstance(node.get(part), dict):
            node[part] = {}
        node = node[part]
    node[parts[-1]] = value


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "diff"
    config = json.loads(CONFIG.read_text())
    pinned = json.loads(PINFILE.read_text()) if PINFILE.exists() else {}

    if action == "save":
        for key in PIN_KEYS:
            value, found = get_path(config, key)
            if found:
                pinned[key] = value
        PINFILE.write_text(json.dumps(pinned, indent=2) + "\n")
        print(f"saved {len(pinned)} keys to {PINFILE}")
    elif action == "restore":
        for key, value in pinned.items():
            set_path(config, key, value)
        CONFIG.write_text(json.dumps(config, indent=2) + "\n")
        print(f"restored {len(pinned)} keys")
    elif action == "diff":
        changed = False
        for key in PIN_KEYS:
            current, _ = get_path(config, key)
            if key in pinned and pinned[key] != current:
                print(f"{key}:\n  pinned:  {pinned[key]!r}\n  current: {current!r}")
                changed = True
        if not changed:
            print("pinned keys untouched")
    else:
        sys.exit(f"unknown action: {action}")


if __name__ == "__main__":
    main()
