pragma ComponentBehavior: Bound

// Reusable progress and value slider.
// Show the thumb on hover. Drag to update the value, then retract the thumb on release or exit.
//
// Example:
//   SliderBar {
//       value: SystemStatus.volume
//       onMoved: (v) => SystemStatus.setVolume(v)
//   }

import QtQuick
import qs.services

Item {
    id: root

    // Public API
    property real value: 0                  // 0.0 - 1.0
    property real wheelStep: 0.05           // Mouse wheel increment
    property real minValue: 0               // Lower bound. A minimum of 0.05 can prevent a brightness slider from blanking the screen.
    signal moved(real newValue)             // Emitted on user input. The parent writes the value to the backend.

    readonly property bool active: hover.containsMouse || hover.pressed

    implicitHeight: 24                      // Include a hover target above and below the visible track.

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 8
        radius: 4
        color: Theme.colors.surface_container_high

        // Filled track
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: Theme.colors.primary
        }
    }

    // The white thumb matches IosSwitch. Show it on hover or press.
    Rectangle {
        id: thumb
        readonly property real targetX: parent.width * Math.max(0, Math.min(1, root.value)) - width / 2
        x: Math.max(0, Math.min(parent.width - width, thumb.targetX))
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: "#ffffff"
        border.color: Theme.colors.outline_variant
        border.width: 1
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        z: 1
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function commit(mx) {
            const v = Math.max(root.minValue, Math.min(1, mx / width))
            root.moved(v)
        }

        onPressed: (mouse) => hover.commit(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed) hover.commit(mouse.x)
        }
        onWheel: (event) => {
            const step = event.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep
            const v = Math.max(root.minValue, Math.min(1, root.value + step))
            root.moved(v)
            event.accepted = true
        }
    }
}
