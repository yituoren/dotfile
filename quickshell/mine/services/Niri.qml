pragma Singleton
pragma ComponentBehavior: Bound

// niri adapter replacing ii's HyprlandData.qml
//
// Decode the persistent niri msg --json event-stream into observable properties.
// Track workspaces, windows, the focused window and the active workspace.
// Log unfamiliar events for inspection.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- Observable state ----
    property var workspaces: []          // [{id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}, ...]
    property var windows: []             // [{id, title, app_id, pid, workspace_id, is_focused, ...}, ...]
    property int focusedWindowId: -1
    property int activeWorkspaceId: -1
    property bool overviewOpen: false
    property bool configOk: true
    property bool ready: false           // Set after the first WorkspacesChanged snapshot.

    // ---- Persistent niri event stream ----
    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.handleLine(line)
        }
        // The process ends when niri exits and does not automatically reconnect.
        // An onExited retry could be added if compositor restarts need to be handled.
    }

    // ---- Event decoding ----
    function handleLine(line: string): void {
        if (!line || line.length === 0) return
        let event
        try {
            event = JSON.parse(line)
        } catch (e) {
            console.warn("Niri: invalid JSON:", line.slice(0, 200))
            return
        }
        const type = Object.keys(event)[0]
        const data = event[type]

        switch (type) {
            // ==== Initial snapshots ====
            case "WorkspacesChanged":
                root.workspaces = data.workspaces
                const focusedWs = data.workspaces.find(w => w.is_focused)
                if (focusedWs) root.activeWorkspaceId = focusedWs.id
                root.ready = true
                break

            case "WindowsChanged":
                root.windows = data.windows
                const focusedWin = data.windows.find(w => w.is_focused)
                root.focusedWindowId = focusedWin ? focusedWin.id : -1
                break

            // ==== Incremental events ====
            case "WorkspaceActivated":
                // Workspace activation payload: {id, focused}
                // When focused is true, the user switched focus and activeWorkspaceId changes.
                // Otherwise only the active workspace on that output changed.
                if (data.focused) root.activeWorkspaceId = data.id
                // Update is_active and is_focused in the workspace array.
                const target = root.workspaces.find(w => w.id === data.id)
                if (target) {
                    root.workspaces = root.workspaces.map(w => {
                        if (w.output !== target.output) return w
                        return Object.assign({}, w, {
                            is_active: w.id === data.id,
                            is_focused: w.id === data.id && data.focused ? true
                                       : data.focused ? false
                                       : w.is_focused,
                        })
                    })
                }
                break

            case "WindowFocusChanged":
                root.focusedWindowId = data.id ?? -1
                root.windows = root.windows.map(w =>
                    Object.assign({}, w, { is_focused: w.id === data.id })
                )
                break

            case "WindowOpenedOrChanged":
                // A window opened or changed properties such as its title or floating state.
                const w = data.window
                const idx = root.windows.findIndex(x => x.id === w.id)
                const next = root.windows.slice()
                if (idx >= 0) next[idx] = w
                else next.push(w)
                root.windows = next
                if (w.is_focused) root.focusedWindowId = w.id
                break

            case "WindowLayoutsChanged": {
                const layouts = new Map(data.changes)
                root.windows = root.windows.map(win => layouts.has(win.id)
                    ? Object.assign({}, win, { layout: layouts.get(win.id) }) : win)
                break
            }

            case "WindowClosed":
                root.windows = root.windows.filter(w => w.id !== data.id)
                if (root.focusedWindowId === data.id) root.focusedWindowId = -1
                break

            case "OverviewOpenedOrClosed":
                root.overviewOpen = data.is_open
                console.log("Niri: overview =", data.is_open)
                break

            case "ConfigLoaded":
                root.configOk = !data.failed
                break

            // Events reserved for future handling:
            case "WorkspaceActiveWindowChanged":
            case "WorkspaceUrgencyChanged":
            case "WindowUrgencyChanged":
            case "KeyboardLayoutsChanged":
            case "CastsChanged":
            case "WindowFocusTimestampChanged":  // Sent on each focus change. The bar and overview do not use this timestamp.
                // Ignore for now.
                break

            default:
                console.log("Niri: unhandled event:", type, JSON.stringify(data).slice(0, 200))
        }
    }

    function compareWindowPosition(a, b): real {
        const tileA = a.layout?.pos_in_scrolling_layout
        const tileB = b.layout?.pos_in_scrolling_layout
        if (tileA && tileB)
            return tileA[0] - tileB[0] || tileA[1] - tileB[1] || a.id - b.id
        if (tileA || tileB) return tileA ? -1 : 1

        // Floating windows have no column. Order them after the tiled group.
        const posA = a.layout?.tile_pos_in_workspace_view
        const posB = b.layout?.tile_pos_in_workspace_view
        if (posA && posB)
            return posA[0] - posB[0] || posA[1] - posB[1] || a.id - b.id
        if (posA || posB) return posA ? -1 : 1
        return a.id - b.id
    }

    // ---- Dispatch niri actions ----
    //
    // The focus-workspace action accepts an index or name. The event stream supplies an ID.
    // Resolve that ID against the local workspace list before dispatching.
    // Indices are unique on a single output. With multiple outputs, niri searches the current one.
    // Cross-output selection by ID is currently unsupported.
    function focusWorkspace(id: int): void {
        const ws = root.workspaces.find(w => w.id === id)
        if (!ws) {
            console.warn("Niri.focusWorkspace: id", id, "not found")
            return
        }
        dispatcher.command = ["niri", "msg", "action", "focus-workspace", String(ws.idx)]
        dispatcher.running = true
    }

    Process {
        id: dispatcher
        // Actions such as focusWorkspace set the command and set running to true once.
    }

    // ---- Log a state summary with qs ipc call niri dump ----
    IpcHandler {
        target: "niri"
        function dump(): void {
            console.log(`Niri: ws=${root.workspaces.length} wins=${root.windows.length} active_ws=${root.activeWorkspaceId} focused_win=${root.focusedWindowId} overview=${root.overviewOpen}`)
        }
    }
}
