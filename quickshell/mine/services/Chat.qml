pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string outputName: ""
    property bool opened: false
    property real anchorX: 0
    function toggle(screen: var, x: real): void {
        if (opened && outputName === screen.name) {
            opened = false
        } else {
            viewport = null
            anchorX = x
            outputName = screen.name
            opened = true
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.outputName && !Quickshell.screens.some(s => s.name === root.outputName)) {
                root.opened = false
                root.viewport = null
                root.outputName = ""
            }
        }
    }
    property bool local: false
    property var viewport: null
    property Socket client: null
    function send(message: var): void {
        if (client?.connected) {
            client.write(JSON.stringify(message) + "\n")
            client.flush()
        }
    }
    onViewportChanged: send({ viewport })
    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mine-chat-view.sock"
        handler: Socket {
            id: peer
            onConnectedChanged: {
                if (connected) {
                    root.client = peer
                    root.send({ viewport: root.viewport })
                }
            }
        }
    }
    function ensureHost(): void {
        if (!client?.connected) launch.running = true
    }
    Process {
        id: launch
        command: [Quickshell.env("HOME") + "/.local/lib/mine-chat/quickshell",
                  "-n", "-d", "-p", Quickshell.shellPath("chat")]
    }
}
