import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1280
    height: 800
    color: surface
    readonly property string mono: "Maple Mono NF CN"
    readonly property string symbols: "Material Symbols Rounded"
    readonly property color surface: config.stringValue("surface") || "#101519"
    readonly property color panel: config.stringValue("surface_container") || "#1b2023"
    readonly property color field: config.stringValue("surface_container_high") || "#282e32"
    readonly property color ink: config.stringValue("on_surface") || "#dfe3e7"
    readonly property color muted: config.stringValue("on_surface_variant") || "#c0c8cd"
    readonly property color accent: config.stringValue("primary") || "#8ccff0"
    readonly property color accentInk: config.stringValue("on_primary") || "#003547"
    readonly property color outline: config.stringValue("outline_variant") || "#40484c"
    readonly property color errorInk: config.stringValue("error") || "#ffb4ab"
    readonly property string imageFile: config.stringValue("wallpaper")
    property date now: new Date()
    property bool busy: false
    property string errorText: ""

    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }
    Image {
        anchors.fill: parent
        source: /^(a|b)[.]jpg$/.test(root.imageFile) ? config.stringValue("assets") + root.imageFile : ""
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: "#30000000" }

    function login() {
        const name = account.editText.trim()
        if (!name || busy || session.currentIndex < 0) return
        errorText = ""
        busy = true
        sddm.login(name, password.text, session.currentIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.errorText = "Sign-in failed. Try again."
            password.clear()
            password.forceActiveFocus()
        }
    }

    component Action: AbstractButton {
        id: button
        property string symbol: ""
        property bool primary: false
        property bool compact: false
        hoverEnabled: true
        implicitWidth: Math.max(40, contentItem.implicitWidth + 26)
        implicitHeight: 40
        Accessible.name: text
        background: Rectangle {
            radius: 13
            color: button.primary ? root.accent : button.down || button.hovered ? root.field : root.panel
            border.width: button.visualFocus ? 2 : 0
            border.color: button.primary ? root.ink : root.accent
            opacity: button.primary && button.down ? 0.8 : 1
            Behavior on color { ColorAnimation { duration: 130 } }
        }
        contentItem: Item {
            implicitWidth: caption.implicitWidth
            implicitHeight: caption.implicitHeight
            Row {
                id: caption
                anchors.centerIn: parent
                spacing: button.symbol && button.text && !button.compact ? 8 : 0
                layoutDirection: button.primary ? Qt.RightToLeft : Qt.LeftToRight
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!button.symbol
                    text: button.symbol; font.family: root.symbols; font.pixelSize: 18
                    color: button.primary ? root.accentInk : root.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!button.text && !button.compact
                    text: button.text; font.family: root.mono; font.styleName: "Bold"; font.pixelSize: 13
                    color: button.primary ? root.accentInk : root.ink
                }
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    component Picker: ComboBox {
        id: box
        property string symbol
        implicitHeight: 45
        implicitWidth: 158
        leftPadding: 39; rightPadding: 30
        flat: true
        font.family: root.mono; font.pixelSize: 14
        palette.text: root.ink; palette.buttonText: root.ink; palette.highlight: root.accent
        background: Rectangle {
            radius: 13; color: root.field
            border.width: box.activeFocus ? 1 : 0; border.color: root.accent
            Text {
                anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter
                font.family: root.symbols; font.pixelSize: 18; color: root.accent; text: box.symbol
            }
        }
        indicator: Text {
            visible: box.count > 1
            x: box.width - width - 10; y: (box.height - height) / 2
            font.family: root.symbols; font.pixelSize: 17; color: root.muted; text: "expand_more"
        }
        delegate: ItemDelegate {
            required property int index
            width: box.popup.width - 8
            highlighted: box.highlightedIndex === index
            contentItem: Text {
                text: box.textAt(index); font: box.font; color: root.ink; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight; textFormat: Text.PlainText
            }
            background: Rectangle { radius: 9; color: parent.highlighted ? root.field : "transparent" }
        }
        popup: Popup {
            y: box.height + 5; width: box.width; padding: 4
            implicitHeight: Math.min(190, contentItem.implicitHeight + 8)
            contentItem: ListView {
                clip: true; implicitHeight: contentHeight; currentIndex: box.highlightedIndex
                model: box.popup.visible ? box.delegateModel : null
            }
            background: Rectangle { radius: 14; color: root.panel; border.color: root.outline }
        }
    }

    Rectangle {
        id: bar
        x: 12; y: 10; width: parent.width - 24; height: 48; radius: 18; color: "#ed080a0c"
        Text {
            anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
            text: ""; font.family: root.mono; font.styleName: "ExtraBold"; font.pixelSize: 25; color: root.accent
        }
        Text {
            anchors.centerIn: parent; font.family: root.mono; font.styleName: "Bold"; font.pixelSize: 14; color: root.ink
            text: root.now.toLocaleString(Qt.locale("en_US"), "ddd, MMM d   HH:mm")
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; spacing: 5
            Picker {
                implicitWidth: 96; implicitHeight: 38; symbol: "keyboard"
                model: keyboard.layouts.map(layout => layout.shortName)
                visible: count > 1; currentIndex: keyboard.currentLayout; Accessible.name: "Keyboard layout"
                onActivated: index => { keyboard.currentLayout = index; password.forceActiveFocus() }
            }
            Action {
                text: "Sleep"; symbol: "bedtime"; compact: root.width < 1150; visible: sddm.canSuspend
                onClicked: sddm.suspend()
            }
            Action {
                text: "Restart"; compact: root.width < 1150; symbol: "restart_alt"; visible: sddm.canReboot
                onClicked: sddm.reboot()
            }
            Action {
                text: "Power off"; compact: root.width < 1150; symbol: "power_settings_new"; visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        scale: Math.max(1, Math.min(1.22, root.width / 1540, root.height / 900))
        width: Math.min(370, root.width - 32); height: form.implicitHeight + 44
        radius: 23; color: Qt.rgba(root.panel.r, root.panel.g, root.panel.b, 0.96)
        border.color: root.outline
        ColumnLayout {
            id: form
            x: 22; y: 22; width: parent.width - 44; spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Sign in"; font.family: root.mono; font.styleName: "Bold"; font.pixelSize: 25; color: root.ink
                    Layout.fillWidth: true
                }
                Picker {
                    id: session; symbol: "desktop_windows"; implicitWidth: 139; implicitHeight: 36
                    model: sessionModel; textRole: "name"; Accessible.name: "Desktop session"
                    Component.onCompleted: {
                        const niri = find("Niri")
                        currentIndex = niri >= 0 ? niri : Math.max(0, sessionModel.lastIndex)
                    }
                }
            }
            Picker {
                id: account; Layout.fillWidth: true; Layout.topMargin: 5
                symbol: "person"; editable: true; model: userModel; textRole: "name"; Accessible.name: "Username"
                Component.onCompleted: {
                    currentIndex = userModel.lastIndex >= 0 ? userModel.lastIndex : (count ? 0 : -1)
                    if (currentIndex < 0) editText = userModel.lastUser || ""
                }
                onAccepted: password.forceActiveFocus()
            }
            PasswordField {
                id: password; Layout.fillWidth: true; implicitHeight: 47; focus: true
                leftPadding: 40; rightPadding: 14
                textSize: 15
                accent: root.accent; color: root.ink; placeholderTextColor: root.muted; placeholderText: "Password"
                selectByMouse: true; readOnly: root.busy
                onAccepted: root.login()
                background: Rectangle {
                    radius: 13; color: root.field; border.width: password.activeFocus ? 2 : 1
                    border.color: password.activeFocus ? root.accent : root.outline
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter
                        text: "lock"; font.family: root.symbols; font.pixelSize: 18; color: root.muted
                    }
                }
            }
            Text {
                Layout.fillWidth: true; visible: !!root.errorText; text: root.errorText
                font.family: root.mono; font.pixelSize: 12; color: root.errorInk; wrapMode: Text.Wrap
            }
            Action {
                Layout.fillWidth: true; implicitHeight: 43; Layout.topMargin: 2
                primary: true; symbol: "arrow_forward"; text: root.busy ? "Signing in…" : "Sign in"
                enabled: !root.busy; onClicked: root.login()
            }
        }
    }
    Component.onCompleted: if (account.editText) password.forceActiveFocus(); else account.forceActiveFocus()
}
