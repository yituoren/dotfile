pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.services
import qs.modules.bar.widgets

PanelWindow {
    id: dialog
    property bool opened: false
    property string page: "shortcuts"
    readonly property bool helpPage: page === "shortcuts"
    property string failure: ""
    function show(which: string, output: var): void {
        if (!output || runner.running || (which !== "shortcuts" && which !== "logout")) return
        PopupManager.close()
        screen = output
        page = which
        failure = ""
        opened = true
        Qt.callLater(function() { if (body.item) body.item.takeFocus() })
    }
    function close(): void { opened = false }
    function confirm(): void {
        if (!opened || page !== "logout" || runner.running) return
        runner.running = true
    }
    Process {
        id: runner
        command: ["niri", "msg", "action", "quit", "--skip-confirmation"]
        onExited: (code, status) => {
            if (code === 0) dialog.close()
            else dialog.failure = "Could not complete the action. Check your session and try again."
        }
    }

    property real amount: opened ? 1 : 0
    Behavior on amount { NumberAnimation { duration: 165; easing.type: Easing.OutCubic } }
    visible: opened || amount > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mine-prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, (dialog.helpPage ? 0.16 : 0.26) * dialog.amount)
        MouseArea { anchors.fill: parent; onClicked: dialog.close() }
    }
    Rectangle {
        id: card
        readonly property real ui: Math.min(Theme.uiScale, (dialog.width - 24) / (dialog.helpPage ? 660 : 350),
                                           (dialog.height - 84) / (dialog.helpPage ? 380 : 220))
        width: dialog.helpPage ? 660 : 350
        height: dialog.helpPage ? 380 : (dialog.failure ? 220 : 190)
        scale: ui * (0.97 + 0.03 * dialog.amount)
        transformOrigin: dialog.helpPage ? Item.Center : Item.TopRight
        x: dialog.helpPage ? (dialog.width - width) / 2 : dialog.width - width - 8
        y: (dialog.helpPage ? (dialog.height - height) / 2 : 8 + 44 * Theme.uiScale + 8) - 8 * (1 - dialog.amount)
        opacity: dialog.amount; radius: 20
        color: dialog.helpPage ? "#000000" : Theme.colors.surface_container_lowest
        border.width: dialog.helpPage ? 0 : 1; border.color: Theme.colors.outline_variant
        enabled: dialog.opened
        MouseArea { anchors.fill: parent }
        Loader {
            id: body
            anchors.fill: parent; anchors.margins: 20
            active: dialog.visible
            sourceComponent: dialog.helpPage ? shortcuts : confirmation
            onLoaded: item.takeFocus()
            Keys.onEscapePressed: dialog.close()
        }
    }
    Component {
        id: shortcuts
        ShortcutSheet {
            function takeFocus(): void { focusSearch() }
        }
    }
    Component {
        id: confirmation
        FocusScope {
            function takeFocus(): void { cancel.forceActiveFocus(Qt.TabFocusReason) }
            ColumnLayout {
                anchors.fill: parent; spacing: 8
                RowLayout {
                    spacing: 12
                    Rectangle {
                        implicitWidth: 42; implicitHeight: 42; radius: 14; color: Theme.colors.tertiary_container
                        Text {
                            anchors.centerIn: parent; text: "logout"
                            font.family: "Material Symbols Rounded"; font.pixelSize: 24; color: Theme.colors.on_tertiary_container
                        }
                    }
                    Text {
                        text: "Log out?"
                        font.family: "Maple Mono NF CN"; font.styleName: "Bold"; font.pixelSize: 21; color: Theme.colors.on_surface
                    }
                }
                Text {
                    Layout.fillWidth: true; Layout.fillHeight: true; verticalAlignment: Text.AlignVCenter
                    text: dialog.failure || "End this niri session and return to the login screen?"; wrapMode: Text.WordWrap
                    font.family: "Maple Mono NF CN"; font.pixelSize: 14
                    color: dialog.failure ? Theme.colors.error : Theme.colors.on_surface_variant
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight; spacing: 8
                    PanelAction {
                        id: cancel
                        text: "Cancel"; onClicked: dialog.close()
                        Keys.onReturnPressed: dialog.close()
                        Keys.onEnterPressed: dialog.close()
                    }
                    PanelAction {
                        id: accept
                        text: "Log out"; symbol: "logout"
                        enabled: !runner.running; onClicked: dialog.confirm()
                        Keys.onReturnPressed: dialog.confirm()
                        Keys.onEnterPressed: dialog.confirm()
                    }
                }
            }
        }
    }
}
