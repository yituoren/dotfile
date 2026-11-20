//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// Shell entry point. Each output has a Caelestia-style ContentWindow for the bar and popups.
// The shared prompt handles keyboard help and session confirmations on the active output.

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Blobs  // User-built SDF plugin in ~/.local/share/qt6/qml/Caelestia/Blobs/
import qs.modules.drawers
import qs.modules.bar.widgets
import qs.services

ShellRoot {
    id: shell
    function focusedScreen(): var {
        const ws = Niri.workspaces.find(w => w.id === Niri.activeWorkspaceId)
        return Quickshell.screens.find(s => s.name === ws?.output) ?? Quickshell.screens[0]
    }
    DesktopPrompt { id: prompt }

    // Prefetch weather and warm up the Cloud page before the panel first opens.
    Component.onCompleted: {
        Weather.refresh()
        Chat.ensureHost()
    }

    Variants {
        model: Quickshell.screens
        ContentWindow {
            onLogoutRequested: prompt.show("logout", modelData)
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            const screen = shell.focusedScreen()
            if (screen) PopupManager.toggle("power", screen, screen.width)
        }
    }

    IpcHandler {
        target: "desktop"
        function shortcuts(): void {
            if (prompt.opened && prompt.helpPage) prompt.close()
            else prompt.show("shortcuts", shell.focusedScreen())
        }
        function logout(): void { prompt.show("logout", shell.focusedScreen()) }
    }

    IpcHandler {
        target: "test"
        function ping(): void { console.log("hi from mine") }
    }
}
