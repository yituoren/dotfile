pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import "ShortcutIndex.js" as Index

FocusScope {
    id: sheet
    function focusSearch(): void { search.forceActiveFocus() }

    FileView {
        id: config
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/niri/binds.kdl"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var rows: Index.read(config.text())
    readonly property var groups: [...new Set(rows.map(r => r.section))]
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var matches: rows.filter(r => query
        ? query.split(/\s+/).every(word => r.search.includes(word))
        : r.section === groups[categories.currentIndex])

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: "keyboard"; font.family: "Material Symbols Rounded"
                font.pixelSize: 24; color: Theme.colors.primary
            }
            ShortcutLabel { text: "Shortcuts"; font.styleName: "Bold"; font.pixelSize: 18 }
            Item { Layout.fillWidth: true }
            TextField {
                id: search
                Layout.preferredWidth: 230
                implicitHeight: 34; leftPadding: 12; rightPadding: 12
                placeholderText: "Search actions or keys"
                color: Theme.colors.on_surface; placeholderTextColor: Theme.colors.on_surface_variant
                font.family: "Maple Mono NF CN"; font.pixelSize: 13
                background: Rectangle { radius: 10; color: Theme.colors.surface_container }
                Keys.onDownPressed: {
                    if (sheet.query) results.enter()
                    else categories.enter()
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 14
            ShortcutList {
                onSearchRequested: sheet.focusSearch()
                id: categories
                Layout.preferredWidth: 122; Layout.fillHeight: true
                model: sheet.groups
                Keys.onRightPressed: results.enter()
                Keys.onReturnPressed: results.enter()
                delegate: Rectangle {
                    id: category
                    required property int index
                    required property string modelData
                    readonly property bool selected: !sheet.query && categories.currentIndex === index
                    width: categories.width; height: 35; radius: 9
                    color: selected || hover.hovered ? Theme.colors.surface_container : "transparent"
                    ShortcutLabel {
                        anchors.fill: parent; anchors.leftMargin: 10
                        text: category.modelData
                        font.styleName: category.selected ? "Bold" : "Medium"
                        color: category.selected ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 2; height: 12; radius: 1; color: Theme.colors.primary
                        visible: category.selected && categories.activeFocus
                    }
                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            search.clear()
                            categories.currentIndex = category.index
                            categories.enter()
                        }
                    }
                }
                // Selecting a category with the keyboard leaves the cross-category search.
                onActiveFocusChanged: if (activeFocus && sheet.query) search.clear()
            }
            ShortcutList {
                onSearchRequested: sheet.focusSearch()
                id: results
                Layout.fillWidth: true; Layout.fillHeight: true
                model: sheet.matches
                onModelChanged: { currentIndex = count ? 0 : -1; positionViewAtBeginning() }
                Keys.onLeftPressed: {
                    if (sheet.query) sheet.focusSearch()
                    else categories.enter()
                }
                ScrollIndicator.vertical: ScrollIndicator {}
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: results.width; height: 35; radius: 9
                    color: results.activeFocus && results.currentIndex === index
                        ? Theme.colors.surface_container : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        ShortcutLabel { Layout.fillWidth: true; text: row.modelData.label }
                        ShortcutLabel { text: row.modelData.keys.join(" + "); color: Theme.colors.primary }
                    }
                    TapHandler {
                        onTapped: { results.currentIndex = row.index; results.enter() }
                    }
                }
                ShortcutLabel {
                    anchors.centerIn: parent; visible: !results.count
                    text: sheet.rows.length ? "No matching shortcuts" : "No bindings available"
                    color: Theme.colors.on_surface_variant
                }
            }
        }
    }
}
