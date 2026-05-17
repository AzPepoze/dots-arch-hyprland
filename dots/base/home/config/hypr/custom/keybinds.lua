require("hyprland.lib")

-- App Launcher
hl.bind("SUPER + A", hl.dsp.exec_cmd("pgrep -x rofi && killall rofi || rofi -show drun"), { description = "App: Rofi Launcher" })

-- Custom Scripts
local archSetupScripts = "$HOME/dots-arch-hyprland/scripts"
hl.bind("CTRL + ALT + F", hl.dsp.exec_cmd("bash " .. archSetupScripts .. "/keybinds/zoom_to_fit.sh"), { description = "Custom: Zoom to fit" })
hl.bind("ALT + Q", hl.dsp.exec_cmd("bash " .. archSetupScripts .. "/keybinds/mixer.sh"), { description = "Custom: Mixer" })
hl.bind("CTRL + ALT + Slash", hl.dsp.exec_cmd(archSetupScripts .. "/hypr/keybinds/toggle_workspace_mod.sh"), { description = "Custom: Toggle Workspace Mod" })
hl.bind("CTRL + ALT + Period", hl.dsp.exec_cmd(archSetupScripts .. "/hypr/keybinds/toggle_hover_to_focus.sh"), { description = "Custom: Toggle Hover to Focus" })

-- Utilities & Screenshots
hl.bind("SUPER + Q", hl.dsp.exec_cmd(archSetupScripts .. "/utils/qr_code_scanner.sh"), { description = "Utilities: QR Code Scanner" })
hl.bind("Print", hl.dsp.global("quickshell:regionScreenshot"), { description = "Utilities: Screen snip" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("mkdir -p $(xdg-user-dir PICTURES)/Screenshots && FILE=$(xdg-user-dir PICTURES)/Screenshots/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png && grim \"$FILE\" && wl-copy < \"$FILE\" && notify-send \"Screenshot Saved\" \"Image saved to $FILE\""), { description = "Utilities: Capture screen" })

-- System / Keyboard
hl.bind("ALT + Shift_L", hl.dsp.exec_cmd("hyprctl switchxkblayout main next"), { description = "System: Switch Keyboard Layout" })
hl.bind("SHIFT + Alt_L", hl.dsp.exec_cmd("hyprctl switchxkblayout main next"))

-- Workspace & Window Management
local mod = "ALT"

hl.bind(mod .. " + C", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind(mod .. " + F4", hl.dsp.window.close(), { description = "Window: Close" })

-- Focus window
hl.bind(mod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + Down", hl.dsp.focus({ direction = "d" }))

-- Move window
hl.bind(mod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))

-- Switch workspaces
for i = 1, 10 do
    hl.bind(mod .. " + " .. (i % 10), function()
        hl.dispatch(hl.dsp.focus({ workspace = tostring(i) }))
    end, { description = "Workspace: Focus " .. i })
    
    -- Move to workspace
    hl.bind(mod .. " + SHIFT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(i) }))
    end, { description = "Window: Send to workspace " .. i })
end

-- Mouse binds
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
