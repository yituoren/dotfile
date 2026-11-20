pragma Singleton
pragma ComponentBehavior: Bound

// Taskwarrior interface
//
// Read the complete task export as JSON, then filter and group by date in JavaScript.
// Refresh every five seconds and immediately after writes.
// Use the task CLI to add, complete, undo or remove a task.
//
// Taskwarrior due dates use YYYYMMDDTHHMMSSZ in UTC.
// Convert them to JavaScript Dates and compare calendar days in the local time zone.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var pending: []   // Snapshot of all pending tasks
    property var completed: [] // Recently completed tasks for the optional completion count
    readonly property bool ready: root.pending !== null

    function parseTwDate(s: string): var {
        if (!s || s.length < 15) return null
        // YYYYMMDDTHHMMSSZ
        const y = parseInt(s.substring(0, 4), 10)
        const mo = parseInt(s.substring(4, 6), 10) - 1
        const d = parseInt(s.substring(6, 8), 10)
        const h = parseInt(s.substring(9, 11), 10)
        const mi = parseInt(s.substring(11, 13), 10)
        const se = parseInt(s.substring(13, 15), 10)
        return new Date(Date.UTC(y, mo, d, h, mi, se))
    }

    function sameDay(a: var, b: var): bool {
        if (!a || !b) return false
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    function tasksOn(date: var): var {
        if (!date) return []
        return root.pending.filter(t => {
            const due = root.parseTwDate(t.due)
            return root.sameDay(due, date)
        }).sort((a, b) => (b.urgency ?? 0) - (a.urgency ?? 0))
    }

    function tasksWithoutDate(): var {
        return root.pending.filter(t => !t.due).sort((a, b) => (b.urgency ?? 0) - (a.urgency ?? 0))
    }

    function countOn(date: var): int {
        return root.tasksOn(date).length
    }

    Process {
        id: exportProc
        command: ["task", "rc.confirmation:no", "export"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(this.text || "[]")
                    root.pending = all.filter(t => t.status === "pending")
                    root.completed = all.filter(t => t.status === "completed")
                } catch (e) {
                    console.warn("Tasks: parse failed", e)
                }
            }
        }
    }

    function refresh(): void {
        if (exportProc.running) return
        exportProc.running = true
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // ============ Write operations ============
    // Use task rc.confirmation:no so commands never block on stdin.

    Process {
        id: writeProc
        onExited: root.refresh()
    }

    function mutate(args: var): void {
        if (writeProc.running) return
        writeProc.command = ["task", "rc.confirmation:no"].concat(args)
        writeProc.running = true
    }

    function add(description: string, dueIso: string): void {
        if (!description || !description.trim()) return
        const args = ["add", description]
        if (dueIso) args.push("due:" + dueIso)
        root.mutate(args)
    }

    function markDone(uuid: string): void {
        if (!uuid) return
        root.mutate([uuid, "done"])
    }

    function remove(uuid: string): void {
        if (!uuid) return
        root.mutate([uuid, "delete"])
    }
}
