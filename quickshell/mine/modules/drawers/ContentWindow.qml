pragma ComponentBehavior: Bound

// One fullscreen PanelWindow per output places the bar and popup in the same scene graph.
// Caelestia.Blobs needs this shared scene graph for SDF metaball blending.
//
// Layer order:
//   1. BlobGroup and BlobRects draw the bar and popup shapes.
//   2. Bar widgets such as ArchLogo and WorkspaceIndicator draw over the bar.
//   3. A Loader places the active popup's content over its shape.
//   4. A fullscreen scrim below the popup handles outside clicks.
//
// Input mask:
//   - Closed: only the bar receives input. Other clicks pass through.
//   - Open: the bar and popup receive input, and the scrim handles outside clicks.

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Caelestia.Blobs
import qs.services
import qs.modules.bar.widgets

PanelWindow {
    id: root
    required property var modelData
    signal logoutRequested()
    screen: modelData

    WlrLayershell.namespace: "mine-shell"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // OnDemand lets a clicked TextField, such as the dashboard task entry, take keyboard focus.
    // With the default None mode the layer surface receives no keyboard events.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Reserve bar space through the struts in niri/layout.kdl.
    // A fullscreen anchor cannot reserve only the bar's height with an exclusive zone.

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    // ---- Bar geometry ----
    readonly property int barTopMargin: 8
    readonly property int barSideMargin: 8
    readonly property int barHeight: Math.round(44 * Theme.uiScale)
    readonly property int barRadius: Math.round(16 * Theme.uiScale)

    // Whether the bar, scrim and popup belong to this output
    readonly property bool popupOnThisScreen: PopupManager.currentScreen === root.modelData

    // Popup geometry in output-local coordinates
    // Scale both the SDF and the popup content by popupScale in the range [0, 1].
    //   By default openAmount animates through the entire range.
    //   A positive scaleFrom, as on the dashboard, limits the opening motion to the final portion.
    //   On close, openAmount and scale return to zero.
    // Read the current entry here so scaleFrom returns to zero as soon as closing begins.
    // This lets the popup shrink continuously to zero.
    readonly property real popupScaleFrom: {
        const e = PopupManager.entry
        return e && e.scaleFrom !== undefined ? e.scaleFrom : 0
    }
    readonly property real popupRawAmount: root.popupOnThisScreen ? PopupManager.openAmount : 0
    readonly property real popupScale: {
        const oa = root.popupRawAmount
        const sf = root.popupScaleFrom
        if (sf <= 0) return oa
        if (oa <= 0) return 0
        return Math.min(1, sf + (1 - sf) * oa)
    }
    readonly property real popupUiScale: PopupManager.popupScaleFor(PopupManager.entry ?? PopupManager.lastEntry, root.modelData)
    readonly property real popupWidth: PopupManager.displayWidth * root.popupScale * root.popupUiScale
    // Add dropdown expansion (extraHeight) to the registered displayHeight.
    property real trayExtraHeight: {
        if (!trayLoader.item || PopupManager.lastEntry !== PopupManager.registry.tray) return 0
        const base = PopupManager.registry.tray.height
        const available = (root.height - root.popupY - root.barSideMargin) / root.popupUiScale
        return Math.max(0, Math.min(available, trayLoader.item.pageHeight + 20) - base)
    }
    Behavior on trayExtraHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    readonly property real popupHeight: (PopupManager.displayHeight + PopupManager.extraHeight
            + (PopupManager.lastEntry === PopupManager.registry.tray ? root.trayExtraHeight : 0)) * root.popupScale * root.popupUiScale
    readonly property real barRight: root.width - root.barSideMargin
    readonly property real chatTopLimit: barTopMargin + barHeight
    readonly property real chatMaxWidth: Math.max(1, width - 2 * barSideMargin)
    readonly property real chatMaxHeight: Math.max(1, height - chatTopLimit - barSideMargin)
    readonly property real chatMinWidth: Math.min(chatMaxWidth, Math.round(270 * Theme.uiScale))
    readonly property real chatMinHeight: Math.min(chatMaxHeight, Math.round(200 * Theme.uiScale))
    // Dragging replaces the default geometry for this output.
    property rect chatGeometry: {
        const h = Math.min(Math.round(height * 0.8), height - 2 * chatTopLimit)
        return Qt.rect(3 * barSideMargin, Math.round((height - h) / 2), Math.round(width / 4), h)
    }
    function clamp(value: real, low: real, high: real): real {
        return Math.max(low, Math.min(value, high))
    }
    readonly property real chatFullWidth: clamp(chatGeometry.width, chatMinWidth, chatMaxWidth)
    readonly property real chatFullHeight: clamp(chatGeometry.height, chatMinHeight, chatMaxHeight)
    function boundedChatPosition(x: real, y: real): point {
        return Qt.point(clamp(x, barSideMargin, width - barSideMargin - chatFullWidth),
                        clamp(y, chatTopLimit, height - barSideMargin - chatFullHeight))
    }
    readonly property point chatOrigin: boundedChatPosition(chatGeometry.x, chatGeometry.y)

    function resizeChat(start: rect, edges: int, dx: real, dy: real): void {
        let left = start.x, right = start.x + start.width
        let top = start.y, bottom = start.y + start.height
        if (edges & Qt.LeftEdge) left = clamp(left + dx, barSideMargin, right - chatMinWidth)
        if (edges & Qt.RightEdge) right = clamp(right + dx, left + chatMinWidth, width - barSideMargin)
        if (edges & Qt.TopEdge) top = clamp(top + dy, chatTopLimit, bottom - chatMinHeight)
        if (edges & Qt.BottomEdge) bottom = clamp(bottom + dy, top + chatMinHeight, height - barSideMargin)
        chatGeometry = Qt.rect(left, top, right - left, bottom - top)
    }
    property real chatAmount: Chat.opened && Chat.outputName === modelData.name ? 1 : 0
    Behavior on chatAmount {
        NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }
    readonly property real popupX: {
        const centered = (root.width - root.popupWidth) / 2
        const right = PopupManager.anchorX + (root.barRight - PopupManager.anchorX) * root.popupRawAmount
        return centered + PopupManager.alignment * (right - root.popupWidth - centered)
    }
    // Straighten the lower-right corner near an attached menu and restore it as the menu closes.
    readonly property real rightJoin: {
        const gap = Math.max(0, root.barRight - (root.popupX + root.popupWidth))
        return Math.max(0, PopupManager.alignment) * Math.min(1, root.popupWidth / root.barRadius)
                * Math.max(0, 1 - gap / root.barRadius)
    }
    readonly property real leftJoin: Math.min(1, chatMenu.width / barRadius)
            * Math.max(0, 1 - (chatMenu.y - barTopMargin - barHeight) / barRadius)
            * Math.max(0, 1 - Math.max(0, chatMenu.x - barSideMargin) / barRadius)
    readonly property real popupY: barTopMargin + barHeight + 4 * (1 - rightJoin)

    // A reloaded panel can inherit the old Wayland surface and its last blur.
    // Attach an explicit empty region on every inactive surface, including at startup.
    BackgroundEffect.blurRegion: popupShape.trackBlur ? dashboardBlur : emptyBlur
    Region { id: emptyBlur }
    Region {
        id: dashboardBlur
        property var bands: []
        property Component bandType: Component { Region {} }

        // Reuse Wayland region rectangles as the SDF scanline runs change.
        function setBands(rects): void {
            for (let i = bands.length; i < rects.length; ++i) {
                const band = bandType.createObject(dashboardBlur)
                bands.push(band)
                regions.push(band)
            }
            for (let i = 0; i < bands.length; ++i) {
                const b = bands[i]
                if (i >= rects.length) {
                    b.width = 0
                    continue
                }
                const r = rects[i]
                b.x = r.x
                b.y = r.y
                b.width = r.width
                b.height = r.height
            }
        }
    }

    // ---- Input mask ----
    // The scrim covers every output while a menu is open. The web viewport
    // has its own Wayland surface and must receive its own pointer events.
    mask: Region {
        x: PopupManager.isOpen ? 0 : root.barSideMargin
        y: PopupManager.isOpen ? 0 : root.barTopMargin
        width: PopupManager.isOpen ? root.width : root.width - 2 * root.barSideMargin
        height: PopupManager.isOpen ? root.height : root.barHeight
        Region {
            x: Math.floor(chatMenu.x)
            y: Math.floor(chatMenu.y)
            width: Math.ceil(chatMenu.width)
            height: Math.ceil(chatMenu.height)
        }
        Region {
            readonly property var viewport: Chat.client?.connected && Chat.viewport?.output === root.modelData.name
                    ? Chat.viewport : null
            intersection: Intersection.Subtract
            x: viewport?.x ?? 0
            y: viewport?.y ?? 0
            width: viewport ? Math.round(viewport.width * viewport.zoom) : 0
            height: viewport ? Math.round(viewport.height * viewport.zoom) : 0
        }
    }

    // ==================== SDF shape layer ====================
    Item {
        anchors.fill: parent
        // Smooth minimum can bulge a few pixels where two straight edges meet.
        anchors.rightMargin: root.barSideMargin
        anchors.leftMargin: root.barSideMargin
        clip: root.rightJoin > 0 || root.leftJoin > 0

        BlobGroup {
            id: blobGroup
            color: "#000000"
            // A larger smoothing factor joins the bar and popup over a wider distance.
            smoothing: 32

            // Only transparent entries use a gradient. Others use black for both endpoint colors.
            // Keep lastEntry during closing so the gradient survives until the popup has shrunk.
            readonly property bool popupTransparent: {
                const e = PopupManager.entry ?? PopupManager.lastEntry
                return e && e.transparent === true
            }
            colorBottom: blobGroup.popupTransparent ? Qt.rgba(0, 0, 0, 0.35) : "#000000"
            gradientTop: root.popupY
            gradientBottom: root.popupY + root.popupHeight
        }

        // Fixed top bar rectangle
        BlobRect {
            id: barShape
            group: blobGroup
            x: 0
            y: root.barTopMargin
            implicitWidth: root.width - 2 * root.barSideMargin
            implicitHeight: root.barHeight
            radius: root.barRadius
            bottomLeftRadius: root.barRadius * (1 - root.leftJoin)
            bottomRightRadius: root.barRadius * (1 - root.rightJoin)
        }

        // Popup position and dimensions follow the PopupManager animation.
        BlobRect {
            id: popupShape
            trackBlur: root.popupOnThisScreen && blobGroup.popupTransparent && visible
            onBlurRectsChanged: dashboardBlur.setBands(blurRects)
            group: blobGroup
            visible: root.popupWidth > 0.5 && root.popupHeight > 0.5
            x: root.popupX - root.barSideMargin
            y: root.popupY
            implicitWidth: root.popupWidth
            implicitHeight: root.popupHeight
            deformScale: 0
            radius: root.barRadius
            topRightRadius: root.barRadius * (1 - root.rightJoin)
        }

    }

    BarSpectrum {
        width: Math.min(600 * Theme.uiScale, barShape.width - 2 * root.barRadius)
        height: Math.ceil(46 * Theme.uiScale)
        x: (root.width - width) / 2
        y: root.barTopMargin + root.barHeight - 2
        visible: Cava.showBarSpectrum && !(blobGroup.popupTransparent && root.popupRawAmount > 0)
        samples: visible ? Cava.values : []
        fill: blobGroup.color
    }

    // ==================== Outside-click scrim ====================
    // Declare before the popup content so controls receive clicks first.
    // Swallow clicks during opening so a hover-triggered popup can finish its transition.
    // Cover other outputs too. Clicking their scrims dismisses the popup.
    MouseArea {
        anchors.fill: parent
        visible: PopupManager.isOpen
        onClicked: {
            if (!PopupManager.openInProgress) PopupManager.close()
        }
    }

    // ==================== Bar Widgets ====================
    Item {
        id: barContent
        x: root.barSideMargin
        y: root.barTopMargin
        transformOrigin: Item.TopLeft
        scale: Theme.uiScale
        width: (root.width - 2 * root.barSideMargin) / scale
        height: root.barHeight / scale

        ArchLogo {
            id: archLogo
            triggerScreen: root.modelData
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
        }

        WorkspaceIndicator {
            id: workspaceStrip
            anchors {
                left: archLogo.right
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }
        }

        FocusedWindowTitle {
            id: titleText
            anchors.centerIn: parent
            readonly property real leftEdge: workspaceStrip.x + workspaceStrip.width
            readonly property real rightEdge: parent.width - rightCluster.x
            readonly property real availableWidth: Math.max(0, parent.width - 2 * Math.max(leftEdge, rightEdge) - 32)
            width: Math.min(implicitWidth, availableWidth)
        }

        Row {
            id: rightCluster
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }
            spacing: 12

            Clock { anchors.verticalCenter: parent.verticalCenter }
            SystemTrayIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            WifiIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            BluetoothIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            VolumeIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            BatteryIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            PowerButton { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
        }

        // Click the center trigger to toggle or hover for 80 ms to open.
        MouseArea {
            id: dashTriggerArea
            width: Math.min(320, titleText.text.length ? titleText.width : titleText.availableWidth)
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                if (!pressed && PopupManager.currentPopup !== "dashboard")
                    dashOpenTimer.restart()
            }
            onExited: dashOpenTimer.stop()
            onPressed: dashOpenTimer.stop()
            onClicked: PopupManager.toggle("dashboard", root.modelData, root.width / 2)

            Timer {
                id: dashOpenTimer
                interval: 80
                onTriggered: PopupManager.open("dashboard", root.modelData, root.width / 2)
            }
        }
    }

    // ==================== Popup Content ====================
    Item {
        id: popupContentArea
        visible: root.popupOnThisScreen && root.popupWidth > 0
        x: root.popupX
        y: root.popupY
        width: root.popupWidth
        height: root.popupHeight
        clip: true

        // Keep unhandled presses inside the panel from reaching the outside-click area.
        MouseArea { anchors.fill: parent }

        component PopupItem: Loader {
            id: popupItem
            required property string name
            readonly property bool shouldBeActive: PopupManager.currentPopup === popupItem.name
            anchors.centerIn: parent
            width: Math.max(0, parent.width / root.popupUiScale - 20)
            height: Math.max(0, parent.height / root.popupUiScale - 20)
            scale: root.popupUiScale
            opacity: 0
            active: false

            states: State {
                name: "active"
                when: popupItem.shouldBeActive
                PropertyChanges {
                    popupItem.active: true
                    popupItem.opacity: 1
                }
            }

            transitions: [
                Transition {
                    from: "active"; to: ""
                    SequentialAnimation {
                        NumberAnimation {
                            property: "opacity"; duration: 280
                            easing.type: Easing.OutQuad
                        }
                        PropertyAction { property: "active" }
                    }
                },
                Transition {
                    from: ""; to: "active"
                    SequentialAnimation {
                        PropertyAction { property: "active" }
                        NumberAnimation {
                            property: "opacity"; duration: 280
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            ]
        }

        PopupItem { name: "power";     sourceComponent: powerComp     }
        PopupItem { name: "wifi";      sourceComponent: wifiComp      }
        PopupItem { name: "bluetooth"; sourceComponent: bluetoothComp }
        PopupItem { name: "volume";    sourceComponent: volumeComp    }
        PopupItem { name: "battery";   sourceComponent: batteryComp   }
        PopupItem { id: trayLoader; name: "tray";      sourceComponent: trayComp      }
        Loader {
            // Lay out at the expanded size and scale the result to avoid reflowing text on every frame.
            anchors.centerIn: parent
            width: PopupManager.registry.dashboard.width - 20
            height: PopupManager.registry.dashboard.heightFn(root.modelData) - 20
            scale: Math.min(root.popupWidth / (width + 20), root.popupHeight / (height + 20))
            active: root.popupOnThisScreen && blobGroup.popupTransparent
                    && (PopupManager.isOpen || root.popupRawAmount > 0)
            opacity: root.popupRawAmount
            sourceComponent: dashboardComp
        }
    }

    ChatMenu {
        id: chatMenu
        outputName: root.modelData.name
        activeMenu: Chat.opened && Chat.outputName === outputName
        visible: root.chatAmount > 0
        x: Chat.anchorX + (root.chatOrigin.x - Chat.anchorX) * root.chatAmount
        y: root.barTopMargin + root.barHeight
           + (root.chatOrigin.y - root.barTopMargin - root.barHeight) * root.chatAmount
        width: fullWidth * root.chatAmount
        height: fullHeight * root.chatAmount
        fullWidth: root.chatFullWidth
        fullHeight: root.chatFullHeight
        uiScale: Theme.uiScale
        radius: root.barRadius * root.chatAmount
        topLeftRadius: radius * (1 - root.leftJoin)
        onMoveRequested: (x, y) => {
            const pos = root.boundedChatPosition(x, y)
            root.chatGeometry = Qt.rect(pos.x, pos.y, fullWidth, fullHeight)
        }
        onResizeRequested: (start, edges, dx, dy) => root.resizeChat(start, edges, dx, dy)
    }

    // ==================== Popup components ====================
    // The components are inline and can be split into separate files later.

    // Shared command process for the power menu
    Process {
        id: actionProcInternal
        onExited: code => {
            // The notify service returns after niri has securely covered every output.
            if (code === 0 && root.popupOnThisScreen && PopupManager.currentPopup === "power")
                PopupManager.close()
        }
    }

    // ==================== Power (2 by 2 icon grid) ====================
    Component {
        id: powerComp
        Grid {
            columns: 2
            spacing: 12
            enabled: !actionProcInternal.running
            // Each button pairs a Material container color with its matching on_*_container icon.
            Repeater {
                model: [
                    { icon: "lock", tone: "secondary", command: ["systemctl", "--user", "start", "mine-lock.service"] },
                    { icon: "logout", tone: "tertiary" },
                    { icon: "restart_alt", tone: "primary", command: ["systemctl", "reboot"] },
                    { icon: "power_settings_new", tone: "error", command: ["systemctl", "poweroff"] }
                ]
                Rectangle {
                    id: powerItem
                    required property var modelData
                    width: (parent.width - 12) / 2
                    height: width
                    radius: 20
                    color: powerHover.containsMouse
                        ? Qt.tint(Theme.colors[powerItem.modelData.tone + "_container"], "#20ffffff")
                        : Theme.colors[powerItem.modelData.tone + "_container"]
                    Behavior on color { ColorAnimation { duration: 150 } }
                    scale: powerHover.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: powerItem.modelData.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 42
                        color: Theme.colors["on_" + powerItem.modelData.tone + "_container"]
                    }

                    MouseArea {
                        id: powerHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (powerItem.modelData.icon === "logout") root.logoutRequested()
                            else {
                                actionProcInternal.command = powerItem.modelData.command
                                actionProcInternal.running = true
                                if (powerItem.modelData.icon !== "lock") PopupManager.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== Wi-Fi (switch, connection and networks) ====================
    Component {
        id: wifiComp
        Item {
            Component.onCompleted: SystemStatus.refreshWifi()

            // The top row contains airplane mode, Wi-Fi and a square refresh button.
            Row {
                id: switchRow
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 56
                spacing: 12

                // Airplane mode
                Rectangle {
                    // Split the remaining width after subtracting the 56 px refresh button and two gaps.
                    width: (switchRow.width - switchRow.spacing * 2 - 56) / 2
                    height: parent.height
                    radius: 16
                    color: Theme.colors.surface_container
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: "airplanemode_active"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: SystemStatus.airplaneMode ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    IosSwitch {
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        checked: SystemStatus.airplaneMode
                        onToggled: SystemStatus.toggleAirplaneMode()
                    }
                }

                // Wi-Fi switch
                Rectangle {
                    width: (switchRow.width - switchRow.spacing * 2 - 56) / 2
                    height: parent.height
                    radius: 16
                    color: Theme.colors.surface_container
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: SystemStatus.wifiEnabled ? "wifi" : "wifi_off"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: SystemStatus.wifiEnabled ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    IosSwitch {
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        checked: SystemStatus.wifiEnabled
                        onToggled: SystemStatus.toggleWifi()
                    }
                }

                // Square 56 px refresh button
                Rectangle {
                    width: 56
                    height: parent.height
                    radius: 16
                    color: wifiRefreshHover.containsMouse ? Theme.colors.surface_container_high : Theme.colors.surface_container
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: wifiRefreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: Theme.colors.on_surface

                        // Rotate the icon once per click.
                        property real rot: 0
                        rotation: rot
                        Behavior on rot {
                            NumberAnimation { duration: 500; easing.type: Easing.OutQuad }
                        }
                    }

                    MouseArea {
                        id: wifiRefreshHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SystemStatus.scanWifi()
                            wifiRefreshIcon.rot += 360
                        }
                    }
                }
            }

            // Use primary_container for connected and surface_container for disconnected.
            Rectangle {
                id: wifiHeader
                anchors {
                    top: switchRow.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: SystemStatus.wifiConnected
                    ? Theme.colors.primary_container
                    : Theme.colors.surface_container

                Text {
                    id: wifiHeaderIcon
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.wifiConnected ? "wifi" : "wifi_off"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 32
                    color: SystemStatus.wifiConnected
                        ? Theme.colors.on_primary_container
                        : Theme.colors.on_surface_variant
                }
                Column {
                    anchors {
                        left: wifiHeaderIcon.right
                        leftMargin: 14
                        right: parent.right
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        text: SystemStatus.wifiConnected ? SystemStatus.wifiSsid : "Not connected"
                        color: SystemStatus.wifiConnected
                            ? Theme.colors.on_primary_container
                            : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 16
                        font.styleName: "Bold"
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        visible: SystemStatus.wifiConnected || SystemStatus.wifiMessage.length > 0
                        width: parent.width
                        elide: Text.ElideRight
                        text: SystemStatus.wifiMessage || `${SystemStatus.wifiSignal}%`
                        color: Theme.colors.on_primary_container
                        opacity: 0.7
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 12
                    }
                }
            }

            // Network list
            PanelAction {
                id: wifiSettings
                symbol: "settings"
                trailingSymbol: "open_in_new"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 34
                text: "Network settings"
                onClicked: {
                    Quickshell.execDetached(["kcmshell6", "kcm_networkmanagement"])
                    PopupManager.close()
                }
            }

            ListView {
                anchors {
                    top: wifiHeader.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: wifiSettings.top
                    bottomMargin: 6
                }
                model: SystemStatus.wifiNetworks
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: wifiRow
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: 12
                    color: wifiRowHover.containsMouse
                        ? Theme.colors.surface_container_high
                        : (wifiRow.modelData.inUse ? Theme.colors.surface_container : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // Choose a Material Symbol by connection status, security and signal strength.
                    Text {
                        id: signalIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            const s = wifiRow.modelData.signal
                            if (wifiRow.modelData.secured) {
                                if (s >= 75) return "network_wifi_3_bar_locked"
                                if (s >= 50) return "network_wifi_2_bar_locked"
                                if (s >= 25) return "network_wifi_1_bar_locked"
                                return "signal_wifi_0_bar"
                            }
                            if (s >= 75) return "signal_wifi_4_bar"
                            if (s >= 50) return "network_wifi_3_bar"
                            if (s >= 25) return "network_wifi_2_bar"
                            if (s > 0)  return "network_wifi_1_bar"
                            return "signal_wifi_0_bar"
                        }
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: wifiRow.modelData.inUse ? Theme.colors.primary : Theme.colors.on_surface
                    }

                    Text {
                        anchors {
                            left: signalIcon.right
                            leftMargin: 10
                            right: checkIcon.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: wifiRow.modelData.ssid
                        color: wifiRow.modelData.inUse ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: wifiRow.modelData.inUse ? "Bold" : "Medium"
                        elide: Text.ElideRight
                    }

                    // Mark the connected network with a check.
                    Text {
                        id: checkIcon
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: wifiRow.modelData.inUse
                        text: "check"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.primary
                    }

                    MouseArea {
                        id: wifiRowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!wifiRow.modelData.inUse) {
                                SystemStatus.connectWifi(wifiRow.modelData.ssid, wifiRow.modelData.secured)
                                // Leave the popup open so the updated connection is visible.
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== Bluetooth (switch, status and devices) ====================
    Component {
        id: bluetoothComp
        Item {
            Component.onCompleted: SystemStatus.refreshBluetooth()

            // Bluetooth power and refresh. Airplane mode lives in the Wi-Fi popup.
            Row {
                id: btSwitchRow
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 56
                spacing: 12

                Rectangle {
                    width: btSwitchRow.width - btSwitchRow.spacing - 56
                    height: parent.height
                    radius: 16
                    color: Theme.colors.surface_container
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: SystemStatus.bluetoothPowered ? "bluetooth" : "bluetooth_disabled"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: SystemStatus.bluetoothPowered ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    IosSwitch {
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        checked: SystemStatus.bluetoothPowered
                        onToggled: SystemStatus.toggleBluetooth()
                    }
                }

                // Refresh
                Rectangle {
                    width: 56
                    height: parent.height
                    radius: 16
                    color: btRefreshHover.containsMouse ? Theme.colors.surface_container_high : Theme.colors.surface_container
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: btRefreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: Theme.colors.on_surface

                        property real rot: 0
                        rotation: rot
                        Behavior on rot {
                            NumberAnimation { duration: 500; easing.type: Easing.OutQuad }
                        }
                    }

                    MouseArea {
                        id: btRefreshHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SystemStatus.refreshBluetooth()
                            btRefreshIcon.rot += 360
                        }
                    }
                }
            }

            // Show the connected device count or the powered-off state.
            Rectangle {
                id: btHeader
                anchors {
                    top: btSwitchRow.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: SystemStatus.bluetoothConnected
                    ? Theme.colors.primary_container
                    : Theme.colors.surface_container

                Text {
                    id: btHeaderIcon
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.bluetoothPowered
                          ? (SystemStatus.bluetoothConnected ? "bluetooth_connected" : "bluetooth")
                          : "bluetooth_disabled"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 32
                    color: SystemStatus.bluetoothConnected
                        ? Theme.colors.on_primary_container
                        : Theme.colors.on_surface_variant
                }
                Text {
                    anchors {
                        left: btHeaderIcon.right
                        leftMargin: 14
                        right: parent.right
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.bluetoothMessage ? SystemStatus.bluetoothMessage
                          : !SystemStatus.bluetoothPowered ? "Bluetooth off"
                          : SystemStatus.bluetoothConnected
                                ? (SystemStatus.bluetoothDeviceCount === 1
                                    ? "1 device connected"
                                    : `${SystemStatus.bluetoothDeviceCount} devices connected`)
                                : "No devices connected"
                    color: SystemStatus.bluetoothConnected
                        ? Theme.colors.on_primary_container
                        : Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 16
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
            }

            // Device list
            PanelAction {
                id: pairDevice
                symbol: "bluetooth_searching"
                trailingSymbol: "open_in_new"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 34
                text: "Pair new device…"
                enabled: SystemStatus.bluetoothPowered
                onClicked: {
                    Quickshell.execDetached(["bluedevil-wizard"])
                    PopupManager.close()
                }
            }

            ListView {
                anchors {
                    top: btHeader.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: pairDevice.top
                    bottomMargin: 6
                }
                model: SystemStatus.bluetoothDevices
                clip: true
                spacing: 4

                // Show a hint when there are no paired devices.
                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: SystemStatus.bluetoothPowered ? "No paired devices" : ""
                    color: Theme.colors.on_surface_variant
                    opacity: 0.6
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                }

                delegate: Rectangle {
                    id: btRow
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: 12
                    color: btRowHover.containsMouse
                        ? Theme.colors.surface_container_high
                        : (btRow.modelData.connected ? Theme.colors.surface_container : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // Choose a Material Symbol from the device name.
                    readonly property string deviceIcon: {
                        const n = btRow.modelData.name.toLowerCase()
                        if (/headphone|headset|buds|airpod|earbud/.test(n)) return "headphones"
                        if (/keyboard|kbd/.test(n)) return "keyboard"
                        if (/mouse|trackpad/.test(n)) return "mouse"
                        if (/speaker|soundbar/.test(n)) return "speaker"
                        if (/phone|pixel|iphone|samsung|xiaomi|huawei/.test(n)) return "smartphone"
                        if (/watch/.test(n)) return "watch"
                        if (/laptop|macbook|computer/.test(n)) return "laptop_chromebook"
                        return "bluetooth"
                    }

                    Text {
                        id: btDevIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: btRow.deviceIcon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: btRow.modelData.connected ? Theme.colors.primary : Theme.colors.on_surface
                    }

                    Text {
                        anchors {
                            left: btDevIcon.right
                            leftMargin: 10
                            right: btCheckIcon.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: btRow.modelData.name
                        color: btRow.modelData.connected ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: btRow.modelData.connected ? "Bold" : "Medium"
                        elide: Text.ElideRight
                    }

                    Text {
                        id: btCheckIcon
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: btRow.modelData.connected
                        text: "check"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.primary
                    }

                    MouseArea {
                        id: btRowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (btRow.modelData.connected) {
                                SystemStatus.disconnectBluetoothDevice(btRow.modelData.mac)
                            } else {
                                SystemStatus.connectBluetoothDevice(btRow.modelData.mac)
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== Volume (slider and output selector) ====================
    Component {
        id: volumeComp
        Item {
            id: volRoot
            Component.onCompleted: SystemStatus.refreshAudio()

            // Current default sink
            readonly property var defaultSink: SystemStatus.audioSinks.find(s => s.isDefault) || null
            // Derive expansion from PopupManager.extraHeight.
            readonly property bool sinksExpanded: PopupManager.extraHeight > 4

            function sinkIcon(sink) {
                if (!sink) return "speaker"
                const n = sink.name.toLowerCase()
                const d = sink.description.toLowerCase()
                if (/bluez/.test(n)) return "bluetooth_audio"
                if (/hdmi/.test(n) || /hdmi/.test(d)) return "tv"
                if (/usb/.test(n) && /head/.test(d)) return "headset"
                return "speaker"
            }

            // Top volume slider
            Rectangle {
                id: volCard
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: Theme.colors.surface_container

                Text {
                    id: volMuteIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: SystemStatus.volumeIcon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 26
                    color: SystemStatus.volumeSilent ? Theme.colors.on_surface_variant : Theme.colors.primary
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemStatus.toggleMute()
                    }
                }

                SliderBar {
                    anchors {
                        left: volMuteIcon.right
                        leftMargin: 12
                        right: volPercentText.left
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    value: SystemStatus.volume
                    onMoved: (v) => SystemStatus.setVolume(v)
                }

                Text {
                    id: volPercentText
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: SystemStatus.volumeSilent ? "—" : `${SystemStatus.volumePercent}%`
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 14
                    font.styleName: "Bold"
                }
            }

            // Show the current sink and a chevron. Toggle extraHeight when clicked.
            // Highlight the selected output with the same primary_container used for active connections.
            Rectangle {
                id: sinkButton
                anchors {
                    top: volCard.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 56
                radius: 16
                color: sinkButtonHover.containsMouse
                    ? Qt.tint(Theme.colors.primary_container, "#15ffffff")
                    : Theme.colors.primary_container
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: curSinkIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: volRoot.sinkIcon(volRoot.defaultSink)
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Theme.colors.on_primary_container
                }

                Text {
                    anchors {
                        left: curSinkIcon.right
                        leftMargin: 10
                        right: chevron.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: volRoot.defaultSink ? volRoot.defaultSink.description : "—"
                    color: Theme.colors.on_primary_container
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }

                Text {
                    id: chevron
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: volRoot.sinksExpanded ? "expand_less" : "expand_more"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Theme.colors.on_primary_container
                    opacity: 0.7
                }

                MouseArea {
                    id: sinkButtonHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PopupManager.extraHeight = volRoot.sinksExpanded ? 0 : 160
                }
            }

            // Render the sink list and reserve its height only while expanded.
            ListView {
                id: sinkList
                anchors {
                    top: sinkButton.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                visible: volRoot.sinksExpanded
                model: SystemStatus.audioSinks
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: sinkRow
                    required property var modelData
                    width: ListView.view.width
                    height: 40
                    radius: 12
                    color: sinkHover.containsMouse
                        ? Theme.colors.surface_container_high
                        : (sinkRow.modelData.isDefault ? Theme.colors.surface_container : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: sinkIconText
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: volRoot.sinkIcon(sinkRow.modelData)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: sinkRow.modelData.isDefault ? Theme.colors.primary : Theme.colors.on_surface
                    }

                    Text {
                        anchors {
                            left: sinkIconText.right
                            leftMargin: 10
                            right: sinkCheck.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: sinkRow.modelData.description
                        color: sinkRow.modelData.isDefault ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: sinkRow.modelData.isDefault ? "Bold" : "Medium"
                        elide: Text.ElideRight
                    }

                    Text {
                        id: sinkCheck
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: sinkRow.modelData.isDefault
                        text: "check"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.primary
                    }

                    MouseArea {
                        id: sinkHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!sinkRow.modelData.isDefault) {
                                SystemStatus.setDefaultSink(sinkRow.modelData.name)
                            }
                            // Collapse after selection.
                            PopupManager.extraHeight = 0
                        }
                    }
                }
            }
        }
    }

    // ==================== Battery and display brightness ====================
    Component {
        id: batteryComp
        Item {
            id: batRoot

            // Use the popup's output name to select the brightness backend.
            readonly property string screenName: PopupManager.currentScreen ? PopupManager.currentScreen.name : ""
            readonly property bool hasBrightness: batRoot.screenName.length > 0
            readonly property real currentBrightness: {
                if (!batRoot.screenName) return 1.0
                const v = SystemStatus.brightnessByScreen[batRoot.screenName]
                return v !== undefined ? v : 1.0
            }
            readonly property int currentBrightnessPct: Math.round(batRoot.currentBrightness * 100)

            Component.onCompleted: {
                if (!batRoot.screenName) return
                // Use the prefetched or optimistically updated cache immediately to avoid a ddcutil round trip.
                if (SystemStatus.brightnessByScreen[batRoot.screenName] !== undefined) return
                // On a cache miss, read the internal backlight immediately or defer the slower external query.
                if (SystemStatus.brightnessBackendFor(batRoot.screenName) === "brightnessctl") {
                    SystemStatus.fetchBrightnessFor(batRoot.screenName)
                } else {
                    ddcutilFetchDelay.start()
                }
            }
            Timer {
                id: ddcutilFetchDelay
                interval: 500
                repeat: false
                onTriggered: {
                    if (batRoot.screenName) SystemStatus.fetchBrightnessFor(batRoot.screenName)
                }
            }

            readonly property bool lowBattery: SystemStatus.batteryPercent >= 0
                                              && SystemStatus.batteryPercent <= 15
                                              && !SystemStatus.batteryCharging

            // Show battery icon, percentage and status on a primary_container card.
            Rectangle {
                id: batCard
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: batRoot.lowBattery ? Theme.colors.error_container : Theme.colors.primary_container

                Text {
                    id: batCardIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: SystemStatus.batteryCharging ? "battery_charging_full"
                          : SystemStatus.batteryPercent >= 95 ? "battery_full"
                          : SystemStatus.batteryPercent <= 15 ? "battery_alert"
                          : "battery_5_bar"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 26
                    color: batRoot.lowBattery ? Theme.colors.on_error_container : Theme.colors.on_primary_container
                }
                Text {
                    id: batPctText
                    anchors {
                        left: batCardIcon.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.batteryPercent >= 0 ? `${SystemStatus.batteryPercent}%` : "—"
                    color: batRoot.lowBattery ? Theme.colors.on_error_container : Theme.colors.on_primary_container
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 18
                    font.styleName: "Bold"
                }
                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.batteryCharging ? "charging" : SystemStatus.batteryStatus.toLowerCase()
                    color: batRoot.lowBattery ? Theme.colors.on_error_container : Theme.colors.on_primary_container
                    opacity: 0.7
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                }
            }

            // Adjust only this output using brightnessctl internally or ddcutil externally.
            Rectangle {
                id: brightCard
                anchors {
                    top: batCard.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 56
                radius: 16
                color: Theme.colors.surface_container

                Text {
                    id: brightIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: batRoot.currentBrightnessPct < 34 ? "brightness_low"
                          : batRoot.currentBrightnessPct < 67 ? "brightness_medium"
                          : "brightness_high"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 24
                    color: Theme.colors.primary
                }

                SliderBar {
                    anchors {
                        left: brightIcon.right
                        leftMargin: 12
                        right: brightPctText.left
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    value: batRoot.currentBrightness
                    minValue: 0.05
                    onMoved: (v) => {
                        if (batRoot.screenName) SystemStatus.setBrightnessFor(batRoot.screenName, v)
                    }
                }

                Text {
                    id: brightPctText
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: `${batRoot.currentBrightnessPct}%`
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 14
                    font.styleName: "Bold"
                }
            }
        }
    }

    // ==================== Central dashboard and its four tabs ====================
    // Tab order: media, dashboard, weather, control
    // Mark the active tab with primary text and a sliding underline.
    // Each tab supplies its own content component.
    Component {
        id: dashboardComp
        Item {
            id: dashRoot

            // PopupManager preserves the selected tab when the Loader is recreated.
            // PopupManager initially selects dashboard.
            readonly property string currentTab: PopupManager.dashboardTab
            property bool animateTabChange: false
            readonly property bool dashboardOpen: PopupManager.currentPopup === "dashboard"
            onDashboardOpenChanged: {
                if (!dashboardOpen) {
                    animateTabChange = false
                    underlineSlide.complete()
                    underlineResize.complete()
                }
            }

            readonly property var tabs: [
                { key: "media",     label: "Media",     icon: "music_note" },
                { key: "dashboard", label: "Dashboard", icon: "dashboard" },
                { key: "weather",   label: "Weather",   icon: "partly_cloudy_day" },
                { key: "control",   label: "Control",   icon: "tune" }
            ]

            // ============ Tab bar ============
            Item {
                id: tabBar
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 44

                // Center a Row with one repeated item per tab.
                // Use a single underline rectangle shared by all tabs.
                // Animate its x position and width between labels.
                // Divide the width evenly and center each label within its item.
                Row {
                    id: tabRow
                    anchors.fill: parent

                    Repeater {
                        id: tabRepeater
                        model: dashRoot.tabs

                        delegate: Item {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool isActive: dashRoot.currentTab === tab.modelData.key
                            // Expose the label width to size the underline to the text.
                            readonly property real labelWidth: tabLabel.implicitWidth

                            width: tabRow.width / tabRepeater.count
                            height: tabBar.height

                            Row {
                                id: tabLabel
                                anchors.centerIn: parent
                                spacing: 6
                                readonly property color tint: tab.isActive ? Theme.colors.primary : Theme.colors.on_surface_variant

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    color: tabLabel.tint
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 18
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tabLabel.tint
                                    font.family: "Maple Mono NF CN"
                                    font.pixelSize: 16
                                    font.styleName: tab.isActive ? "ExtraBold" : "Medium"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (tab.isActive) return
                                    dashRoot.animateTabChange = true
                                    PopupManager.dashboardTab = tab.modelData.key
                                }
                            }
                        }
                    }
                }

                // Center the underline on the active label and match its width.
                Rectangle {
                    id: underline
                    readonly property Item activeTab: {
                        for (let i = 0; i < tabRepeater.count; i++) {
                            const t = tabRepeater.itemAt(i)
                            if (t && t.isActive) return t
                        }
                        return null
                    }
                    readonly property real targetX: underline.activeTab
                        ? tabRow.x + underline.activeTab.x
                            + (underline.activeTab.width - underline.activeTab.labelWidth) / 2 - 6
                        : 0
                    readonly property real targetW: underline.activeTab
                        ? underline.activeTab.labelWidth + 12
                        : 0

                    x: underline.targetX
                    width: underline.targetW
                    height: 2
                    radius: 1
                    color: Theme.colors.primary
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    visible: underline.activeTab !== null

                    Behavior on x {
                        enabled: dashRoot.animateTabChange
                        NumberAnimation {
                            id: underlineSlide
                            duration: 280
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                    Behavior on width {
                        enabled: dashRoot.animateTabChange
                        NumberAnimation {
                            id: underlineResize
                            duration: 280
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                }
            }

            // ============ Content ============
            // The Loader selects a component by currentTab.
            // Use placeholderComp for tabs without an implementation.
            Loader {
                id: contentLoader
                anchors {
                    top: tabBar.bottom
                    topMargin: 16
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                sourceComponent: {
                    switch (dashRoot.currentTab) {
                    case "media": return mediaTabComp
                    case "dashboard": return dashboardTabComp
                    case "weather": return weatherTabComp
                    case "control": return controlTabComp
                    default: return placeholderComp
                    }
                }
            }

            Component {
                id: mediaTabComp
                MediaTab {}
            }

            Component {
                id: dashboardTabComp
                DashboardTab {}
            }

            Component {
                id: weatherTabComp
                WeatherTab {}
            }

            Component {
                id: controlTabComp
                ControlTab {}
            }

            // Placeholder for unimplemented tabs
            Component {
                id: placeholderComp
                Item {
                    id: phRoot
                    readonly property var activeTabData: dashRoot.tabs.find(t => t.key === dashRoot.currentTab) || null

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: phRoot.activeTabData ? phRoot.activeTabData.icon : "dashboard"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 72
                            color: Theme.colors.on_surface_variant
                            opacity: 0.45
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: phRoot.activeTabData
                                ? `${phRoot.activeTabData.label} — coming soon`
                                : ""
                            color: Theme.colors.on_surface_variant
                            opacity: 0.6
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 13
                            font.styleName: "Medium"
                        }
                    }
                }
            }
        }
    }

    // =================== System Tray ===================
    // List StatusNotifierItems such as Clash Verge and Fcitx5.
    // Left click activates, right click opens the application menu, and middle click invokes the secondary action.
    Component {
        id: trayComp
        Controls.StackView {
            id: trayStack
            readonly property real pageHeight: currentItem?.preferredPageHeight ?? 0
            initialItem: trayItems
            Keys.onEscapePressed: {
                if (depth > 1) pop()
                else PopupManager.close()
            }

            function openMenu(handle: QsMenuHandle, title: string): void {
                push(menuPage, { handle: handle, title: title })
                forceActiveFocus()
            }

            Component {
                id: menuPage
                Item {
                    id: page
                    required property QsMenuHandle handle
                    required property string title
                    readonly property real preferredPageHeight: back.height + 4
                        + opener.children.values.reduce((h, entry) => h + (entry.isSeparator ? 9 : 36), 0)
                    onHandleChanged: {
                        if (!handle && Controls.StackView.status === Controls.StackView.Active)
                            trayStack.pop(null)
                    }
                    QsMenuOpener { id: opener; menu: page.handle }
                    PanelAction {
                        id: back
                        width: parent.width
                        symbol: "arrow_back"
                        text: page.title
                        Accessible.name: "Back — " + page.title
                        onClicked: trayStack.pop()
                    }
                    ListView {
                        anchors { top: back.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
                        clip: true
                        model: opener.children
                        delegate: Item {
                            id: menuRow
                            required property QsMenuEntry modelData
                            width: ListView.view.width
                            height: modelData.isSeparator ? 9 : 36
                            Rectangle {
                                visible: menuRow.modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 24
                                height: 1
                                color: Theme.colors.outline_variant
                            }
                            PanelAction {
                                anchors.fill: parent
                                visible: !menuRow.modelData.isSeparator
                                enabled: menuRow.modelData.enabled
                                filled: false
                                text: menuRow.modelData.text
                                imageUrl: menuRow.modelData.icon
                                symbol: {
                                    const entry = menuRow.modelData
                                    if (entry.buttonType === QsMenuButtonType.RadioButton)
                                        return entry.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked"
                                    if (entry.buttonType === QsMenuButtonType.CheckBox)
                                        return entry.checkState === Qt.Checked ? "check_box"
                                             : entry.checkState === Qt.PartiallyChecked ? "indeterminate_check_box"
                                             : "check_box_outline_blank"
                                    return ""
                                }
                                trailingSymbol: menuRow.modelData.hasChildren ? "chevron_right" : ""
                                onClicked: {
                                    if (menuRow.modelData.hasChildren)
                                        trayStack.openMenu(menuRow.modelData, menuRow.modelData.text)
                                    else {
                                        menuRow.modelData.triggered()
                                        PopupManager.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: trayItems
                ListView {
                    readonly property real preferredPageHeight: count * 40 + Math.max(0, count - 1) * spacing
                    clip: true
                    spacing: 4
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: trayRow
                        required property SystemTrayItem modelData
                        width: ListView.view.width
                        height: 40
                        radius: 10
                        color: trayHover.containsMouse ? Theme.colors.surface_container_high : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 12

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                source: trayRow.modelData.icon
                                sourceSize.width: 22
                                sourceSize.height: 22
                                width: 22
                                height: 22
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: trayRow.modelData.title || trayRow.modelData.id
                                color: Theme.colors.on_surface
                                font.family: "Maple Mono NF CN"
                                font.pixelSize: 13
                                font.styleName: "Bold"
                                elide: Text.ElideRight
                                width: trayRow.width - 24 - 22 - 12
                            }
                        }

                        MouseArea {
                            id: trayHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                const item = trayRow.modelData
                                if (item.hasMenu && (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && item.onlyMenu))) {
                                    trayStack.openMenu(item.menu, item.title || item.id)
                                    return
                                }
                                if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                                    trayRow.modelData.secondaryActivate()
                                } else {
                                    trayRow.modelData.activate()
                                }
                                PopupManager.close()
                            }
                            onWheel: (event) => {
                                trayRow.modelData.scroll(event.angleDelta.y, false)
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
