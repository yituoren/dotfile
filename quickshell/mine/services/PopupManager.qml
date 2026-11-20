pragma Singleton
pragma ComponentBehavior: Bound

// Global popup state
//
import QtQuick
import Quickshell

Singleton {
    id: root

    // ============ State ============
    property string currentPopup: ""
    property var currentScreen: null
    property real anchorX: 0

    readonly property var registry: ({
        "power":     { width: 280, height: 280 },
        "wifi":      { width: 320, height: 440 },
        "bluetooth": { width: 320, height: 440 },
        "volume":    { width: 320, height: 154 },
        "battery":   { width: 320, height: 154 },
        "tray":      { width: 320, height: 280 },
        // Dashboard height follows the output and its bottom sits near the screen midpoint.
        // Starting at scaleFrom=0.8 combines a short opening motion with the content fade.
        "dashboard": {
            width: 880,
            duration: 240,
            heightFn: (s) => Math.min(600, Math.round((s ? s.height : 1440) * 0.48)),
            scaleFrom: 0.85,
            // Use a gradient and local background blur.
            transparent: true
        }
    })

    // Keep the whole popup within the output on narrow screens.
    function popupScaleFor(entry: var, screen: var): real {
        if (!screen || !entry) return Theme.uiScale
        const height = entry.heightFn ? entry.heightFn(screen) : entry.height
        return Math.min(Theme.uiScale, (screen.width - 24) / entry.width,
                        (screen.height - 76) / height)
    }

    readonly property var entry: root.registry[root.currentPopup] ?? null
    readonly property bool isOpen: root.entry !== null
    property var lastEntry: null

    // Adopt the new entry's duration when switching and keep it for the close animation.
    property int activeDuration: 320

    // Remember the selected dashboard tab across openings. Start on dashboard.
    property string dashboardTab: "dashboard"

    // Ignore dismissal clicks during transitions so a hover-triggered popup can finish opening.
    property bool openInProgress: false
    Timer {
        id: openInProgressTimer
        interval: root.activeDuration + 30
        repeat: false
        onTriggered: root.openInProgress = false
    }
    onCurrentPopupChanged: {
        if (root.currentPopup !== "") {
            root.openInProgress = true
            openInProgressTimer.restart()
        }
    }

    // ============ Animated popup dimensions ============
    property real displayWidth: lastEntry?.width ?? 0
    property real displayHeight: lastEntry?.heightFn ? lastEntry.heightFn(currentScreen) : (lastEntry?.height ?? 0)
    Behavior on displayWidth {
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }
    Behavior on displayHeight {
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    // ============ Notch ============
    readonly property int dipMaxDepth: 16

    // ============ Open and close animation ============
    property real openAmount: 0
    Behavior on openAmount {
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    // ============ Extra height for dropdowns such as the output list ============
    // Popups request more space through extraHeight. Reset it when switching entries.
    property real extraHeight: 0
    Behavior on extraHeight {
        NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    // Center the dashboard and align right-hand menus with the bar edge. Animate between these anchors.
    property real alignment: 0
    Behavior on alignment {
        enabled: root.openAmount > 0
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    onEntryChanged: {
        if (root.entry) {
            root.lastEntry = root.entry
            // Use the new entry's duration for subsequent behaviors immediately.
            // Keep activeDuration when entry becomes null so closing uses the same speed.
            root.activeDuration = root.entry.duration ?? 320
            // Collapse internal dropdowns when opening or switching popups.
            root.extraHeight = 0

            root.alignment = root.currentPopup === "dashboard" ? 0 : 1
        }
        root.openAmount = root.entry ? 1 : 0
    }

    function open(popupKey: string, screen: var, screenLocalX: real): void {
        root.currentScreen = screen
        root.anchorX = screenLocalX
        root.currentPopup = popupKey
    }

    function close(): void {
        root.currentPopup = ""
    }

    function toggle(popupKey: string, screen: var, screenLocalX: real): void {
        if (root.currentPopup === popupKey) {
            root.close()
        } else {
            root.open(popupKey, screen, screenLocalX)
        }
    }

    function toggleAt(triggerItem: Item, popupKey: string, screen: var): void {
        if (!triggerItem || !screen) {
            console.warn("PopupManager.toggleAt: missing triggerItem or screen")
            return
        }
        const g = triggerItem.mapToGlobal(triggerItem.width / 2, 0)
        const localX = g.x - (screen.x ?? 0)
        root.toggle(popupKey, screen, localX)
    }
}
