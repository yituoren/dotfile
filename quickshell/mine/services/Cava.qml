pragma Singleton
pragma ComponentBehavior: Bound

// Run cava and parse its raw ASCII output into normalized [0, 1] bar values.
// Share one spectrum between the bar and the dashboard media tab.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool showBarSpectrum: PopupManager.currentPopup !== "dashboard"
    property var values: []
    readonly property int bars: values.length

    Process {
        id: cavaProc
        running: root.showBarSpectrum || PopupManager.dashboardTab === "media"
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";").filter(s => s.length > 0)
                if (!parts.length) return
                const v = []
                for (let i = 0; i < parts.length; i++) {
                    const n = parseInt(parts[i], 10)
                    v.push(isNaN(n) ? 0 : Math.max(0, Math.min(1, n / 100)))
                }
                root.values = v
            }
        }
    }
}
