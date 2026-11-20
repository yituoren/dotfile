pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var sources: Mpris.players.values
    readonly property var integrations: sources.filter(p => isChromeIntegration(p))
    property var snapshot: ({})
    property bool pending: false
    readonly property string hints: JSON.stringify(integrations.map(p =>
        [p.dbusName, p.metadata["xesam:url"] || "", nativeFor(p)?.trackTitle || "", p.isPlaying, nativeFor(p)?.isPlaying]))
    onHintsChanged: refreshSoon.restart()

    function isChromeIntegration(p): bool {
        return p.dbusName.startsWith("org.mpris.MediaPlayer2.plasma-browser-integration")
            && /chrome|chromium/i.test(p.desktopEntry || p.identity)
    }
    function nativeFor(p): var {
        const pid = Number(p.metadata["kde:pid"])
        return pid ? sources.find(n => n.dbusName === "org.mpris.MediaPlayer2.chromium.instance" + pid) : null
    }
    function refresh(): void {
        if (!reader.running || pending || !integrations.length) return
        const request = {}
        for (const p of integrations) {
            const known = {}
            for (const tab of snapshot[p.dbusName] || []) known[tab.id] = tab.url
            request[p.dbusName] = { known, url: p.metadata["xesam:url"] || "", titles: [nativeFor(p)?.trackTitle].filter(Boolean) }
        }
        pending = true
        reader.write(JSON.stringify(request) + "\n")
    }
    Process {
        id: reader
        running: root.integrations.length > 0
        command: ["/usr/bin/python", Quickshell.shellPath("scripts/media-tabs.py")]
        stdinEnabled: true
        onStarted: root.refresh()
        onExited: { root.pending = false; root.snapshot = ({}) }
        stdout: SplitParser {
            onRead: data => {
                root.pending = false
                const next = JSON.parse(data)
                if (JSON.stringify(next) !== JSON.stringify(root.snapshot)) root.snapshot = next
            }
        }
    }
    Timer { id: refreshSoon; interval: 80; onTriggered: root.refresh() }
    Timer {
        running: reader.running
        interval: PopupManager.currentPopup === "dashboard" ? 1200 : 8000
        repeat: true
        onTriggered: root.refresh()
    }
    Connections {
        target: PopupManager
        function onCurrentPopupChanged() {
            if (PopupManager.currentPopup === "dashboard") root.refresh()
        }
    }
}
