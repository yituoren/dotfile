pragma ComponentBehavior: Bound

// Volume icon
// Left click opens the slider and mute toggle.
// Scroll to change volume by 5% without opening the dropdown.

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    text: SystemStatus.volumeIcon
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: SystemStatus.volumeSilent ? Theme.colors.on_surface_variant : Theme.colors.on_surface
    opacity: SystemStatus.volumeSilent ? 0.6 : 1
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: PopupManager.toggleAt(root, "volume", root.triggerScreen)
        onWheel: (event) => {
            SystemStatus.setVolumeDelta(event.angleDelta.y > 0 ? 5 : -5)
            event.accepted = true
        }
    }
}
