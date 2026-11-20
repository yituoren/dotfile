pragma ComponentBehavior: Bound

// Single entry point for the system tray.
// Open a popup listing StatusNotifierItems such as Clash Verge and Fcitx5.
// One apps glyph represents all tray icons on the bar.

import QtQuick
import Quickshell.Services.SystemTray
import qs.services

Text {
    id: root
    required property var triggerScreen

    text: "apps"
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    // Dim the icon when the tray is empty.
    color: SystemTray.items.values.length > 0 ? Theme.colors.on_surface
                                               : Theme.colors.on_surface_variant
    opacity: SystemTray.items.values.length > 0 ? 1 : 0.6
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "tray", root.triggerScreen)
    }
}
