//@ pragma UseQApplication
//@ pragma Env QS_DISABLE_FILE_WATCHER=1
//@ pragma AppId mine-chat
//@ pragma Env QS_NO_RELOAD_POPUP=1
pragma ComponentBehavior: Bound

import QtQuick
import QtWebEngine
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property var viewport: null
    property bool viewportVisible: false
    property WebEngineProfile persistentProfile: null
    Component.onCompleted: {
        const profile = chatProfile.instance()
        if (profile && !profile.offTheRecord) persistentProfile = profile
        else console.error("Chat: persistent browser profile unavailable")
    }
    Socket {
        id: bridge
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mine-chat-view.sock"
        connected: true
        onConnectedChanged: if (!connected) root.viewportVisible = false
        parser: SplitParser {
            onRead: line => {
                const msg = JSON.parse(line)
                if ("viewport" in msg) {
                    // Preserve the document layout while the surface is hidden.
                    if (msg.viewport) root.viewport = msg.viewport
                    root.viewportVisible = msg.viewport !== null
                }
                if (msg.action === "back") {
                    if (secondary.active) secondary.active = false
                    else if (mainView.item?.canGoBack) mainView.item.goBack()
                } else if (msg.action === "reload") (secondary.item ?? mainView.item)?.reload()
            }
        }
    }
    Timer {
        interval: 500; running: !bridge.connected; repeat: true
        onTriggered: bridge.connected = true
    }
    WebEngineProfilePrototype {
        id: chatProfile
        storageName: "mine-chat"
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
    }

    readonly property webEngineScript conversationScroll: ({
        name: "conversation-scroll",
        sourceUrl: Qt.resolvedUrl("conversation-scroll.js"),
        injectionPoint: WebEngineScript.DocumentCreation,
        worldId: WebEngineScript.ApplicationWorld
    })

    FileView {
        id: css
        path: Quickshell.shellPath("chat.css")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: mainView.item?.applyStyle()
    }

    PanelWindow {
        id: panel
        screen: Quickshell.screens.find(s => s.name === root.viewport?.output) ?? Quickshell.screens[0]
        visible: bridge.connected && root.viewportVisible
        anchors { top: true; left: true }
        margins { top: root.viewport?.y ?? 0; left: root.viewport?.x ?? 0 }
        implicitWidth: Math.max(1, Math.round((root.viewport?.width ?? 1) * page.scale))
        implicitHeight: Math.max(1, Math.round((root.viewport?.height ?? 1) * page.scale))
        color: "transparent"
        WlrLayershell.namespace: "mine-chat"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            id: page
            width: root.viewport?.width ?? 560
            height: root.viewport?.height ?? 720
            scale: root.viewport?.zoom ?? 1
            transformOrigin: Item.TopLeft
            Loader {
                id: mainView
                anchors.fill: parent
                active: root.persistentProfile !== null
                sourceComponent: WebEngineView {
                    profile: root.persistentProfile
                    settings.scrollAnimatorEnabled: true
                    userScripts.collection: [root.conversationScroll]
                    url: "https://chatgpt.com/"
                    focus: true
                    function applyStyle(): void {
                        if (!css.loaded || !url.toString().startsWith("https://chatgpt.com/")) return
                        const source = JSON.stringify(css.text())
                        runJavaScript(`(() => {
                            if (location.origin !== "https://chatgpt.com") return;
                            const sheet = globalThis.mineChatStyle ??= new CSSStyleSheet();
                            sheet.replaceSync(${source});
                            if (!document.adoptedStyleSheets.includes(sheet))
                                document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
                        })()`, WebEngineScript.ApplicationWorld)
                    }
                    onLoadingChanged: info => {
                        if (info.status === WebEngineView.LoadSucceededStatus) applyStyle()
                    }
                    onNewWindowRequested: request => {
                        if (!request.userInitiated) return
                        secondary.active = true
                        request.openIn(secondary.item)
                        secondary.item.forceActiveFocus()
                    }
                }
            }
            Loader {
                id: secondary
                anchors.fill: parent
                active: false
                sourceComponent: WebEngineView {
                    profile: root.persistentProfile
                    onWindowCloseRequested: secondary.active = false
                }
            }
        }
    }
}
