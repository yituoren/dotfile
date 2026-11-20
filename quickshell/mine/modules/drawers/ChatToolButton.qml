import QtQuick
import QtQuick.Controls
import qs.services

AbstractButton {
    id: button
    hoverEnabled: true
    Accessible.name: text
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    ToolTip {
        id: hint
        parent: button
        // Keep the hint above the toolbar, clear of the separate web surface.
        x: (button.width - implicitWidth) / 2
        y: -implicitHeight - 6
        margins: 8
        delay: 550
        visible: button.enabled && button.visible && button.hovered && !button.down
        text: button.text
        horizontalPadding: 11
        verticalPadding: 6
        contentItem: Text {
            text: hint.text
            font.family: "Maple Mono NF CN"
            font.styleName: "Medium"
            font.pixelSize: 13
            color: Theme.colors.on_surface
        }
        background: Rectangle {
            radius: 10
            color: Theme.colors.surface_container_high
            border.color: Theme.colors.outline_variant
            border.width: 1
        }
    }
}
