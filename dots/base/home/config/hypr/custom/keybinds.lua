require("hyprland.lib")

-- Configurable workspace/window modifier
local mod = "ALT"
local archSetupScripts = "$HOME/dots-arch-hyprland/scripts"

-------------------------------------------------------
-- App Launcher
-------------------------------------------------------
hl.bind("SUPER + A", hl.dsp.exec_cmd("pgrep -x rofi && killall rofi || rofi -show drun"), { description = "App: Rofi Launcher" })
hl.bind("SUPER + Semicolon", hl.dsp.global("quickshell:overviewEmojiToggle"), { description = "Utilities: Emoji Picker" })
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd("pavucontrol-qt || pavucontrol"), { description = "App: Volume Mixer" })

-------------------------------------------------------
-- Custom Scripts
-------------------------------------------------------
hl.bind("CTRL + ALT + F", hl.dsp.exec_cmd("bash " .. archSetupScripts .. "/keybinds/zoom_to_fit.sh"), { description = "Custom: Zoom to fit" })
hl.bind("ALT + Q", hl.dsp.exec_cmd("bash " .. archSetupScripts .. "/keybinds/mixer.sh"), { description = "Custom: Mixer" })
hl.bind("CTRL + ALT + Slash", hl.dsp.exec_cmd(archSetupScripts .. "/hypr/keybinds/toggle_workspace_mod.sh"), { description = "Custom: Toggle Workspace Mod" })
hl.bind("CTRL + ALT + Period", hl.dsp.exec_cmd(archSetupScripts .. "/hypr/keybinds/toggle_hover_to_focus.sh"), { description = "Custom: Toggle Hover to Focus" })

-------------------------------------------------------
-- Utilities & Screenshots
-------------------------------------------------------
hl.bind("SUPER + Q", hl.dsp.exec_cmd(archSetupScripts .. "/utils/qr_code_scanner.sh"), { description = "Utilities: QR Code Scanner" })
hl.bind("Print", hl.dsp.global("quickshell:regionScreenshot"), { description = "Utilities: Screen snip" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("mkdir -p $(xdg-user-dir PICTURES)/Screenshots && FILE=$(xdg-user-dir PICTURES)/Screenshots/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png && grim \"$FILE\" && wl-copy < \"$FILE\" && notify-send \"Screenshot Saved\" \"Image saved to $FILE\""), { description = "Utilities: Capture screen" })

-------------------------------------------------------
-- System / Keyboard
-------------------------------------------------------
hl.bind("ALT + Shift_L", hl.dsp.exec_cmd("hyprctl switchxkblayout main next"), { locked = true, description = "System: Switch Keyboard Layout" })
hl.bind("SHIFT + Alt_L", hl.dsp.exec_cmd("hyprctl switchxkblayout main next"), { locked = true })
hl.bind("SHIFT + CTRL + D", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { description = "System: Toggle Mic Mute" })

-------------------------------------------------------
-- Close / Kill Window
-------------------------------------------------------
hl.bind(mod .. " + C", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind(mod .. " + F4", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(archSetupScripts .. "/dontkillsteam.sh"), { description = "Window: Close (Steam safe)" })
hl.bind("SUPER + F4", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Force kill" })

-------------------------------------------------------
-- Focus Window
-------------------------------------------------------
hl.bind(mod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + Down", hl.dsp.focus({ direction = "d" }))

-------------------------------------------------------
-- Move Window
-------------------------------------------------------
hl.bind(mod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))

-------------------------------------------------------
-- Window State
-------------------------------------------------------
hl.bind(mod .. " + W", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Toggle Maximized" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Toggle Fullscreen" })
hl.bind(mod .. " + SHIFT + Z", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.pin())
end, { description = "Window: Toggle Float + Pin" })
hl.bind(mod .. " + SHIFT + CTRL + Z", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Toggle Float" })

-------------------------------------------------------
-- Cycle Windows & Groups
-------------------------------------------------------
hl.bind("ALT + Tab", hl.dsp.exec_cmd("hyprctl dispatch cyclenext && hyprctl dispatch bringactivetotop"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("hyprctl dispatch togglegroup"), { description = "Window: Toggle Group" })
hl.bind("ALT + Tab", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"))

-------------------------------------------------------
-- Switch Workspaces & Move Windows
-------------------------------------------------------
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mod .. " + " .. key, function()
        hl.dispatch(hl.dsp.focus({ workspace = tostring(i) }))
    end, { description = "Workspace: Focus " .. i })

    -- Move to workspace (follow)
    hl.bind(mod .. " + SHIFT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(i) }))
    end, { description = "Window: Send to workspace " .. i })

    -- Move to workspace (silent)
    hl.bind(mod .. " + CTRL + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(i), follow = false }))
    end)
end

-------------------------------------------------------
-- Special Workspace (Scratchpad)
-------------------------------------------------------
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Toggle Scratchpad" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:special" }), { description = "Window: Send to Scratchpad" })
hl.bind("CTRL + SHIFT + S", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to Scratchpad (Silent)" })

-------------------------------------------------------
-- Mouse & Hold Binds
-------------------------------------------------------
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + Z", hl.dsp.window.drag(), { mouse = true, description = "Window: Hold to Move" })
hl.bind(mod .. " + X", hl.dsp.window.resize(), { mouse = true, description = "Window: Hold to Resize" })
