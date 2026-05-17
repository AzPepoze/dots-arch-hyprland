-- Custom Window Rules

-- Re-enable blur for specific windows (base config disables blur for all windows)
hl.window_rule({match = {class = "^(kitty)$"}, opacity = "0.80 0.80 1.0", no_blur = false})
hl.window_rule({match = {class = "^(org.kde.dolphin)$"}, opacity = "0.80 0.80 1.0", no_blur = false})
