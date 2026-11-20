pragma Singleton
pragma ComponentBehavior: Bound

// Shared clock
//
// One timer updates clocks, calendars and notification timestamps together.
// Consumers share the tick instead of starting individual timers.

import QtQuick
import Quickshell

Singleton {
    id: root

    // Current time as a JavaScript Date
    property date now: new Date()

    // Frequently used formatted strings
    readonly property string hhmm: Qt.formatDateTime(root.now, "HH:mm")
    readonly property string hhmmss: Qt.formatDateTime(root.now, "HH:mm:ss")
    readonly property string dateShort: Qt.formatDateTime(root.now, "MM-dd ddd")
    readonly property string dateLong: Qt.formatDateTime(root.now, "yyyy-MM-dd dddd")

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
