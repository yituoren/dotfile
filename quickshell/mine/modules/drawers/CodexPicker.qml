pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.bar.widgets

ColumnLayout {
    id: root
    required property bool completing
    signal returnToEditor()
    signal commandChosen(string name, bool execute)
    readonly property string mode: completing ? "commands" : CodexCommands.page
    readonly property bool commands: completing || mode === "help"
    readonly property var entries: commands
        ? CodexCommands.commands.filter(c => !completing || c.name.startsWith(LocalCodex.draft.trim()))
        : CodexCommands.rows
    readonly property bool infoOnly: mode === "skills" || mode === "mcp"
    readonly property string selectedKey: mode === "history" ? LocalCodex.threadId
        : mode === "models" ? LocalCodex.modelOverride : mode === "permissions" ? LocalCodex.permissionProfile
        : mode === "effort" ? ((LocalCodex.effortModel === LocalCodex.selectedModel && LocalCodex.effort) || LocalCodex.configuredEffort) : ""
    function choose(row, execute): void {
        if (!row) return
        if (commands) commandChosen(row.name, execute)
        else if (!infoOnly && CodexCommands.canManage) {
            returnToEditor()
            CodexCommands.pick(row)
        }
    }
    function dismiss(): void {
        if (completing) LocalCodex.draft = ""
        CodexCommands.close()
        returnToEditor()
    }
    function focusSearch(): void { filter.forceActiveFocus() }

    // Called by both text inputs so arrows move the highlight without moving focus.
    function handleKey(event): bool {
        if (!visible || event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return false
        if (event.key === Qt.Key_Escape) { dismiss(); return true }
        if (!filter.activeFocus && !completing && LocalCodex.draft.length > 0) return false
        if (debounce.running && filter.activeFocus) return false
        const count = entries.length
        if (!count || mode === "status") return false
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Down: {
            const step = event.key === Qt.Key_Down ? 1 : -1
            choices.currentIndex = (choices.currentIndex + step + count) % count
            choices.positionViewAtIndex(choices.currentIndex, ListView.Contain)
            return true
        }
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!event.isAutoRepeat && LocalCodex.ready) choose(entries[choices.currentIndex], true)
            return true
        case Qt.Key_Tab:
            if (!completing) return false
            choose(entries[choices.currentIndex], false)
            return true
        default: return false
        }
    }
    spacing: 6
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.commands ? "Slash commands" : root.mode === "models" ? "Select a model"
                  : root.mode === "status" ? "Status" : root.mode === "permissions" ? "Conversation permissions"
                  : root.mode === "effort" ? "Reasoning effort" : root.mode === "skills" ? "Skills"
                  : root.mode === "mcp" ? "MCP" : "Conversations"
            elide: Text.ElideRight
            color: Theme.colors.primary
            font.family: "Maple Mono NF CN"; font.styleName: "Bold"; font.pixelSize: 14
        }
        PanelAction {
            visible: root.mode === "history"
            text: CodexCommands.archived ? "Back to history" : "Archived"
            onClicked: CodexCommands.history(!CodexCommands.archived, filter.text.trim())
        }
        ChatToolButton {
            text: "Close"; width: 30; height: 30
            contentItem: Text {
                text: "close"; font.family: "Material Symbols Rounded"; font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                color: Theme.colors.on_surface_variant
            }
            onClicked: root.dismiss()
        }
    }
    TextField {
        id: filter
        Layout.fillWidth: true
        visible: root.mode === "history"
        text: CodexCommands.query
        placeholderText: "Search conversations"
        color: Theme.colors.on_surface
        placeholderTextColor: Theme.colors.on_surface_variant
        background: Rectangle { radius: 8; color: Theme.colors.surface_container_high }
        Keys.onPressed: event => { event.accepted = !inputMethodComposing && root.handleKey(event) }
        onTextEdited: debounce.restart()
        Timer {
            id: debounce
            interval: 220
            onTriggered: if (root.mode === "history") CodexCommands.history(CodexCommands.archived, filter.text.trim())
        }
    }
    TextEdit {
        visible: root.mode === "status"
        Layout.fillWidth: true
        readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
        text: CodexCommands.statusText; textFormat: TextEdit.PlainText
        color: Theme.colors.on_surface; font.family: "Maple Mono NF CN"; font.pixelSize: 13
    }
    ListView {
        id: choices
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        spacing: 3
        model: root.mode === "status" ? [] : root.entries
        onModelChanged: {
            const selected = root.commands ? 0 : root.entries.findIndex(row => row.key === root.selectedKey)
            currentIndex = root.entries.length ? Math.max(0, selected) : -1
        }
        ScrollBar.vertical: ScrollBar {}
        delegate: AbstractButton {
            id: choice
            required property int index
            required property var modelData
            width: choices.width - 8
            height: root.commands || modelData.detail ? 48 : 34
            leftPadding: 10; rightPadding: 10
            hoverEnabled: true
            enabled: !root.infoOnly && (root.commands || CodexCommands.canManage)
            Accessible.name: modelData.name || modelData.title || ""
            background: Rectangle {
                radius: 9
                color: choice.ListView.isCurrentItem ? Theme.colors.secondary_container
                     : choice.hovered || choice.visualFocus
                       ? Theme.colors.surface_container_high : Theme.colors.surface_container
            }
            contentItem: Item {
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                        text: choice.modelData.name ? choice.modelData.name + (choice.modelData.argument ? " " + choice.modelData.argument : "")
                              : (root.mode === "history" && CodexCommands.archived ? "Restore · " : "") + (choice.modelData.title || "")
                        color: !root.commands && choice.modelData.key === root.selectedKey
                               ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"; font.pixelSize: 13
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                        text: choice.modelData.detail; visible: text.length > 0
                        color: Theme.colors.on_surface_variant; font.pixelSize: 12
                    }
                }
            }
            onClicked: root.choose(modelData, true)
        }
        footer: PanelAction {
            visible: !root.commands && !!CodexCommands.cursor
            height: visible ? 34 : 0
            enabled: !CodexCommands.loading
            text: "Load more"
            onClicked: CodexCommands.fetchPage()
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.mode !== "status" && (CodexCommands.loading || !root.entries.length)
        text: CodexCommands.loading ? "Loading…" : root.commands ? "No matching commands" : "No matches"
        color: Theme.colors.on_surface_variant; font.pixelSize: 12
    }
}
