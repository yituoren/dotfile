pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.services

Rectangle {
    id: root
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.06)
    border.color: field.activeFocus ? Theme.colors.primary : "transparent"

    readonly property string query: field.text.trim().toLowerCase()
    readonly property var matches: {
        if (!query) return []
        const words = query.split(/\s+/)
        return DesktopEntries.applications.values.filter(app => {
            const haystack = [app.name, app.genericName, app.id, ...app.keywords].join(" ").toLowerCase()
            return !app.noDisplay && words.every(word => haystack.includes(word))
        }).sort((a, b) => Number(b.name.toLowerCase().startsWith(query))
                         - Number(a.name.toLowerCase().startsWith(query)) || a.name.localeCompare(b.name))
    }

    function launch(index: int): void {
        const app = matches[index < 0 ? 0 : index]
        if (!app) return
        if (app.runInTerminal && app.command.length > 0) {
            const args = ["wezterm", "start"]
            if (app.workingDirectory) args.push("--cwd", app.workingDirectory)
            Quickshell.execDetached([...args, "--", ...app.command])
        } else {
            Quickshell.execDetached(["gtk-launch", app.id])
        }
        field.clear()
        PopupManager.close()
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "search"
        color: Theme.colors.primary
        font.family: "Material Symbols Rounded"
        font.pixelSize: 21
    }
    TextField {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 38
        anchors.rightMargin: 10
        placeholderText: "Search apps…"
        color: Theme.colors.on_surface
        placeholderTextColor: Theme.colors.on_surface_variant
        font.family: "Maple Mono NF CN"
        font.pixelSize: 13
        background: null
        onTextChanged: results.currentIndex = 0
        function submit(event: var): void {
            event.accepted = !inputMethodComposing
            if (event.accepted && !event.isAutoRepeat) root.launch(results.currentIndex)
        }
        Keys.onReturnPressed: event => submit(event)
        Keys.onEnterPressed: event => submit(event)
        onAccepted: root.launch(results.currentIndex)
        Keys.onUpPressed: results.decrementCurrentIndex()
        Keys.onDownPressed: results.incrementCurrentIndex()
        Keys.onEscapePressed: clear()
    }

    Rectangle {
        visible: field.activeFocus && root.query.length > 0
        anchors.bottom: parent.top
        anchors.bottomMargin: 4
        width: parent.width
        height: 8 + 34 * Math.min(4, Math.max(1, root.matches.length))
        radius: 10
        color: Theme.colors.surface_container_high
        // Consume clicks in the padding before they reach the calendar.
        MouseArea { anchors.fill: parent }
        ListView {
            id: results
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.matches
            keyNavigationWraps: true
            delegate: Rectangle {
                id: result
                required property var modelData
                required property int index
                width: results.width
                height: 34
                radius: 7
                color: ListView.isCurrentItem ? Theme.colors.primary_container : "transparent"
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: result.modelData.name
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    color: result.ListView.isCurrentItem ? Theme.colors.on_primary_container : Theme.colors.on_surface
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(result.index)
                }
            }
        }
        Text {
            visible: !root.matches.length
            anchors.centerIn: parent
            text: "No matching apps"
            font.family: "Maple Mono NF CN"
            font.pixelSize: 12
            color: Theme.colors.on_surface_variant
        }
    }
}
