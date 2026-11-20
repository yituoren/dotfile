pragma ComponentBehavior: Bound

// MediaTab —— dashboard "Media" tab
//
// Layout:
//   Top row: volume, sink and player selectors with proportional widths and equal spacing.
//   │
//   Bottom row: playback information on the left and the disc with its cava halo on the right.
//        - A MultiEffect mask clips the cover to a disc with a center pin and 32 radial cava bars.
//        - The playback panel contains title, artist, album, lyrics, progress, time and controls.
//
// QtQuick.Effects.MultiEffect masks the square album art to a circle.
// The tab requests cava while visible and releases it on destruction.

import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.services
import qs.modules.bar.widgets

Item {
    id: root

    readonly property var active: MediaPlayer.active
    // Apple Music can publish its playlist clock on both browser interfaces.
    readonly property real trackDuration: Lyrics.streamClock ? Lyrics.catalogDuration : MediaPlayer.duration
    readonly property bool trackClock: !Lyrics.streamClock || (trackDuration > 0 && MediaPlayer.duration > 0
        && Math.abs(trackDuration - MediaPlayer.duration) <= 4)
    readonly property bool showPosition: MediaPlayer.positionKnown && (!Lyrics.streamClock
        || (trackDuration > 0 && MediaPlayer.position <= trackDuration))
    readonly property real progress: showPosition && trackDuration > 0 ? Math.min(1, MediaPlayer.position / trackDuration) : 0
    readonly property var defaultSink: SystemStatus.audioSinks.find(s => s.isDefault) || null

    // Only one dropdown can be open: "", "sink" or "player".
    property string openMenu: ""

    // Disc rotation
    property real discAngle: 0
    Timer {
        running: root.active ? root.active.isPlaying : false
        interval: 33; repeat: true
        onTriggered: root.discAngle = (root.discAngle + 3) % 360
    }

    function sinkIcon(sink) {
        if (!sink) return "speaker"
        const n = (sink.name ?? "").toLowerCase()
        const d = (sink.description ?? "").toLowerCase()
        if (/bluez/.test(n)) return "bluetooth_audio"
        if (/hdmi/.test(n) || /hdmi/.test(d)) return "tv"
        if (/usb/.test(n) && /head/.test(d)) return "headset"
        return "speaker"
    }

    // ============ Empty state ============
    Item {
        anchors.fill: parent
        visible: !root.active
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "music_off"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 72
                color: Theme.colors.on_surface_variant
                opacity: 0.45
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No active media player"
                color: Theme.colors.on_surface_variant
                opacity: 0.6
                font.family: "Maple Mono NF CN"
                font.pixelSize: 14
                font.styleName: "Medium"
            }
        }
    }

    // ============ Player view ============
    Item {
        id: mainView
        anchors.fill: parent
        visible: root.active !== null

        // ---- Volume, sink and player selectors ----
        // Distribute the width after spacing: 36% volume, 28% sink and 36% player.
        Item {
            id: topRow
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 14
                rightMargin: 14
            }
            height: 44

            readonly property int spacing: 8
            readonly property real cellAvail: width - 2 * spacing

            // vol pill
            Rectangle {
                id: volPill
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Math.round(topRow.cellAvail * 0.30)
                radius: height / 2
                color: Theme.colors.surface_container

                Text {
                    id: volIcon
                    anchors {
                        left: parent.left; leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22; horizontalAlignment: Text.AlignHCenter
                    text: SystemStatus.volumeIcon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: SystemStatus.volumeSilent ? Theme.colors.on_surface_variant : Theme.colors.primary
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemStatus.toggleMute()
                    }
                }
                SliderBar {
                    anchors {
                        left: volIcon.right; leftMargin: 10
                        right: volPctText.left; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    value: SystemStatus.volume
                    onMoved: (v) => SystemStatus.setVolume(v)
                }
                Text {
                    id: volPctText
                    anchors {
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 32; horizontalAlignment: Text.AlignRight
                    text: SystemStatus.volumeSilent ? "—" : `${SystemStatus.volumePercent}%`
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Bold"
                }
            }

            // sink trigger
            Rectangle {
                id: sinkBtn
                anchors {
                    left: volPill.right; leftMargin: topRow.spacing
                    top: parent.top; bottom: parent.bottom
                }
                width: Math.round(topRow.cellAvail * 0.44)
                radius: height / 2
                color: sinkBtnHover.containsMouse
                    ? Qt.tint(Theme.colors.primary_container, "#15ffffff")
                    : Theme.colors.primary_container
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: sinkBtnIcon
                    anchors {
                        left: parent.left; leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22; horizontalAlignment: Text.AlignHCenter
                    text: root.sinkIcon(root.defaultSink)
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.on_primary_container
                }
                Text {
                    anchors {
                        left: sinkBtnIcon.right; leftMargin: 8
                        right: sinkBtnChevron.left; rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.defaultSink ? root.defaultSink.description : "—"
                    color: Theme.colors.on_primary_container
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
                Text {
                    id: sinkBtnChevron
                    anchors {
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.openMenu === "sink" ? "expand_less" : "expand_more"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.on_primary_container
                    opacity: 0.8
                }
                MouseArea {
                    id: sinkBtnHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMenu = root.openMenu === "sink" ? "" : "sink"
                }
            }

            // player trigger
            Rectangle {
                id: playerBtn
                anchors {
                    left: sinkBtn.right; leftMargin: topRow.spacing
                    right: parent.right
                    top: parent.top; bottom: parent.bottom
                }
                radius: height / 2
                color: playerBtnHover.containsMouse
                    ? Theme.colors.surface_container_high
                    : Theme.colors.surface_container
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: playerBtnIcon
                    anchors {
                        left: parent.left; leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22; horizontalAlignment: Text.AlignHCenter
                    text: root.active ? "music_note" : "music_off"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.primary
                }
                Text {
                    anchors {
                        left: playerBtnIcon.right; leftMargin: 8
                        right: playerBtnChevron.left; rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.active ? MediaPlayer.getIdentity(root.active) : "No player"
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
                Text {
                    id: playerBtnChevron
                    anchors {
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.openMenu === "player" ? "expand_less" : "expand_more"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.on_surface
                    opacity: 0.8
                }
                MouseArea {
                    id: playerBtnHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMenu = root.openMenu === "player" ? "" : "player"
                }
            }
        }

        // ---- Playback details and disc halo ----
        Item {
            id: playbackArea
            anchors {
                top: topRow.bottom
                topMargin: 14
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 10
            }

            // ---- Playback information on the left ----
            Item {
                id: panel
                anchors {
                    left: parent.left
                    leftMargin: 28
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: 32
                    bottomMargin: 18
                }
                // Allow 280 px for the disc, 28 px for its right margin and 28 px between it and the panel.
                width: parent.width - 280 - 28 - 28 - 28

                // ---- Title, artist and album ----
                Text {
                    id: titleText
                    anchors {
                        top: parent.top
                        left: parent.left; right: parent.right
                    }
                    text: MediaPlayer.trackTitle || "Unknown Title"
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 17
                    font.styleName: "ExtraBold"
                    elide: Text.ElideRight
                }
                Text {
                    id: artistText
                    anchors {
                        top: titleText.bottom; topMargin: 4
                        left: parent.left; right: parent.right
                    }
                    text: MediaPlayer.trackArtist
                    color: Theme.colors.primary
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
                Text {
                    id: albumText
                    anchors {
                        top: artistText.bottom; topMargin: 2
                        left: parent.left; right: parent.right
                    }
                    text: MediaPlayer.trackAlbum
                    color: Theme.colors.on_surface_variant
                    opacity: 0.75
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Medium"
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                // ---- Controls, time and progress ----
                Row {
                    id: controlsRow
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                    }
                    spacing: 10

                    component IconBtn: Rectangle {
                        id: btn
                        required property string icon
                        property bool big: false
                        property bool primary: false
                        property bool disabled: false
                        signal clicked()

                        readonly property real sz: btn.big ? 48 : 36
                        width: sz; height: sz; radius: sz / 2
                        color: {
                            if (btn.disabled) return "transparent"
                            if (btn.primary) return btnHover.containsMouse
                                ? Qt.tint(Theme.colors.primary, "#20ffffff")
                                : Theme.colors.primary
                            return btnHover.containsMouse
                                ? Theme.colors.surface_container_high
                                : "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        opacity: btn.disabled ? 0.35 : 1
                        scale: btnHover.pressed ? 0.92 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: btn.icon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: btn.big ? 26 : 20
                            color: btn.primary ? Theme.colors.on_primary : Theme.colors.on_surface
                        }
                        MouseArea {
                            id: btnHover
                            anchors.fill: parent
                            hoverEnabled: !btn.disabled
                            cursorShape: btn.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (!btn.disabled) btn.clicked()
                        }
                    }

                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: (root.active && MediaPlayer.transport?.shuffle) ? "shuffle_on" : "shuffle"
                        disabled: !(root.active && MediaPlayer.transport?.shuffleSupported)
                        onClicked: { if (MediaPlayer.transport?.shuffleSupported) MediaPlayer.transport.shuffle = !MediaPlayer.transport.shuffle }
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_previous"
                        disabled: !MediaPlayer.previousPlayer
                        onClicked: MediaPlayer.previousPlayer?.previous()
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        big: true; primary: true
                        icon: (root.active && root.active.isPlaying) ? "pause" : "play_arrow"
                        disabled: !MediaPlayer.playPausePlayer
                        onClicked: MediaPlayer.playPausePlayer?.togglePlaying()
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_next"
                        disabled: !MediaPlayer.nextPlayer
                        onClicked: MediaPlayer.nextPlayer?.next()
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: {
                            if (!root.active) return "repeat"
                            switch (MediaPlayer.transport?.loopState) {
                            case MprisLoopState.Track: return "repeat_one_on"
                            case MprisLoopState.Playlist: return "repeat_on"
                            default: return "repeat"
                            }
                        }
                        disabled: !(root.active && MediaPlayer.transport?.loopSupported)
                        onClicked: {
                            if (!root.active) return
                            const s = MediaPlayer.transport?.loopState
                            MediaPlayer.transport.loopState = s === MprisLoopState.None
                                ? MprisLoopState.Playlist
                                : s === MprisLoopState.Playlist
                                    ? MprisLoopState.Track
                                    : MprisLoopState.None
                        }
                    }
                }

                Item {
                    id: timeRow
                    anchors {
                        left: parent.left; right: parent.right
                        bottom: controlsRow.top; bottomMargin: 10
                    }
                    height: 14
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.showPosition ? MediaPlayer.formatTime(MediaPlayer.position) : "—"
                        color: Theme.colors.on_surface_variant
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.trackDuration > 0 ? MediaPlayer.formatTime(root.trackDuration) : "—"
                        color: Theme.colors.on_surface_variant
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 11
                    }
                }
                Item {
                    id: progressRow
                    anchors {
                        left: parent.left; right: parent.right
                        bottom: timeRow.top; bottomMargin: 2
                    }
                    height: 22
                    SliderBar {
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        enabled: root.trackClock && !!MediaPlayer.clockPlayer?.canSeek && MediaPlayer.livePosition && root.showPosition && MediaPlayer.clockPlayer.lengthSupported
                        value: root.progress
                        minValue: 0
                        onMoved: (v) => {
                            const a = MediaPlayer.clockPlayer
                            if (root.trackClock && a?.canSeek && a.positionSupported && a.lengthSupported && MediaPlayer.duration > 0) {
                                a.position = v * MediaPlayer.duration
                            }
                        }
                    }
                }

                Item {
                    id: lyricArea
                    anchors {
                        top: albumText.bottom; topMargin: 12
                        bottom: progressRow.top; bottomMargin: 12
                        left: parent.left; right: parent.right
                    }
                    clip: true
                    readonly property int typeSize: width < 360 || height < 110 ? 20 : 24
                    readonly property int secondaryTypeSize: Math.round(typeSize * 0.84)
                    readonly property bool synced: Lyrics.status === "ok" && Lyrics.canSync
                    readonly property bool plain: Lyrics.status === "plain" || (Lyrics.status === "ok" && !Lyrics.canSync)
                    readonly property bool shaderEffects: GraphicsInfo.api !== GraphicsInfo.Software

                    // Fade the glyphs themselves so the wallpaper stays visible at both edges.
                    Rectangle {
                        id: lyricFade
                        anchors.fill: parent
                        visible: false
                        layer.enabled: lyricArea.synced && lyricArea.shaderEffects
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.18; color: "white" }
                            GradientStop { position: 0.82; color: "white" }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }

                    ListView {
                        id: timedLyrics
                        anchors.fill: parent
                        visible: lyricArea.synced
                        layer.enabled: visible && lyricArea.shaderEffects
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: lyricFade
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        model: lyricArea.synced ? Lyrics.lines : []
                        currentIndex: count ? Math.max(0, Lyrics.currentIndex) : -1
                        spacing: 10
                        boundsBehavior: Flickable.StopAtBounds
                        readonly property real focusY: height / 3
                        property int lastLine: -1
                        function centerLine(): void {
                            if (currentIndex < 0 || !currentItem || height <= 0) return
                            forceLayout()
                            const start = contentY
                            scrollLine.stop()
                            positionViewAtIndex(currentIndex, ListView.Beginning)
                            contentY = currentItem.y - Math.max(0, focusY - currentItem.height / 2)
                            const end = contentY
                            if (lastLine >= 0 && Math.abs(currentIndex - lastLine) === 1 && Math.abs(end - start) < height) {
                                scrollLine.from = start
                                scrollLine.to = end
                                scrollLine.start()
                            }
                            lastLine = currentIndex
                        }
                        onCurrentIndexChanged: Qt.callLater(centerLine)
                        onCurrentItemChanged: Qt.callLater(centerLine)
                        onModelChanged: { lastLine = -1; Qt.callLater(centerLine) }
                        onHeightChanged: Qt.callLater(centerLine)
                        onWidthChanged: Qt.callLater(centerLine)
                        onMovementStarted: scrollLine.stop()
                        NumberAnimation {
                            id: scrollLine
                            target: timedLyrics; property: "contentY"
                            duration: 380; easing.type: Easing.InOutCubic
                        }
                        header: Item { height: timedLyrics.focusY }
                        footer: Item { height: timedLyrics.height - timedLyrics.focusY }

                        delegate: Text {
                            id: lyricLine
                            required property var modelData
                            required property int index
                            readonly property bool singing: index === timedLyrics.currentIndex
                            // Treat the middle of a wrapped verse as one focus area.
                            readonly property real centerOffset: Math.abs(y + height / 2 - timedLyrics.contentY - timedLyrics.focusY)
                            readonly property real distance: Math.min(1, Math.max(0,
                                centerOffset - (height - height / Math.max(1, lineCount)) / 2 - 1)
                                / Math.max(1, timedLyrics.height * 0.48))
                            width: timedLyrics.width
                            text: modelData.text
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "Maple Mono NF CN"
                            font.styleName: "Bold"
                            font.pixelSize: singing ? lyricArea.typeSize : lyricArea.secondaryTypeSize
                            color: singing ? Theme.colors.primary : Theme.colors.on_surface_variant
                            opacity: singing ? 1 : 1 - 0.76 * distance
                            layer.enabled: !singing && lyricArea.shaderEffects && distance > 0 && y + height > timedLyrics.contentY
                                           && y < timedLyrics.contentY + timedLyrics.height
                            layer.effect: MultiEffect {
                                blurEnabled: true
                                blurMax: 8
                                blur: 0.65 * lyricLine.distance
                            }
                            Behavior on color { ColorAnimation { duration: 240 } }
                        }
                    }

                    Flickable {
                        id: plainView
                        anchors.fill: parent
                        visible: lyricArea.plain
                        contentWidth: width
                        contentHeight: plainLyrics.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Text {
                            id: plainLyrics
                            width: plainView.width
                            text: lyricArea.plain ? Lyrics.lines.map(l => l.text).join("\n") : ""
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            lineHeight: 1.23
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "Maple Mono NF CN"
                            font.styleName: "Bold"
                            font.pixelSize: lyricArea.secondaryTypeSize
                            color: Theme.colors.on_surface_variant
                            onTextChanged: plainView.contentY = 0
                        }
                    }

                    Text {
                        visible: Lyrics.status !== "instrumental" && !lyricArea.synced && !lyricArea.plain
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (Lyrics.status) {
                            case "loading": return "Loading lyrics…"
                            case "instrumental": return ""
                            case "miss": return "No lyrics"
                            case "error": return "Lyrics fetch failed"
                            default: return root.active ? "♪" : "—"
                            }
                        }
                        color: Theme.colors.on_surface_variant
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 14
                    }
                }
            }

            // ---- Disc and cava halo on the right ----
            Item {
                id: discArea
                anchors {
                    right: parent.right
                    rightMargin: 28
                    verticalCenter: parent.verticalCenter
                }
                width: 280
                height: 280

                readonly property real coverDiameter: 174  // Reduce the cover diameter to leave room for the halo.
                readonly property real innerRadius: discArea.coverDiameter / 2 + 8  // Inner edge of the halo
                readonly property real maxBar: 36

                // ── cava halo bars ──
                Repeater {
                    model: Cava.bars
                    delegate: Item {
                        id: barItem
                        required property int index
                        readonly property real value: Cava.values[barItem.index] ?? 0
                        readonly property real angle: barItem.index * 360 / Cava.bars

                        anchors.centerIn: parent
                        width: 1; height: 1
                        rotation: barItem.angle

                        Rectangle {
                            // Rotate around the parent origin. At zero rotation each bar grows straight up.
                            x: -width / 2
                            y: -(discArea.innerRadius + height)
                            width: 4
                            height: Math.max(3, barItem.value * discArea.maxBar)
                            radius: 2
                            color: Theme.colors.primary
                            opacity: 0.55
                            Behavior on height {
                                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                // ---- Rotating disc ----
                Item {
                    id: discSpin
                    anchors.centerIn: parent
                    width: discArea.coverDiameter
                    height: discArea.coverDiameter
                    rotation: root.discAngle

                    // Black vinyl base
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#0a0a0a"
                    }

                    // Clip the square cover to a circle with a MultiEffect mask.
                    Image {
                        id: coverImage
                        anchors.centerIn: parent
                        width: discArea.coverDiameter - 16
                        height: discArea.coverDiameter - 16
                        source: MediaPlayer.getArtUrl(root.active)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: width
                        sourceSize.height: height
                        visible: false
                    }
                    Item {
                        id: coverMaskShape
                        anchors.fill: coverImage
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "white"
                        }
                    }
                    MultiEffect {
                        anchors.fill: coverImage
                        source: coverImage
                        maskEnabled: true
                        maskSource: coverMaskShape
                        maskThresholdMin: 0.5
                        visible: coverImage.status === Image.Ready
                    }

                    // Fallback for missing cover art
                    Rectangle {
                        anchors.fill: coverImage
                        radius: width / 2
                        color: Theme.colors.surface_container_high
                        visible: coverImage.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 56
                            color: Theme.colors.on_surface_variant
                            opacity: 0.45
                        }
                    }

                    // Rotate the center pin with the vinyl.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        radius: 7
                        color: Theme.colors.surface_container_high
                        border.color: Theme.colors.outline
                        border.width: 1
                    }
                }
            }
        }

        // ---- Dropdown menus above playbackArea in stacking order ----
        // Open the sink menu below sinkBtn over the playback area.
        Rectangle {
            id: sinkMenu
            visible: root.openMenu === "sink" || menuOpacity > 0
            opacity: menuOpacity
            property real menuOpacity: root.openMenu === "sink" ? 1 : 0
            Behavior on menuOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            x: topRow.x + sinkBtn.x
            y: topRow.y + sinkBtn.y + sinkBtn.height + 6
            width: sinkBtn.width
            height: Math.min(sinkRows.implicitHeight + 12, 220)
            radius: 16
            color: Theme.colors.surface_container_high
            z: 10

            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                contentWidth: width
                contentHeight: sinkRows.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: sinkRows
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: SystemStatus.audioSinks
                        delegate: Rectangle {
                            id: sinkItem
                            required property var modelData
                            width: parent.width
                            height: 36
                            radius: 12
                            color: sinkItem.modelData.isDefault
                                ? Theme.colors.primary_container
                                : (sinkItemHover.containsMouse ? Theme.colors.surface_container_highest : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: sinkItemIcon
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 20
                                horizontalAlignment: Text.AlignHCenter
                                text: root.sinkIcon(sinkItem.modelData)
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                color: sinkItem.modelData.isDefault
                                    ? Theme.colors.on_primary_container
                                    : Theme.colors.on_surface
                            }
                            Text {
                                anchors {
                                    left: sinkItemIcon.right; leftMargin: 8
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                text: sinkItem.modelData.description
                                color: sinkItem.modelData.isDefault
                                    ? Theme.colors.on_primary_container
                                    : Theme.colors.on_surface
                                font.family: "Maple Mono NF CN"
                                font.pixelSize: 12
                                font.styleName: sinkItem.modelData.isDefault ? "Bold" : "Medium"
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: sinkItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!sinkItem.modelData.isDefault) {
                                        SystemStatus.setDefaultSink(sinkItem.modelData.name)
                                    }
                                    root.openMenu = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        // player menu
        Rectangle {
            id: playerMenu
            visible: root.openMenu === "player" || menuOpacity > 0
            opacity: menuOpacity
            property real menuOpacity: root.openMenu === "player" ? 1 : 0
            Behavior on menuOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            x: topRow.x + playerBtn.x
            y: topRow.y + playerBtn.y + playerBtn.height + 6
            width: playerBtn.width
            height: Math.max(48, Math.min(playerRows.implicitHeight + 12, 220))
            radius: 16
            color: Theme.colors.surface_container_high
            z: 10

            Text {
                anchors.centerIn: parent
                visible: MediaPlayer.list.length === 0
                text: "No players"
                color: Theme.colors.on_surface_variant
                opacity: 0.6
                font.family: "Maple Mono NF CN"
                font.pixelSize: 12
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                contentWidth: width
                contentHeight: playerRows.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: playerRows
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: MediaPlayer.list
                        delegate: Rectangle {
                            id: pItem
                            required property var modelData
                            readonly property bool isActive: pItem.modelData.dbusName === root.active?.dbusName

                            width: parent.width
                            height: 36
                            radius: 12
                            color: pItem.isActive
                                ? Theme.colors.primary_container
                                : (pItemHover.containsMouse ? Theme.colors.surface_container_highest : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: pItemIcon
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 20
                                horizontalAlignment: Text.AlignHCenter
                                text: pItem.modelData.isPlaying ? "play_arrow" : "music_note"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                color: pItem.isActive
                                    ? Theme.colors.on_primary_container
                                    : Theme.colors.on_surface
                            }
                            Text {
                                anchors {
                                    left: pItemIcon.right; leftMargin: 8
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                text: {
                                    const player = pItem.modelData
                                    const identity = MediaPlayer.getIdentity(player)
                                    const title = player.trackTitle
                                    if (!title || (MediaPlayer.list.length < 2 && !player.tab)) return identity
                                    return title + " · " + identity
                                }
                                color: pItem.isActive
                                    ? Theme.colors.on_primary_container
                                    : Theme.colors.on_surface
                                font.family: "Maple Mono NF CN"
                                font.pixelSize: 12
                                font.styleName: pItem.isActive ? "Bold" : "Medium"
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: pItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MediaPlayer.selectPlayer(pItem.modelData)
                                    root.openMenu = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
