pragma ComponentBehavior: Bound

// Keep the workspace indicator in sync with Niri.workspaces.
//
// Workspace states:
//   - Active with windows: a wide pill with one Material Symbols Rounded category icon per window.
//                     A sliding highlight marks the focused window.
//   - Active and empty: a 32 by 24 px pill.
//   - Inactive: a 12 px dot, regardless of window count.
//
// Transitions:
//   - Workspace changes animate pill size and color and fade the icon row.
//   - Focus changes within a workspace slide the highlight with emphasized easing.
//   - Across workspaces, fade the highlight out and back in at its new position.

import QtQuick
import qs.services

Row {
    id: root
    spacing: 10
    readonly property int slotHeight: 24

    // Icon dimensions and spacing also determine the highlight position.
    readonly property int iconSize: 18
    readonly property int iconSpacing: 6
    readonly property int iconStride: iconSize + iconSpacing  // 24

    readonly property var visibleWorkspaces: {
        const list = Niri.workspaces.slice()
        list.sort((a, b) => a.idx - b.idx)
        return list
    }

    function categoryIcon(appId) {
        if (!appId) return "apps"
        const s = appId.toLowerCase()
        if (/term|kitty|alacritty|foot|ghostty|wezterm|^st$|^st-|urxvt/.test(s)) return "terminal"
        if (/yazi|nautilus|dolphin|thunar|nemo|pcmanfm|files/.test(s)) return "folder"
        if (/chrom|firefox|brave|qutebrowser|opera|vivaldi|librewolf|zen/.test(s)) return "language"
        if (/clash|mihomo|v2ray|nekoray|qv2ray|sing-box|tun2socks/.test(s)) return "vpn_lock"
        if (/zed|code|vscode|sublime|atom|vim|emacs|jetbrain|idea|pycharm|goland/.test(s)) return "code"
        if (/discord|telegram|slack|signal|element|qq|wechat|whatsapp/.test(s)) return "chat"
        if (/spotify|youtube|netease/.test(s)) return "music_note"
        if (/vlc|mpv|celluloid|potplayer|smplayer/.test(s)) return "play_circle"
        if (/thunderbird|geary|evolution|mailspring/.test(s)) return "mail"
        if (/feh|swayimg|imv|gthumb|gpicview|loupe|qview|nomacs/.test(s)) return "image"
        if (/pavu|blueberry|nm-connection|gnome-control|systemsettings/.test(s)) return "tune"
        if (/zoom|jitsi|teams|skype|webex/.test(s)) return "videocam"
        if (/krita|gimp|inkscape|blender|figma|drawio/.test(s)) return "brush"
        if (/libreoffice|abiword|onlyoffice|wps/.test(s)) return "description"
        if (/htop|btop|bottom|nvtop|btm/.test(s)) return "monitor_heart"
        if (/steam|lutris|heroic|gamescope|prismlauncher/.test(s)) return "sports_esports"
        if (/obsidian|notion|joplin|logseq/.test(s)) return "edit_note"
        if (/keepass|bitwarden|1password/.test(s)) return "lock"
        if (/torrent|qbittorrent|transmission|deluge/.test(s)) return "download"
        return "apps"
    }

    Repeater {
        model: root.visibleWorkspaces

        Item {
            id: slot
            required property var modelData

            readonly property bool isActive: slot.modelData.id === Niri.activeWorkspaceId
            readonly property var windowsInWs: Niri.windows
                .filter(w => w.workspace_id === slot.modelData.id)
                .sort((a, b) => Niri.compareWindowPosition(a, b))
            readonly property bool hasWindows: slot.windowsInWs.length > 0
            readonly property int focusedIdx:
                slot.windowsInWs.findIndex(w => w.id === Niri.focusedWindowId)

            width: pillBg.width
            height: root.slotHeight

            Rectangle {
                id: pillBg
                anchors.centerIn: parent
                clip: true  // Clip icons while the workspace pill shrinks.

                width: {
                    if (!slot.isActive) return 12
                    if (!slot.hasWindows) return 32
                    const n = slot.windowsInWs.length
                    return n * root.iconSize + (n - 1) * root.iconSpacing + 16
                }
                height: slot.isActive ? 24 : 12
                radius: height / 2
                color: slot.isActive ? Theme.colors.primary : Theme.colors.surface_container_high

                Behavior on width {
                    NumberAnimation {
                        duration: 420
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                    }
                }
                Behavior on height {
                    NumberAnimation { duration: 380 }
                }
                Behavior on color {
                    ColorAnimation { duration: 340 }
                }

                // ---- Focus highlight (declared before iconRow to draw underneath it) ----
                // Match the workspace pill with a radius of half the height.
                // Use on_primary behind the focused icon and primary for the glyph
                // to reverse the colors inside the workspace pill.
                Rectangle {
                    id: focusHighlight
                    width: 26
                    height: 20
                    radius: height / 2
                    color: Theme.colors.on_primary
                    opacity: (slot.isActive && slot.focusedIdx >= 0) ? 1 : 0
                    visible: opacity > 0

                    // Center the wider chip on the icon with an offset of (26 - iconSize) / 2 = 4 px.
                    x: iconRow.x + slot.focusedIdx * root.iconStride - (width - root.iconSize) / 2
                    y: (pillBg.height - height) / 2

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }
                }

                Row {
                    id: iconRow
                    anchors.centerIn: parent
                    spacing: root.iconSpacing
                    opacity: (slot.isActive && slot.hasWindows) ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 280 }
                    }

                    Repeater {
                        model: slot.windowsInWs

                        Text {
                            id: iconText
                            required property var modelData
                            readonly property bool isFocused: iconText.modelData.id === Niri.focusedWindowId

                            width: root.iconSize
                            height: root.iconSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            text: root.categoryIcon(iconText.modelData.app_id ?? "")
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: root.iconSize
                            // The focused glyph uses the pill background color inside the inverted chip.
                            color: iconText.isFocused ? Theme.colors.primary : Theme.colors.on_primary

                            Behavior on color {
                                ColorAnimation { duration: 220 }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(slot.modelData.id)
            }
        }
    }
}
