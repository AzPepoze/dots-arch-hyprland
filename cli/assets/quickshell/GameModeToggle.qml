import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models.hyprland
import qs.services

QuickToggleModel {
    id: root
    name: Translation.tr("Game mode")
    toggled: !confOpt.value
    icon: "gamepad"

    // Game mode is handled by the Hyprland config's own script rather than
    // HyprlandConfig: this setup uses a Lua config (plain `keyword` is
    // rejected) and deliberately does not source shellOverrides, so writing
    // there does nothing. The script drives Hyprland via `hyprctl eval` and
    // also drops shell transparency/widgets.
    readonly property string gameModeScript: FileUtils.trimFileProtocol(`${Directories.config}/hypr/custom/scripts/game-mode.sh`)

    mainAction: () => {
        if (gameModeProc.running)
            return;
        gameModeProc.running = true;
    }

    Process {
        id: gameModeProc
        command: ["bash", root.gameModeScript]
        onExited: (exitCode, exitStatus) => {
            // Re-read the Hyprland option so the button shows the new mode.
            confOpt.fetch();
        }
    }

    HyprlandConfigOption {
        id: confOpt
        key: "animations:enabled"
    }

    tooltipText: Translation.tr("Game mode")
}
