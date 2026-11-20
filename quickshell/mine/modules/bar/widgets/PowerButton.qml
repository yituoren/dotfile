pragma ComponentBehavior: Bound

// Open the power dropdown.
// Show the error color on hover.

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    text: "power_settings_new"
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    // Center each right-hand icon in a fixed 22 px box so Row.spacing stays consistent
    // across Material Symbols with different glyph widths.
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: mouse.containsMouse ? Theme.colors.error : Theme.colors.on_surface
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "power", root.triggerScreen)
    }
}
