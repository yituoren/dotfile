pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.bar.widgets

Rectangle {
    id: root
    color: Theme.colors.surface
    radius: 14
    readonly property bool completing: /^\/[a-z]*$/.test(LocalCodex.draft)
    readonly property bool commandInput: CodexCommands.isCommand(LocalCodex.draft)
    function submit(): void {
        transcript.follow = true
        CodexCommands.submit()
    }
    Component.onCompleted: LocalCodex.activate()

    Connections {
        target: LocalCodex
        function onThreadIdChanged() {
            transcript.follow = true
            Qt.callLater(transcript.scrollToLatest)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: LocalCodex.threadTitle || "Codex  ·  ~"
                textFormat: Text.PlainText; elide: Text.ElideRight; maximumLineCount: 1
                font.family: "Maple Mono NF CN"
                font.styleName: "Bold"
                font.pixelSize: 15
                color: Theme.colors.on_surface
            }
            ChatToolButton {
                text: "Conversation history"; width: 32; height: 36
                enabled: CodexCommands.canManage
                contentItem: Text {
                    text: "history"; color: Theme.colors.on_surface_variant
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.family: "Material Symbols Rounded"; font.pixelSize: 21
                }
                onClicked: {
                    if (root.completing) LocalCodex.draft = ""
                    CodexCommands.history(false, "")
                    picker.focusSearch()
                }
            }
            PanelAction {
                symbol: "add_comment"; text: "New conversation"
                enabled: !LocalCodex.busy && !LocalCodex.connecting && !LocalCodex.managing
                         && (LocalCodex.messages.count > 0 || LocalCodex.threadId !== "")
                onClicked: { CodexCommands.close(); LocalCodex.newChat() }
            }
        }
        CodexPicker {
            id: picker
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: completing || !!CodexCommands.page
            completing: root.completing
            onReturnToEditor: editor.forceActiveFocus()
            onCommandChosen: (name, execute) => {
                CodexCommands.close()
                LocalCodex.draft = name + (name === "/rename" || !execute ? " " : "")
                editor.forceActiveFocus()
                editor.cursorPosition = editor.length
                if (execute && name !== "/rename") root.submit()
            }
        }
        ListView {
            id: transcript
            visible: !picker.visible
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            spacing: 10
            model: LocalCodex.messages
            ScrollBar.vertical: ScrollBar {}
            property bool follow: true
            function scrollToLatest(): void {
                if (follow && count) positionViewAtEnd()
            }
            onMovementStarted: follow = false
            onMovementEnded: follow = atYEnd
            onContentHeightChanged: Qt.callLater(scrollToLatest)
            onCountChanged: Qt.callLater(scrollToLatest)
            header: PanelAction {
                visible: !!LocalCodex.olderCursor
                height: visible ? 34 : 0
                text: LocalCodex.loadingOlder ? "Loading…" : "Load earlier messages"
                enabled: !LocalCodex.loadingOlder && LocalCodex.ready
                onClicked: {
                    transcript.follow = false
                    LocalCodex.loadOlder()
                }
            }
            delegate: Item {
                id: message
                required property string who
                required property string body
                readonly property bool mine: who === "You"
                width: transcript.width - 8
                implicitHeight: bubble.height
                Rectangle {
                    id: bubble
                    x: message.mine ? message.width - width : 0
                    width: Math.min(message.width * (message.mine ? 0.9 : 1), Math.max(56, bodyText.implicitWidth + 20))
                    height: bodyText.contentHeight + 16
                    radius: 10
                    color: message.mine ? Theme.colors.primary_container : Theme.colors.surface_container
                    TextEdit {
                        id: bodyText
                        x: 10; y: 8; width: parent.width - 20
                        text: message.body
                        color: message.mine ? Theme.colors.on_primary_container : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"; font.pixelSize: 13
                        readOnly: true; selectByMouse: true
                        textFormat: TextEdit.PlainText; wrapMode: TextEdit.Wrap
                    }
                }
            }
        }
        Rectangle {
            id: approvalBox
            readonly property var req: LocalCodex.approvals[0] ?? null
            visible: req !== null
            Layout.fillWidth: true
            implicitHeight: approvalLayout.implicitHeight + 18
            color: Theme.colors.surface_container_high
            radius: 10
            ColumnLayout {
                id: approvalLayout
                anchors.fill: parent; anchors.margins: 9
                Text {
                    text: approvalBox.req?.method === "item/fileChange/requestApproval" ? "Allow file changes?"
                          : approvalBox.req?.method === "item/commandExecution/requestApproval" ? "Allow this command?"
                          : "Allow these permissions for this turn?"
                    color: Theme.colors.primary; font.bold: true
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(110, details.contentHeight)
                    TextArea {
                        id: details
                        readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                        text: approvalBox.req ? JSON.stringify(approvalBox.req.params, (k,v) =>
                                ["threadId", "turnId", "itemId", "startedAtMs"].includes(k) ? undefined : v, 2) : ""
                        color: Theme.colors.on_surface; font.pixelSize: 12
                        background: null
                    }
                }
                RowLayout {
                    PanelAction { text: "Allow once"; onClicked: LocalCodex.decide(true) }
                    PanelAction { text: "Deny"; onClicked: LocalCodex.decide(false) }
                }
            }
        }
        RowLayout {
            visible: !!LocalCodex.errorText || LocalCodex.busy || LocalCodex.connecting || !!LocalCodex.activity
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: LocalCodex.errorText || (LocalCodex.connecting ? "Connecting to Local Codex…" : LocalCodex.activity)
                color: LocalCodex.errorText ? Theme.colors.error : Theme.colors.on_surface_variant
                font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            PanelAction {
                visible: !LocalCodex.ready && !LocalCodex.connecting
                text: "Reconnect"; onClicked: LocalCodex.activate()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(48, Math.min(120, editor.contentHeight + 16))
            radius: 12; color: Theme.colors.surface_container_high
            border.color: editor.activeFocus ? Theme.colors.primary : Theme.colors.outline_variant
            ScrollView {
                anchors.fill: parent; anchors.margins: 6; anchors.rightMargin: 48
                TextArea {
                    id: editor
                    verticalAlignment: TextEdit.AlignVCenter
                    topPadding: 2
                    bottomPadding: 2
                    text: LocalCodex.draft
                    onTextChanged: if (activeFocus && text !== LocalCodex.draft) LocalCodex.draft = text
                    placeholderText: "Message Codex or type /"
                    color: Theme.colors.on_surface; placeholderTextColor: Theme.colors.on_surface_variant
                    font.family: "Maple Mono NF CN"; font.pixelSize: 13
                    wrapMode: TextEdit.Wrap; selectByMouse: true
                    background: null
                    Keys.onPressed: event => {
                        event.accepted = false
                        if (inputMethodComposing) return
                        if (picker.handleKey(event)) {
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                   && !(event.modifiers & Qt.ShiftModifier)) {
                            event.accepted = true
                            if (!event.isAutoRepeat && LocalCodex.ready && (root.commandInput || CodexCommands.canManage))
                                root.submit()
                        }
                    }
                }
            }
            ChatToolButton {
                id: submit
                anchors.right: parent.right; anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36
                text: LocalCodex.busy ? "Stop generating" : "Send"
                enabled: LocalCodex.busy ? !!LocalCodex.turnId : CodexCommands.canManage && !!LocalCodex.draft.trim()
                background: Rectangle {
                    radius: 10; color: submit.enabled ? Theme.colors.primary_container : "transparent"
                }
                contentItem: Text {
                    text: LocalCodex.busy ? "stop" : "arrow_upward"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.family: "Material Symbols Rounded"; font.pixelSize: 21
                    color: submit.enabled ? Theme.colors.on_primary_container : Theme.colors.outline
                }
                onClicked: {
                    if (LocalCodex.busy) LocalCodex.interrupt()
                    else {
                        editor.forceActiveFocus()
                        root.submit()
                    }
                }
            }
        }
    }
}
