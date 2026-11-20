pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.services

Rectangle {
    id: root
    color: "black"
    MouseArea { anchors.fill: parent }
    signal resizeRequested(rect start, int edges, real dx, real dy)
    signal moveRequested(real x, real y)
    required property bool activeMenu
    required property string outputName
    required property real fullWidth
    required property real fullHeight
    required property real uiScale
    readonly property real zoom: Math.min(1, width / fullWidth, height / fullHeight)
    readonly property bool cloud: activeMenu && !Chat.local
    readonly property int pad: Math.round(12 * uiScale)
    readonly property int header: Math.round(52 * uiScale)

    // The web surface occupies only the inset below the toolbar. Follow the same
    // animated origin and scale as the bar menu, keeping webpage layout stable.
    readonly property var frame: {
        if (!visible || Chat.local || zoom <= 0.02) return null
        return { output: outputName, x: Math.round(root.x + pad * zoom),
            y: Math.round(root.y + header * zoom), zoom,
            width: Math.round(fullWidth - 2 * pad), height: Math.round(fullHeight - header - pad) }
    }
    function publish(): void {
        if (Chat.outputName === outputName) Chat.viewport = frame
    }
    onFrameChanged: Qt.callLater(publish)
    onCloudChanged: if (cloud) Chat.ensureHost()

    Item {
        width: root.fullWidth / root.uiScale
        height: root.fullHeight / root.uiScale
        scale: root.uiScale * root.zoom
        transformOrigin: Item.TopLeft
        opacity: root.zoom
        enabled: root.activeMenu && root.zoom >= 0.999
        Loader {
            x: 12; y: 52
            width: parent.width - 24; height: parent.height - y - 12
            active: root.activeMenu && Chat.local
            sourceComponent: LocalChat {}
        }
        MouseArea {
            id: handle
            width: parent.width; height: 52
            enabled: root.activeMenu && root.zoom >= 0.999
            property point offset
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            onPressed: event => {
                const pos = mapToItem(null, event.x, event.y)
                offset = Qt.point(pos.x - root.x, pos.y - root.y)
            }
            onPositionChanged: event => {
                if (!pressed) return
                const pos = mapToItem(null, event.x, event.y)
                root.moveRequested(pos.x - offset.x, pos.y - offset.y)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 30; height: 4; radius: 2
                color: Theme.colors.outline_variant
            }
        }
        Rectangle {
            id: modes
            x: 12; y: 8
            width: Math.min(90, parent.width - 110); height: 36; radius: 14
            color: Theme.colors.surface_container
            Rectangle {
                x: Chat.local ? modes.width / 2 : 3
                y: 3; height: modes.height - 6; width: modes.width / 2 - 3
                radius: 11; color: Theme.colors.primary_container
                Behavior on x { NumberAnimation { duration: 155; easing.type: Easing.OutCubic } }
            }
            Row {
                Repeater {
                    model: [{ icon: "cloud", label: "Cloud" }, { icon: "computer", label: "Local" }]
                    delegate: ChatToolButton {
                        required property int index
                        required property var modelData
                        width: modes.width / 2; height: modes.height
                        text: modelData.label
                        contentItem: Text {
                            text: modelData.icon
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: "Material Symbols Rounded"; font.pixelSize: 20
                            color: Chat.local === (index === 1) ? Theme.colors.on_primary_container : Theme.colors.on_surface_variant
                        }
                        onClicked: Chat.local = index === 1
                    }
                }
            }
        }
        Row {
            visible: !Chat.local
            anchors.right: parent.right; anchors.rightMargin: 12
            y: 8; spacing: 4
            Repeater {
                model: [{ icon: "arrow_back", label: "Back", action: "back" },
                        { icon: "refresh", label: "Reload", action: "reload" },
                        { icon: "open_in_new", label: "Open in Chrome", action: "browser" }]
                delegate: ChatToolButton {
                    id: control
                    required property var modelData
                    width: 29; height: 36
                    text: modelData.label
                    background: Rectangle {
                        radius: 10; color: control.hovered ? Theme.colors.surface_container_high : "transparent"
                    }
                    contentItem: Text {
                        text: control.modelData.icon; font.family: "Material Symbols Rounded"; font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        color: Theme.colors.on_surface_variant
                    }
                    onClicked: {
                        if (modelData.action === "browser") {
                            Chat.opened = false
                            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/toggle-chat.py"), root.outputName])
                        } else Chat.send({ action: modelData.action })
                    }
                }
            }
        }
    }

    // Only the frame receives resize presses. Corners take both axes.
    Repeater {
        model: [Qt.LeftEdge, Qt.RightEdge, Qt.TopEdge, Qt.BottomEdge,
                Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge | Qt.RightEdge,
                Qt.BottomEdge | Qt.LeftEdge, Qt.BottomEdge | Qt.RightEdge]
        delegate: MouseArea {
            required property int modelData
            readonly property bool leftEdge: (modelData & Qt.LeftEdge) !== 0
            readonly property bool topEdge: (modelData & Qt.TopEdge) !== 0
            readonly property bool horizontal: leftEdge || (modelData & Qt.RightEdge) !== 0
            readonly property bool vertical: topEdge || (modelData & Qt.BottomEdge) !== 0
            readonly property real grip: horizontal && vertical ? root.pad : Math.round(root.pad * 0.7)
            x: horizontal && !leftEdge ? root.width - width : 0
            y: vertical && !topEdge ? root.height - height : 0
            width: horizontal ? grip : root.width
            height: vertical ? grip : root.height
            enabled: root.activeMenu && root.zoom >= 0.999
            preventStealing: true
            cursorShape: horizontal && vertical ? (leftEdge === topEdge ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                       : horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
            property point pressPosition
            property rect startGeometry
            onPressed: event => {
                pressPosition = mapToItem(null, event.x, event.y)
                startGeometry = Qt.rect(root.x, root.y, root.fullWidth, root.fullHeight)
            }
            onPositionChanged: event => {
                if (!pressed) return
                const pos = mapToItem(null, event.x, event.y)
                root.resizeRequested(startGeometry, modelData, pos.x - pressPosition.x, pos.y - pressPosition.y)
            }
        }
    }
}
