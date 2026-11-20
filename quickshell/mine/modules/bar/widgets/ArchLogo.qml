pragma ComponentBehavior: Bound

// Arch Linux Nerd Font glyph (nf-linux-archlinux, U+F303).
// Maple Mono NF CN includes the glyph at this code point.

import QtQuick
import Quickshell
import qs.services

Text {
    id: root
    required property var triggerScreen
    text: ""
    color: Theme.colors.primary
    font.family: "Maple Mono NF CN"
    font.pixelSize: 20
    font.styleName: "ExtraBold"

    MouseArea {
        anchors.fill: parent
        anchors.margins: -5
        cursorShape: Qt.PointingHandCursor
        onClicked: Chat.toggle(root.triggerScreen, root.mapToItem(null, root.width / 2, 0).x)
    }
}
