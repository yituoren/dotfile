pragma ComponentBehavior: Bound

// Elide the focused window title when it exceeds the available width.

import QtQuick
import qs.services

Text {
    id: root

    readonly property var focusedWindow: Niri.windows.find(w => w.id === Niri.focusedWindowId)
    readonly property string overviewTag: Niri.overviewOpen ? "[overview]  " : ""
    readonly property string focusedTitle: {
        if (!focusedWindow) return ""
        return focusedWindow.title ?? "(untitled)"
    }

    text: Niri.ready
          ? `${overviewTag}${focusedTitle}`
          : "Niri: connecting..."

    color: Theme.colors.on_surface
    font.family: "Maple Mono NF CN"
    font.pixelSize: 15
    font.styleName: "ExtraBold"
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
}
