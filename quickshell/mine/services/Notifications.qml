pragma Singleton
pragma ComponentBehavior: Bound

// Desktop notification server and history
//
// Bridge Quickshell.Services.Notifications.NotificationServer:
//   - Own org.freedesktop.Notifications on D-Bus to receive desktop notifications.
//   - Snapshot incoming notifications so history survives expiration and closure.
//   - The dashboard reads history and can dismiss one entry or clear the list.
//
// Snapshots keep history independent of live Notification objects:
//   - Some fields become invalid after close.
//   - History has its own lifetime.
//
// keepOnReload=false clears live notifications on reload to avoid duplicates.

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // History, newest first
    property var history: []
    readonly property int count: root.history.length

    // Expanded card ID (-1 for none). Click a notification to toggle its body.
    property int expandedId: -1
    function toggleExpand(id: int): void {
        root.expandedId = (root.expandedId === id) ? -1 : id
    }

    // Drop the oldest entry when the limit is exceeded.
    readonly property int maxHistory: 50

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            n.tracked = true
            const snap = {
                id: n.id,
                time: new Date(),
                appName: n.appName || "Unknown",
                appIcon: n.appIcon || "",
                summary: n.summary || "",
                body: n.body || "",
                image: n.image || "",
                urgency: n.urgency,
            }
            const next = root.history.slice()
            next.unshift(snap)
            if (next.length > root.maxHistory) next.length = root.maxHistory
            root.history = next
        }
    }

    function dismiss(id: int): void {
        root.history = root.history.filter(h => h.id !== id)
    }

    function clearAll(): void {
        root.history = []
    }

    function formatTime(d: var): string {
        if (!d) return ""
        const now = new Date()
        const diffMs = now.getTime() - d.getTime()
        const diffMin = Math.floor(diffMs / 60000)
        if (diffMin < 1) return "now"
        if (diffMin < 60) return diffMin + "m"
        const diffHr = Math.floor(diffMin / 60)
        if (diffHr < 24) return diffHr + "h"
        const diffDay = Math.floor(diffHr / 24)
        if (diffDay < 7) return diffDay + "d"
        return Qt.formatDateTime(d, "MM-dd")
    }
}
