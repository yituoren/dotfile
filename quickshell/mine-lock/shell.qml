pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
    id: root
    settings.watchFiles: false

    readonly property string generated: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/user/generated/"
    readonly property var palette: {
        const content = colorsFile.text()
        try { return content ? JSON.parse(content) : ({}) }
        catch (error) { return ({}) }
    }
    readonly property url wallpaper: {
        const path = wallpaperFile.text().trim()
        return path.startsWith("/") ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
    }
    property string pendingResponse: ""
    property bool checking: false
    property bool nextPrompt: false
    property string feedback: ""
    signal clearInputs()

    function submit(value: string): void {
        if (!lock.secure || checking || !value.length) return
        feedback = ""
        checking = true
        clearInputs()
        if (nextPrompt) {
            nextPrompt = false
            pam.respond(value)
        } else {
            pendingResponse = value
            if (!pam.start()) failed("Authentication unavailable")
        }
    }

    function failed(message: string): void {
        pendingResponse = ""
        nextPrompt = false
        checking = false
        feedback = message
        clearInputs()
    }

    // Read the two small descriptors before painting the first lock surface.
    FileView {
        id: colorsFile
        path: root.generated + "colors.json"
        preload: false
        blockLoading: true
    }
    FileView {
        id: wallpaperFile
        path: root.generated + "wallpaper/path.txt"
        preload: false
        blockLoading: true
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    PamContext {
        id: pam
        configDirectory: "/etc/pam.d"
        config: "login"

        onPamMessage: {
            if (!responseRequired) return
            if (root.pendingResponse.length && !responseVisible) {
                const value = root.pendingResponse
                root.pendingResponse = ""
                respond(value)
            } else {
                root.pendingResponse = ""
                root.nextPrompt = true
                root.checking = false
                root.feedback = message
            }
        }
        onError: root.failed("Authentication unavailable")
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.pendingResponse = ""
                root.clearInputs()
                lock.locked = false
                Qt.callLater(Qt.quit)
            } else {
                root.failed(result === PamResult.Failed ? "Incorrect password. Try again." : "Authentication unavailable")
            }
        }
    }

    Process {
        id: notify
        command: ["/usr/bin/systemd-notify", "--ready"]
    }
    WlSessionLock {
        id: lock
        locked: true
        onSecureStateChanged: if (secure && Quickshell.env("NOTIFY_SOCKET")) notify.running = true
        WlSessionLockSurface {
            color: "#101519"
            LockFace {
                id: view
                anchors.fill: parent
                wallpaper: root.wallpaper
                palette: root.palette
                now: clock.date
                checking: root.checking
                feedback: root.feedback
                onEdited: if (!root.nextPrompt) root.feedback = ""
                onSubmitted: value => root.submit(value)
                Connections {
                    target: root
                    function onClearInputs() { view.clearInput() }
                }
            }
        }
    }
}
