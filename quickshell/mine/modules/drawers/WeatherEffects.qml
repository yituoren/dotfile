pragma ComponentBehavior: Bound

// Overlay weather particles according to Weather.currentCode.
//
// Supported effects:
//   - Rain: 60 slanted strokes with randomized positions, speeds and lengths.
//   - Snow: 40 circles drift slowly down and sideways.
//   - Thunder: flash the entire layer and fade it every 4 to 8 seconds.
//   - Clear, cloudy and foggy conditions have no particle effect.
//
// Example:
//   WeatherEffects { anchors.fill: parent } belongs above the controls inside WeatherTab.

import QtQuick
import qs.services

Item {
    id: root
    clip: true

    // Crossfade changing conditions over 0.4 seconds.
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // ============ Rain ============
    Repeater {
        model: Weather.isPrecip ? 70 : 0
        delegate: Rectangle {
            id: drop
            required property int index
            // Bind random parameters once to keep them stable across frames.
            readonly property real speedMs: 700 + (drop.index * 113) % 700
            readonly property real lengthPx: 10 + (drop.index * 37) % 8
            readonly property real xStart: (drop.index * 71) % Math.max(1, root.width)
            readonly property real delay: (drop.index * 41) % 1500

            width: 1
            height: drop.lengthPx
            color: Qt.rgba(0.7, 0.8, 1.0, 0.55)
            rotation: 12
            opacity: 0.7
            x: drop.xStart

            NumberAnimation on y {
                from: -drop.lengthPx - 10
                to: root.height + 10
                duration: drop.speedMs
                loops: Animation.Infinite
                running: Weather.isPrecip
                // Stagger the initial drop delays.
                Component.onCompleted: {
                    // Offset the initial y coordinate.
                }
            }
        }
    }

    // ============ Snow ============
    Repeater {
        model: Weather.isSnow ? 40 : 0
        delegate: Rectangle {
            id: flake
            required property int index
            readonly property real speedMs: 4500 + (flake.index * 211) % 3000
            readonly property real radius_: 2 + (flake.index * 7) % 3
            readonly property real xBase: (flake.index * 89) % Math.max(1, root.width)
            readonly property real swayAmp: 12 + (flake.index * 17) % 18
            readonly property real swayDur: 2200 + (flake.index * 67) % 1800

            width: flake.radius_ * 2
            height: flake.radius_ * 2
            radius: flake.radius_
            color: Qt.rgba(1, 1, 1, 0.85)

            x: flake.xBase
            NumberAnimation on y {
                from: -10
                to: root.height + 10
                duration: flake.speedMs
                loops: Animation.Infinite
                running: Weather.isSnow
            }
            // Lateral drift
            SequentialAnimation on x {
                loops: Animation.Infinite
                running: Weather.isSnow
                NumberAnimation { from: flake.xBase - flake.swayAmp; to: flake.xBase + flake.swayAmp; duration: flake.swayDur; easing.type: Easing.InOutSine }
                NumberAnimation { from: flake.xBase + flake.swayAmp; to: flake.xBase - flake.swayAmp; duration: flake.swayDur; easing.type: Easing.InOutSine }
            }
        }
    }

    // ============ Thunder flash ============
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: Weather.isThunder

        SequentialAnimation {
            id: flashAnim
            running: Weather.isThunder
            loops: Animation.Infinite
            PauseAnimation { duration: 4000 + Math.floor(Math.random() * 4000) }
            // Double flash
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.4; duration: 60 }
            NumberAnimation { target: flash; property: "opacity"; from: 0.4; to: 0; duration: 80 }
            PauseAnimation { duration: 120 }
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.55; duration: 50 }
            NumberAnimation { target: flash; property: "opacity"; from: 0.55; to: 0; duration: 200 }
        }
    }

    // ============ Fog overlay ============
    Rectangle {
        anchors.fill: parent
        visible: Weather.isFog
        opacity: 0.18
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(0.9, 0.9, 0.9, 1) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
