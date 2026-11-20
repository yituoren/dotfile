import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root
    width: 1280
    height: 800
    readonly property string mono: "Maple Mono NF CN"
    readonly property string symbols: "Material Symbols Rounded"
    readonly property color surface: config.stringValue("surface") || "#101519"
    readonly property color panel: config.stringValue("surface_container") || "#1b2023"
    readonly property color field: config.stringValue("surface_container_high") || "#282e32"
    readonly property color ink: config.stringValue("on_surface") || "#dfe3e7"
    readonly property color muted: config.stringValue("on_surface_variant") || "#c0c8cd"
    readonly property color accent: config.stringValue("primary") || "#8ccff0"
    readonly property color accentInk: config.stringValue("on_primary") || "#003547"
    readonly property color errorInk: config.stringValue("error") || "#ffb4ab"
    readonly property string imageFile: config.stringValue("wallpaper")
    readonly property real uiScale: Math.min(1.22, Math.max(0.78, height / 1000))
    readonly property string defaultUser: {
        if (userModel.lastUser || !account.count) return userModel.lastUser
        const index = userModel.lastIndex
        return account.textAt(index >= 0 && index < account.count ? index : 0)
    }
    property bool switching: false
    readonly property bool manual: switching || !defaultUser
    property real accountReveal: manual ? 1 : 0
    Behavior on accountReveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property string loginName: manual ? account.editText.trim() : defaultUser
    property bool busy: false
    property string errorText: ""
    property date now: new Date()

    function focusInput() {
        if (manual && !account.editText.trim()) account.contentItem.forceActiveFocus()
        else password.forceActiveFocus()
    }
    function switchUser(other) {
        if (busy) return
        password.clear()
        errorText = ""
        switching = other
        account.currentIndex = -1
        account.editText = ""
        focusInput()
    }
    function login() {
        if (busy || !loginName || session.currentIndex < 0) return
        errorText = ""
        busy = true
        sddm.login(loginName, password.text, session.currentIndex)
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
    Component.onCompleted: Qt.callLater(root.focusInput)
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }

    color: surface
    Image {
        anchors.fill: parent
        source: /^(a|b)[.]jpg$/.test(root.imageFile) ? config.stringValue("assets") + root.imageFile : ""
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: "#69000000" }

    component Action: AbstractButton {
        id: button
        property string symbol
        property bool showLabel: false
        property bool primary: false
        property string hint: showLabel || primary ? "" : text
        font.family: root.mono; font.styleName: "Medium"; font.pixelSize: 15
        implicitHeight: 38
        implicitWidth: showLabel ? glyph.implicitWidth + label.implicitWidth + 32 : implicitHeight
        hoverEnabled: true
        Accessible.name: text
        background: Rectangle {
            radius: 10
            color: button.primary ? root.accent : button.down || button.hovered || button.visualFocus
                ? root.panel : "transparent"
            border.width: button.visualFocus ? 2 : 0
            border.color: button.primary ? root.ink : root.accent
            opacity: button.enabled ? (button.down ? 0.8 : 1) : 0.5
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        contentItem: Item {
            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: button.symbol; font.family: root.symbols; font.pixelSize: button.primary ? 23 : 20
                    color: button.primary ? root.accentInk : button.showLabel ? root.accent : root.ink
                }
                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    visible: button.showLabel
                    width: Math.min(implicitWidth, Math.max(0, button.width - glyph.implicitWidth - 32))
                    text: button.text; font: button.font; color: root.ink
                    elide: Text.ElideRight; textFormat: Text.PlainText
                }
            }
        }
        ToolTip {
            visible: button.hovered && !!button.hint
            delay: 500; text: button.hint; y: -implicitHeight - 4
            background: Rectangle { radius: 8; color: root.panel }
            contentItem: Text { text: button.hint; color: root.ink; font.family: root.mono; font.pixelSize: 12 }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    component Picker: ComboBox {
        id: box
        property string symbol
        property bool opensUp: false
        implicitHeight: 40
        leftPadding: editable ? 49 : 36; rightPadding: editable ? 44 : 25
        font.family: root.mono; font.pixelSize: 14
        palette.text: root.ink; palette.buttonText: root.ink; palette.highlight: root.accent
        background: Rectangle {
            radius: box.editable ? 15 : 12
            color: box.editable || box.hovered || box.visualFocus || box.popup.visible ? root.panel : "transparent"
            border.width: box.activeFocus && box.editable ? 2 : box.visualFocus ? 1 : 0
            border.color: root.accent
            Text {
                anchors.left: parent.left; anchors.leftMargin: box.editable ? 16 : 10; anchors.verticalCenter: parent.verticalCenter
                text: box.symbol; font.family: root.symbols; font.pixelSize: box.editable ? 21 : 19; color: root.accent
            }
        }
        indicator: Text {
            visible: box.count > 0 && (box.editable || box.count > 1)
            x: box.width - width - (box.editable ? 18 : 7); y: (box.height - height) / 2
            text: box.opensUp ? "expand_less" : "expand_more"
            font.family: root.symbols; font.pixelSize: 18; color: root.muted
        }
        delegate: ItemDelegate {
            required property int index
            width: box.popup.width - 8
            highlighted: box.highlightedIndex === index
            contentItem: Text {
                text: box.textAt(index); font: box.font; color: root.ink; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight; textFormat: Text.PlainText
            }
            background: Rectangle { radius: 8; color: parent.highlighted ? root.field : "transparent" }
        }
        popup: Popup {
            y: box.opensUp ? -height - 6 : box.height + 6
            width: box.width; padding: 4
            implicitHeight: Math.min(190, contentItem.implicitHeight + 8)
            contentItem: ListView {
                clip: true; implicitHeight: contentHeight; currentIndex: box.highlightedIndex
                model: box.popup.visible ? box.delegateModel : null
            }
            background: Rectangle { radius: 12; color: root.panel }
        }
    }

    Item {
        id: stage
        anchors.centerIn: parent
        width: root.width / root.uiScale; height: root.height / root.uiScale; scale: root.uiScale

        Column {
            id: clockBlock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -84
            width: Math.min(344, stage.width - 40)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: root.ink; font.family: root.mono; font.styleName: "Bold"; font.pixelSize: 96
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.now.toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d")
                color: root.ink; font.family: root.mono; font.styleName: "Medium"; font.pixelSize: 19
            }
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockBlock.bottom; anchors.topMargin: 36
            width: clockBlock.width
            height: feedback.visible ? feedback.y + feedback.height : passwordRow.y + passwordRow.height
            Item {
                id: accountSlot
                width: parent.width; height: (account.height + 8) * root.accountReveal
                visible: root.manual || height > 0
                clip: true
                Picker {
                    id: account
                    width: parent.width; height: 54; y: -6 * (1 - root.accountReveal)
                    opacity: root.accountReveal; enabled: root.manual && !root.busy
                    model: userModel; textRole: "name"; currentIndex: -1
                    editable: true; symbol: "person"; font.pixelSize: 20
                    Accessible.name: "Username"
                    contentItem: TextField {
                        padding: 0; background: null
                        text: account.editText; font: account.font; color: root.ink
                        placeholderText: "Username"; placeholderTextColor: root.muted
                        verticalAlignment: TextInput.AlignVCenter
                        readOnly: account.down; selectByMouse: true
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    }
                    onEditTextChanged: if (root.manual) { password.clear(); root.errorText = "" }
                    onActivated: password.forceActiveFocus()
                    onAccepted: if (editText.trim()) password.forceActiveFocus()
                }
            }
            Rectangle {
                id: passwordRow
                anchors.top: accountSlot.bottom
                width: parent.width; height: 54; radius: 15
                color: root.panel; border.width: 2
                border.color: root.errorText ? root.errorInk : password.activeFocus ? root.accent : root.field
                Text {
                    id: lockIcon
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    text: "lock"; font.family: root.symbols; font.pixelSize: 21; color: root.accent
                }
                PasswordField {
                    id: password
                    anchors.left: lockIcon.right; anchors.leftMargin: 12
                    anchors.right: submit.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 6; padding: 0; clip: true; background: null
                    textSize: 16; accent: root.accent; color: root.ink
                    placeholderText: root.busy ? "Signing in…" : "Password"; placeholderTextColor: root.muted
                    readOnly: root.busy; selectByMouse: true
                    onTextEdited: root.errorText = ""
                    onAccepted: root.login()
                }
                Action {
                    id: submit
                    anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                    height: 40; width: height
                    primary: true; symbol: "arrow_forward"; text: "Sign in"
                    enabled: !root.busy && root.loginName.length > 0 && session.currentIndex >= 0
                    onClicked: root.login()
                }
            }
            Text {
                id: feedback
                anchors.top: passwordRow.bottom; anchors.topMargin: 8
                width: parent.width; visible: !!root.errorText
                horizontalAlignment: Text.AlignHCenter; text: root.errorText; color: root.errorInk
                font.family: root.mono; font.pixelSize: 13; wrapMode: Text.WordWrap
            }
        }

        Action {
            id: accountSwitch
            readonly property bool showsBack: root.accountReveal >= 0.5
            visible: !!root.defaultUser; enabled: !root.busy
            showLabel: true; height: 40
            width: Math.min(implicitWidth, 240, stage.width - 32)
            opacity: Math.abs(2 * root.accountReveal - 1)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: stage.width < 240 + 2 * (Math.max(sessionTools.width, powerTools.width) + 24) ? 62 : 16
            symbol: showsBack ? "arrow_back" : "person"
            text: showsBack ? "Back" : root.defaultUser
            hint: root.switching ? "" : "Switch user"
            Accessible.name: root.switching ? "Back" : "Switch user, " + root.defaultUser
            onClicked: root.switchUser(!root.switching)
        }
        Row {
            id: sessionTools
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 16; spacing: 4
            enabled: !root.busy
            Picker {
                id: session
                symbol: "desktop_windows"; width: 134; opensUp: true
                model: sessionModel; textRole: "name"; Accessible.name: "Desktop session"
                Component.onCompleted: {
                    const niri = find("Niri", Qt.MatchFixedString)
                    currentIndex = niri >= 0 ? niri : count ? Math.max(0, Math.min(count - 1, sessionModel.lastIndex)) : -1
                }
                onActivated: root.focusInput()
            }
            Picker {
                id: layoutPicker
                symbol: "keyboard"; width: 86; opensUp: true
                model: keyboard.layouts.map(layout => layout.shortName)
                visible: count > 1; currentIndex: keyboard.currentLayout; Accessible.name: "Keyboard layout"
                onActivated: index => { keyboard.currentLayout = index; root.focusInput() }
            }
        }
        Row {
            id: powerTools
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16; spacing: 6
            enabled: !root.busy
            Action { text: "Sleep"; symbol: "bedtime"; visible: sddm.canSuspend; onClicked: sddm.suspend() }
            Action { text: "Restart"; symbol: "restart_alt"; visible: sddm.canReboot; onClicked: sddm.reboot() }
            Action { text: "Power off"; symbol: "power_settings_new"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.switching && !root.busy && !account.popup.visible && !session.popup.visible && !layoutPicker.popup.visible
        onActivated: root.switchUser(false)
    }
}
