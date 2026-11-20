pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string workspace: Quickshell.env("HOME")
    property string threadId: ""
    property string threadTitle: ""
    property string threadModel: ""
    property string olderCursor: ""
    property bool olderByTurn: false
    property bool loadingOlder: false
    property int historyGeneration: 0
    property string modelOverride: ""
    property string permissionProfile: ":workspace"
    property string effort: ""
    property string effortModel: ""
    property string configuredModel: ""
    property string configuredEffort: ""
    readonly property string selectedModel: modelOverride || threadModel || configuredModel
    property bool managing: false
    property var drafts: ({})
    property string turnId: ""
    property bool ready: false
    property bool connecting: false
    property bool busy: false
    property string draft: ""
    property string errorText: ""
    property string activity: ""
    property var approvals: []
    property var toolItems: ({})
    property var callbacks: ({})
    property int serial: 0
    readonly property ListModel messages: ListModel {}
    FileView {
        id: bookmark
        path: Quickshell.statePath("local-codex-thread")
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: preference
        path: Quickshell.statePath("local-codex-model")
        blockLoading: true
        printErrors: false
    }
    function chooseModel(model): void {
        modelOverride = model
        preference.setText(model)
    }
    function useThread(result): void {
        const thread = result.thread
        const previous = threadId
        if (previous !== thread.id) {
            drafts[previous] = draft
            draft = drafts[thread.id] ?? ""
            if (previous) request("thread/unsubscribe", { threadId: previous }, () => {})
        }
        threadId = thread.id
        bookmark.setText(thread.id)
        threadTitle = thread.name || thread.preview || ""
        threadModel = result.model || thread.model || ""
        permissionProfile = result.activePermissionProfile?.id || ":workspace"
        effort = result.reasoningEffort || ""
        effortModel = threadModel
        turnId = (thread.turns ?? []).find(t => t.status === "inProgress")?.id ?? ""
        busy = !!turnId
        activity = busy ? "Working…" : ""
        approvals = []
        toolItems = ({})
        resetHistory()
        olderByTurn = !result.itemsBackwardsCursor
        olderCursor = result.itemsBackwardsCursor || result.turnsBackwardsCursor || ""
        for (const turn of thread.turns ?? []) {
            for (const item of turn.items ?? []) {
                const row = historyRow(item)
                if (row) messages.append(row)
            }
        }
    }
    function write(packet): void { server.write(JSON.stringify(packet) + "\n") }
    function request(method, params, done): void {
        const id = ++serial
        callbacks[id] = done
        write({ id, method, params })
    }
    function activate(): void {
        if (server.running || connecting) return
        connecting = true
        errorText = ""
        startupTimeout.restart()
        server.running = true
    }
    function connected(): void {
        ready = true
        connecting = false
        startupTimeout.stop()
    }
    function add(who, body, itemId): void {
        messages.append({ who, body, itemId: itemId ?? "" })
    }
    function assistantText(id, text, append): void {
        // Commentary and the final response can be separate items in one turn.
        for (let i = messages.count - 1; i >= 0; --i) {
            const row = messages.get(i)
            if (row.who === "You") break
            if (row.itemId === id) {
                messages.setProperty(i, "body", append ? row.body + text : text)
                return
            }
        }
        if (text) add("Codex", text, id)
    }
    function resetHistory(): void {
        historyGeneration++
        olderCursor = ""
        loadingOlder = false
        messages.clear()
    }
    function historyRow(item): var {
        if (item.type === "userMessage")
            return { who: "You", body: item.content.filter(c => c.type === "text").map(c => c.text).join("\n"), itemId: item.id }
        if (item.type === "agentMessage" && item.text)
            return { who: "Codex", body: item.text, itemId: item.id }
        return null
    }
    function loadOlder(): void {
        if (!ready || !olderCursor || loadingOlder) return
        const generation = historyGeneration
        const params = { threadId, cursor: olderCursor, limit: olderByTurn ? 10 : 60, sortDirection: "desc" }
        if (olderByTurn) params.itemsView = "full"
        loadingOlder = true
        request(olderByTurn ? "thread/turns/list" : "thread/items/list", params, (result, err) => {
            if (generation !== historyGeneration) return
            loadingOlder = false
            if (err) { errorText = err.message; return }
            // Reverse pages include the boundary item. Keep one copy in chronological order.
            const seen = new Set()
            for (let i = 0; i < messages.count; i++) seen.add(messages.get(i).itemId)
            function prepend(item) {
                const row = historyRow(item)
                if (row && !seen.has(item.id)) {
                    seen.add(item.id)
                    messages.insert(0, row)
                }
            }
            for (const entry of result.data) {
                if (olderByTurn) {
                    for (let i = entry.items.length - 1; i >= 0; --i) prepend(entry.items[i])
                } else prepend(entry.item)
            }
            olderCursor = result.nextCursor || ""
        })
    }
    function threadParams(profile): var {
        return { cwd: workspace, permissions: profile || permissionProfile, approvalPolicy: "on-request" }
    }
    function initialize(): void {
        request("initialize", { clientInfo: { name: "mine_local", title: "Quickshell Local", version: "1" },
            capabilities: { experimentalApi: true } }, (result, err) => {
            if (err) { errorText = err.message; server.running = false; return }
            write({ method: "initialized" })
            request("config/read", { cwd: workspace }, (res, failure) => {
                if (failure) return
                configuredModel = res.config.model || ""
                configuredEffort = res.config.model_reasoning_effort || ""
            })
            modelOverride = preference.text().trim()
            threadId = bookmark.text().trim()
            if (!threadId) { connected(); return }
            request("thread/resume", Object.assign(threadParams(), { threadId }), (res, failure) => {
                if (failure) {
                    errorText = "Could not resume conversation: " + failure.message
                    threadId = ""
                    threadTitle = ""
                    threadModel = ""
                    resetHistory()
                    connected()
                    return
                }
                useThread(res)
                connected()
            })
        })
    }
    function newChat(): void {
        if (connecting || busy || managing) return
        if (ready && threadId) request("thread/unsubscribe", { threadId }, () => {})
        if (threadId) drafts[threadId] = draft
        bookmark.setText("")
        threadId = ""
        threadTitle = ""
        threadModel = ""
        permissionProfile = ":workspace"
        effort = ""
        effortModel = ""
        activity = ""
        resetHistory()
        draft = ""
        errorText = ""
        if (!ready) activate()
    }
    function send(): void {
        const text = draft.trim()
        if (!ready || busy || managing || !text) return
        busy = true
        errorText = ""
        activity = "Working…"
        draft = ""
        add("You", text)
        function failed(err) {
            errorText = err.message
            busy = false
            activity = ""
            if (!draft) draft = text
        }
        function startTurn() {
            request("turn/start", { threadId, model: modelOverride || threadModel || undefined,
                effort: effort && effortModel === selectedModel ? effort : undefined, input: [{ type: "text", text }] }, (res, err) => {
                if (err) { failed(err); return }
                if (busy) turnId = res.turn.id
            })
        }
        if (threadId) { startTurn(); return }
        request("thread/start", Object.assign(threadParams(), { model: modelOverride || undefined }), (res, err) => {
            if (err) { failed(err); return }
            threadId = res.thread.id
            threadTitle = res.thread.name || text
            threadModel = res.model
            bookmark.setText(threadId)
            startTurn()
        })
    }
    function interrupt(): void {
        if (!turnId) return
        request("turn/interrupt", { threadId, turnId }, (_, err) => { if (err) errorText = err.message })
    }
    function serverRequest(msg): void {
        const p = msg.params
        const method = msg.method
        if (p.threadId === threadId && ["item/commandExecution/requestApproval",
                "item/fileChange/requestApproval", "item/permissions/requestApproval"].includes(method)) {
            // Show the complete request before granting anything for this turn.
            const tool = toolItems[p.itemId]
            const details = Object.assign({}, p)
            if (method === "item/fileChange/requestApproval" && tool?.changes) details.changes = tool.changes
            if (method === "item/commandExecution/requestApproval" && !details.command) details.command = tool?.command
            approvals = [...approvals, { id: msg.id, method, params: details }]
        } else {
            write({ id: msg.id, error: { code: -32601, message: "Unsupported request: " + method } })
            errorText = "Unsupported in this panel: " + method
        }
    }
    function decide(allow): void {
        const req = approvals[0]
        if (!req) return
        const result = req.method === "item/permissions/requestApproval"
                ? { permissions: allow ? req.params.permissions : {}, scope: "turn" }
                : { decision: allow ? "accept" : "decline" }
        write({ id: req.id, result })
        approvals = approvals.slice(1)
    }
    function receive(line): void {
        let msg
        try { msg = JSON.parse(line) } catch (_) { return }
        if (msg.id !== undefined) {
            if (msg.method) { serverRequest(msg); return }
            const callback = callbacks[msg.id]
            delete callbacks[msg.id]
            if (callback) callback(msg.result, msg.error)
            return
        }
        const p = msg.params
        if (!threadId || p?.threadId !== threadId) return
        switch (msg.method) {
        case "thread/name/updated":
            threadTitle = p.threadName || ""
            break
        case "turn/started":
            busy = true
            turnId = p.turn.id
            break
        case "item/agentMessage/delta":
            assistantText(p.itemId, p.delta, true)
            break
        case "item/started":
            if (p.item.type === "commandExecution" || p.item.type === "fileChange") toolItems[p.item.id] = p.item
            if (p.item.type === "commandExecution") activity = "Running command…"
            if (p.item.type === "fileChange") activity = "Editing files…"
            break
        case "item/completed":
            delete toolItems[p.item.id]
            if (p.item.type === "agentMessage") assistantText(p.item.id, p.item.text, false)
            activity = "Working…"
            break
        case "serverRequest/resolved":
            approvals = approvals.filter(a => a.id !== p.requestId)
            break
        case "error":
            if (!p.willRetry) errorText = p.error.message
            break
        case "turn/completed":
            busy = false
            turnId = ""
            activity = ""
            approvals = []
            toolItems = ({})
            if (p.turn.error) errorText = p.turn.error.message
            if (p.turn.status === "interrupted") activity = "Stopped"
            break
        }
    }
    Timer {
        id: startupTimeout
        interval: 30000
        onTriggered: {
            root.errorText = "Connection timed out. Check that Codex is installed and signed in."
            root.connecting = false
            server.running = false
        }
    }
    Process {
        id: server
        command: ["codex", "app-server", "--listen", "stdio://"]
        workingDirectory: root.workspace
        stdinEnabled: true
        onStarted: root.initialize()
        stdout: SplitParser { onRead: line => root.receive(line) }
        onExited: {
            startupTimeout.stop()
            root.managing = false
            root.ready = false
            root.connecting = false
            root.busy = false
            root.turnId = ""
            root.approvals = []
            root.toolItems = ({})
            root.callbacks = ({})
            root.loadingOlder = false
            root.activity = ""
            if (!root.errorText) root.errorText = "Local Codex disconnected."
        }
    }
}
