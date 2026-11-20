pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var commands: [
        { name: "/help", detail: "Show available commands" },
        { name: "/resume", detail: "Choose a conversation or enter its ID" },
        { name: "/new", detail: "Start a conversation" },
        { name: "/rename", detail: "Rename this conversation", argument: "title" },
        { name: "/fork", detail: "Fork this conversation" },
        { name: "/compact", detail: "Compact the conversation context" },
        { name: "/archive", detail: "Archive this conversation" },
        { name: "/model", detail: "Choose a model for new messages" },
        { name: "/permissions", detail: "Choose a permission profile" },
        { name: "/effort", detail: "Set reasoning effort" },
        { name: "/skills", detail: "List skills available in your home directory" },
        { name: "/mcp", detail: "List MCP servers" },
        { name: "/status", detail: "Show conversation, model, and account details" },
        { name: "/stop", detail: "Stop the current response" }
    ]
    property string page: ""
    property var rows: []
    property string cursor: ""
    property bool loading: false
    property int generation: 0
    property bool archived: false
    property string query: ""
    property string statusText: ""
    readonly property bool canManage: LocalCodex.ready && !LocalCodex.busy && !LocalCodex.managing

    Connections {
        target: LocalCodex
        function onReadyChanged() { if (!LocalCodex.ready) root.close() }
    }
    function close(): void {
        generation++
        page = ""
        rows = []
        loading = false
        cursor = ""
    }
    function open(name): void {
        close()
        page = name
    }
    function history(showArchived, term): void {
        open("history")
        archived = showArchived
        query = term
        fetchPage()
    }
    function models(wanted): void {
        open("models")
        rows = [{ key: "", title: "Use conversation default", detail: "" }]
        fetchPage(wanted)
    }
    function fetchPage(wanted): void {
        if (loading || !LocalCodex.ready) return
        const version = generation
        const mode = page
        const params = { limit: 40, cursor: cursor || undefined }
        let method
        switch (mode) {
        case "history":
            method = "thread/list"
            Object.assign(params, { cwd: LocalCodex.workspace, archived, searchTerm: query || undefined,
                sortKey: "updated_at", sourceKinds: ["appServer", "cli", "vscode", "exec", "unknown"] })
            break
        case "permissions": method = "permissionProfile/list"; params.cwd = LocalCodex.workspace; break
        case "mcp": method = "mcpServerStatus/list"; break
        case "skills": method = "skills/list"; break
        case "effort":
        case "models": method = "model/list"; break
        default: return
        }
        loading = true
        LocalCodex.request(method, mode === "skills" ? { cwds: [LocalCodex.workspace] } : params, (result, err) => {
            if (version !== generation) return
            loading = false
            if (err) { LocalCodex.errorText = err.message; return }
            cursor = result.nextCursor || ""
            let entries
            switch (mode) {
            case "history":
                entries = result.data.map(r => ({ key: r.id, title: r.name || r.preview || r.id,
                    detail: Qt.formatDateTime(new Date(r.updatedAt * 1000), "yyyy-MM-dd hh:mm") }))
                break
            case "permissions":
                entries = result.data.filter(r => r.allowed).map(r => ({
                    key: r.id, title: r.id, detail: r.description || "" }))
                break
            case "effort": {
                const model = result.data.find(r => LocalCodex.selectedModel ? r.model === LocalCodex.selectedModel : r.isDefault)
                if (!model && cursor) { fetchPage(wanted); return }
                cursor = ""
                if (!model) { LocalCodex.errorText = "No reasoning options are available for this model."; return }
                entries = model.supportedReasoningEfforts.map(r => ({ key: r.reasoningEffort,
                    title: r.reasoningEffort, detail: "", model: model.model }))
                break
            }
            case "skills":
                entries = (result.data[0]?.skills || []).filter(r => r.enabled).map(r => ({
                    key: r.path, title: r.name, detail: r.shortDescription || r.description || "" }))
                break
            case "mcp":
                entries = result.data.map(r => ({ key: r.name, title: r.name, detail: r.authStatus || "" }))
                break
            default:
                entries = result.data.map(r => ({ key: r.model, title: r.displayName || r.model, detail: r.model,
                    defaultEffort: r.defaultReasoningEffort }))
            }
            const seen = new Set(rows.map(row => row.key))
            rows = rows.concat(entries.filter(row => !seen.has(row.key)))
            if (wanted) {
                const match = rows.find(row => row.key === wanted || (mode === "permissions" && row.key === ":" + wanted))
                if (match) pick(match)
                else if (cursor) fetchPage(wanted)
                else LocalCodex.errorText = "Option unavailable: " + wanted
            }
        })
    }
    function manage(method, params, done): void {
        if (!canManage) return
        LocalCodex.managing = true
        LocalCodex.errorText = ""
        LocalCodex.request(method, params, (result, err) => {
            LocalCodex.managing = false
            if (err) { LocalCodex.errorText = err.message; return }
            done(result)
        })
    }
    function resume(id): void {
        if (id === LocalCodex.threadId) { close(); return }
        // Keep the original thread and bookmark until the requested thread loads.
        manage("thread/read", { threadId: id }, result => {
            if (result.thread.cwd !== LocalCodex.workspace) {
                LocalCodex.errorText = "This conversation uses a different working directory."
                return
            }
            manage("thread/resume", Object.assign(LocalCodex.threadParams(":workspace"), { threadId: id }), res => {
                LocalCodex.useThread(res)
                close()
            })
        })
    }
    function pick(row): void {
        if (!canManage) return
        if (page === "history") {
            if (archived) manage("thread/unarchive", { threadId: row.key }, () => resume(row.key))
            else resume(row.key)
        } else if (page === "models") {
            if (row.key !== LocalCodex.selectedModel) {
                LocalCodex.effort = row.defaultEffort || ""
                LocalCodex.effortModel = row.key
            }
            LocalCodex.chooseModel(row.key)
            close()
        } else if (page === "permissions" || page === "effort") {
            const permission = page === "permissions"
            function apply() {
                if (permission) LocalCodex.permissionProfile = row.key
                else { LocalCodex.effort = row.key; LocalCodex.effortModel = row.model }
                close()
            }
            if (!LocalCodex.threadId) { apply(); return }
            const params = { threadId: LocalCodex.threadId }
            if (permission) params.permissions = row.key
            else { params.model = row.model; params.effort = row.key }
            manage("thread/settings/update", params, apply)
        }
    }
    function status(): void {
        open("status")
        const version = generation
        const details = ["Working directory  " + LocalCodex.workspace,
            "Conversation  " + (LocalCodex.threadId || "New conversation"),
            "Model  " + (LocalCodex.selectedModel || "Codex default"),
            "Permissions  " + LocalCodex.permissionProfile, "Reasoning effort  " +
                ((LocalCodex.effortModel === LocalCodex.selectedModel && LocalCodex.effort) || LocalCodex.configuredEffort || "Model default"), "Approval  on-request"]
        statusText = details.join("\n")
        LocalCodex.request("account/read", {}, (result, err) => {
            if (version !== generation) return
            const account = result?.account
            statusText += "\nAccount  " + (err ? err.message : !account ? "Signed out"
                    : [account.type, account.planType].filter(Boolean).join(" · "))
        })
    }
    function isCommand(text): bool {
        return /^\s*\/(?:[a-z][\w-]*)?(?:\s|$)/i.test(text)
    }
    function submit(): void {
        const text = LocalCodex.draft.trim()
        if (!text) return
        if (!isCommand(text)) {
            if (!canManage) return
            close()
            if (text.startsWith("//")) LocalCodex.draft = text.slice(1)
            LocalCodex.send()
            return
        }
        const parts = /^(\S+)\s*([\s\S]*)$/.exec(text)
        const cmd = parts[1] === "/" ? "/help" : parts[1], arg = parts[2].trim()
        LocalCodex.errorText = ""
        if (!commands.some(c => c.name === cmd)) {
            LocalCodex.errorText = "Unknown command. Type /help to see commands or // to send a literal slash."
            return
        }
        if (!canManage && !["/stop", "/status", "/help"].includes(cmd)) {
            LocalCodex.errorText = "Wait for the current operation to finish."
            return
        }
        const id = LocalCodex.threadId
        if (!id && ["/rename", "/fork", "/archive", "/compact"].includes(cmd)) {
            LocalCodex.errorText = "Start or open a conversation first."
            return
        }
        if (cmd === "/rename" && !arg) {
            LocalCodex.draft = "/rename "
            LocalCodex.errorText = "Enter a new conversation title."
            return
        }
        if (arg && !["/rename", "/resume", "/model", "/permissions", "/effort"].includes(cmd)) {
            LocalCodex.errorText = cmd + " takes no arguments."
            return
        }
        LocalCodex.draft = ""
        switch (cmd) {
        case "/new": close(); LocalCodex.newChat(); break
        case "/help": open("help"); break
        case "/status": status(); break
        case "/stop":
            close()
            if (LocalCodex.busy) LocalCodex.interrupt()
            else LocalCodex.activity = "No response in progress"
            break
        case "/resume": if (arg) resume(arg); else history(false, ""); break
        case "/rename":
            manage("thread/name/set", { threadId: id, name: arg }, () => { LocalCodex.threadTitle = arg; close() })
            break
        case "/fork":
            manage("thread/fork", Object.assign(LocalCodex.threadParams(), { threadId: id }), res => {
                LocalCodex.useThread(res); close()
            })
            break
        case "/compact":
            close()
            manage("thread/compact/start", { threadId: id }, () => {})
            break
        case "/archive":
            manage("thread/archive", { threadId: id }, () => { LocalCodex.newChat(); history(false, "") })
            break
        case "/skills":
        case "/mcp":
        case "/permissions":
        case "/effort":
            open(cmd.slice(1))
            fetchPage(arg)
            break
        case "/model":
            models(arg)
            break
        }
    }
}
