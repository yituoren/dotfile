pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

FocusScope {
    id: face

    required property url wallpaper
    required property var palette
    required property date now
    required property bool checking
    required property string feedback
    signal submitted(string value)
    signal edited()

    readonly property color ink: palette.on_surface || "#dfe3e7"
    readonly property color muted: palette.on_surface_variant || "#c0c8cd"
    readonly property color surface: palette.surface_container || "#1b2023"
    readonly property color accent: palette.primary || "#8ccff0"
    readonly property color accentInk: palette.on_primary || "#003547"
    readonly property color errorInk: palette.error || "#ffb4ab"
    readonly property string mono: "Maple Mono NF CN"
    readonly property string symbols: "Material Symbols Rounded"
    readonly property real scaleFactor: Math.min(1.22, Math.max(0.78, height / 1000))
    property bool entering: false
    property int wakeKey: Qt.Key_unknown
    property real reveal: entering ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    focus: true

    function clearInput(): void { password.clear() }
    function revealInput(): void {
        entering = true
        password.forceActiveFocus()
        clearTimer.restart()
    }
    function dismiss(): void {
        if (checking) return
        clearInput()
        entering = false
        wakeKey = Qt.Key_unknown
        wakeTarget.forceActiveFocus()
        clearTimer.stop()
    }
    function submit(): void {
        revealInput()
        if (password.length && !checking) submitted(password.text)
    }

    Item {
        id: wakeTarget
        focus: true
        Keys.onShortcutOverride: event => { event.accepted = true }
        Keys.onPressed: event => {
            event.accepted = true
            if (event.isAutoRepeat) return
            face.entering = true
            clearTimer.restart()
            // Keep a wake chord such as Ctrl+V together until its action key arrives.
            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_AltGr].includes(event.key)) return
            face.wakeKey = event.key
            password.forceActiveFocus()
        }
        Keys.onReleased: event => {
            event.accepted = true
            if (face.entering && !event.isAutoRepeat) password.forceActiveFocus()
        }
    }
    Timer {
        id: clearTimer
        interval: 30000
        onTriggered: face.dismiss()
    }
    Image {
        id: background
        anchors.fill: parent
        source: width > 0 && height > 0 ? face.wallpaper : ""
        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectCrop
    }
    MultiEffect {
        anchors.fill: parent
        source: background
        blurEnabled: true
        blurMax: 48
        blur: 0.12 + 0.76 * face.reveal
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.24 + 0.19 * face.reveal
        TapHandler {
            acceptedButtons: Qt.AllButtons
            onTapped: face.revealInput()
        }
    }

    Item {
        id: clockBlock
        width: parent.width
        height: clockText.height + dateText.height
        y: Math.round((parent.height - height) / 2 - (26 + 58 * face.reveal) * face.scaleFactor)

        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(face.now, "HH:mm")
            font.family: face.mono
            font.styleName: "Bold"
            font.pixelSize: Math.round(96 * face.scaleFactor)
            color: face.ink
        }
        Text {
            id: dateText
            anchors.top: clockText.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.now.toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d")
            color: face.ink
            font.family: face.mono
            font.styleName: "Medium"
            font.pixelSize: Math.round(19 * face.scaleFactor)
        }
    }

    Rectangle {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(clockBlock.y + clockBlock.height + (36 + 10 * (1 - face.reveal)) * face.scaleFactor)
        width: Math.min(parent.width - 32, Math.round(344 * face.scaleFactor))
        height: Math.round(54 * face.scaleFactor)
        radius: Math.round(15 * face.scaleFactor)
        opacity: face.reveal
        enabled: face.entering
        color: face.surface
        border.color: face.feedback.length ? face.errorInk : face.accent
        border.width: 2

        Text {
            id: padlock
            anchors.left: parent.left
            anchors.leftMargin: 17 * face.scaleFactor
            anchors.verticalCenter: parent.verticalCenter
            text: "lock"
            font.family: face.symbols
            font.pixelSize: 21 * face.scaleFactor
            color: face.accent
        }
        PasswordField {
            id: password
            anchors.left: padlock.right
            anchors.leftMargin: 12 * face.scaleFactor
            anchors.right: confirm.left
            anchors.rightMargin: 8 * face.scaleFactor
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            padding: 0
            leftPadding: 0
            height: parent.height - 6
            background: null
            accent: face.accent
            color: face.ink
            textSize: 16 * face.scaleFactor
            readOnly: face.checking
            placeholderText: face.checking ? "Unlocking…" : "Password"
            placeholderTextColor: face.muted
            onTextEdited: {
                face.edited()
                face.revealInput()
            }
            TapHandler { onTapped: face.revealInput() }
            onAccepted: face.submit()
            Keys.onPressed: event => {
                if (event.isAutoRepeat && event.key === face.wakeKey) event.accepted = true
                else if (event.key === Qt.Key_Escape) {
                    event.accepted = true
                    face.dismiss()
                }
            }
            Keys.onReleased: event => {
                if (event.key === face.wakeKey && !event.isAutoRepeat) face.wakeKey = Qt.Key_unknown
            }
        }
        Rectangle {
            id: confirm
            anchors.right: parent.right
            anchors.rightMargin: 7 * face.scaleFactor
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 14 * face.scaleFactor
            width: height
            radius: 10 * face.scaleFactor
            color: face.accent
            opacity: face.checking ? 0.5 : tap.pressed ? 0.75 : 1
            Text {
                anchors.centerIn: parent
                text: "arrow_forward"
                font.family: face.symbols
                font.pixelSize: 22 * face.scaleFactor
                color: face.accentInk
            }
            TapHandler { id: tap; onTapped: face.submit() }
        }
    }
    Text {
        anchors.top: field.bottom
        anchors.topMargin: 10 * face.scaleFactor
        anchors.horizontalCenter: parent.horizontalCenter
        width: field.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        opacity: face.reveal
        text: face.feedback
        textFormat: Text.PlainText
        color: face.errorInk
        font.family: face.mono
        font.pixelSize: 13 * face.scaleFactor
    }
}
