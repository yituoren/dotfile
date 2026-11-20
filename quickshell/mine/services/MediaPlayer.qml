pragma Singleton
pragma ComponentBehavior: Bound

// MPRIS player selection
// Prefer a playing session. The manual choice breaks ties while playing or paused.
// Quickshell extrapolates MPRIS position between playback notifications.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: BrowserTabs.sources.filter(p => !p.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld"))
    property string manualKey: ""
    property string manualPlaybackState: ""
    readonly property string playbackState: JSON.stringify(list.filter(p => p.isPlaying).map(p => p.dbusName).sort())
    function selectPlayer(row): void {
        manualKey = row.dbusName
        manualPlaybackState = playbackState
    }
    onPlaybackStateChanged: manualPlaybackState = ""
    property var remembered: ({})
    property var lastAudible: ({})
    property var reportedPlaying: ({})
    readonly property var list: {
        const rows = []
        const covered = new Set()
        for (const plasma of BrowserTabs.integrations) {
            const native = BrowserTabs.nativeFor(plasma)
            covered.add(plasma)
            if (native) covered.add(native)
            const tabs = BrowserTabs.snapshot[plasma.dbusName] || []
            if (!tabs.length) {
                // The runner is optional. Keep the ordinary MPRIS player usable without it.
                rows.push(playerRow(!plasma.isPlaying && native?.isPlaying ? native : plasma))
                continue
            }
            const plasmaTab = unique(tabs.filter(t => t.url === plasma.metadata["xesam:url"]))
            const nativeUrl = native?.metadata["xesam:url"]
            const nativeTab = nativeUrl ? unique(tabs.filter(t => t.url === nativeUrl))
                : unique(tabs.filter(t => t.title === native?.trackTitle))
            for (const tab of tabs) {
                const rich = tab === plasmaTab ? plasma : null
                const raw = tab === nativeTab ? native : null
                const key = plasma.dbusName + "/" + tab.id
                const saved = remembered[key]
                const previous = saved?.url === tab.url && saved?.pageTitle === tab.title ? saved : null
                const playing = (rich || raw) ? !!(rich?.isPlaying || raw?.isPlaying) : tab.audible
                const transport = [rich, raw].filter(Boolean).find(p => p.isPlaying === playing) ?? null
                // Read position and duration together from one identified session.
                const clocks = [raw, rich].filter(p => p && p.isPlaying === playing && p.positionSupported)
                const clock = clocks.find(p => lengthOf(p) > 0) ?? clocks[0] ?? transport
                rows.push({ dbusName: key, identity: tab.url.split("/")[2], tab, isPlaying: playing,
                    trackTitle: rich?.trackTitle || previous?.title || tab.title,
                    trackArtist: rich?.trackArtist || previous?.artist || "",
                    trackAlbum: rich?.trackAlbum || previous?.album || "",
                    trackArtUrl: rich?.trackArtUrl || raw?.trackArtUrl || "",
                    metadata: { "xesam:url": tab.url, "xesam:asText": rich?.metadata["xesam:asText"] || "",
                        "mpris:trackid": rich?.metadata["mpris:trackid"] || raw?.metadata["mpris:trackid"] || "" },
                    rich, raw, clock, transport })
            }
        }
        for (const p of players) if (!covered.has(p)) rows.push(playerRow(p))
        return rows
    }
    function unique(matches) { return matches.length === 1 ? matches[0] : null }
    function playerRow(p) {
        return { dbusName: p.dbusName, identity: p.identity, isPlaying: p.isPlaying,
            trackTitle: p.trackTitle, trackArtist: p.trackArtist, trackAlbum: p.trackAlbum,
            trackArtUrl: p.trackArtUrl, metadata: p.metadata, clock: p, transport: p, raw: p }
    }
    // Remember metadata for a background tab while Plasma is reporting another page.
    onListChanged: rememberSoon.restart()
    Timer {
        id: rememberSoon
        interval: 0
        onTriggered: {
            const cache = {}, activity = {}, reported = {}
            const now = Date.now()
            for (const row of root.list) {
                if (!row.tab) continue
                const key = row.dbusName
                const old = root.remembered[key]
                if (row.rich?.trackTitle)
                    cache[key] = { url: row.tab.url, pageTitle: row.tab.title, title: row.rich.trackTitle,
                        artist: row.rich.trackArtist, album: row.rich.trackAlbum }
                else if (old?.url === row.tab.url && old?.pageTitle === row.tab.title) cache[key] = old
                // Chrome can keep the audible flag set briefly across a pause and resume.
                // A newly confirmed playing session takes precedence over that stale flag.
                reported[key] = !!row.transport?.isPlaying
                const started = reported[key] && !root.reportedPlaying[key]
                activity[key] = row.isPlaying ? (started ? now : root.lastAudible[key] || now) : 0
            }
            if (JSON.stringify(cache) !== JSON.stringify(root.remembered)) root.remembered = cache
            if (JSON.stringify(activity) !== JSON.stringify(root.lastAudible)) root.lastAudible = activity
            root.reportedPlaying = reported
            root.sampleTabClocks()
        }
    }
    readonly property var active: {
        const preferred = list.find(p => p.dbusName === manualKey)
        if (preferred && (preferred.isPlaying || manualPlaybackState === playbackState)) return preferred
        let playing = null
        for (const p of list) {
            if (p.isPlaying && (!playing || (lastAudible[p.dbusName] || 0) > (lastAudible[playing.dbusName] || 0))) playing = p
        }
        return playing ?? preferred ?? list[0] ?? null
    }
    readonly property string trackTitle: active?.trackTitle || ""
    readonly property string trackArtist: active?.trackArtist || ""
    readonly property string trackAlbum: active?.trackAlbum || ""
    readonly property var clockPlayer: active?.clock ?? null
    readonly property var transport: active?.transport ?? null
    function lengthOf(player): real {
        const micros = Number(player?.metadata["mpris:length"])
        return micros > 0 && Number.isSafeInteger(micros) ? micros / 1000000 : 0
    }

    // Keep an independent anchor for a tab when both browser-wide clocks move away.
    property var tabClocks: ({})
    property double tickTime: Date.now()
    function tabTrackKey(row): string {
        return JSON.stringify([row.tab.url, row.tab.title, row.trackTitle, row.trackArtist, row.trackAlbum])
    }
    function elapsedAt(sample, now): real {
        return sample.seconds + (sample.playing ? Math.max(0, now - sample.at) * sample.rate / 1000 : 0)
    }
    function sampleTabClocks(): void {
        const now = Date.now()
        const next = {}
        for (const row of list) {
            if (!row.tab) continue
            const key = row.dbusName
            const track = tabTrackKey(row)
            const p = row.clock
            const length = lengthOf(p)
            const seconds = p?.position
            if (p?.positionSupported && Number.isFinite(seconds) && seconds >= 0 && seconds <= length && length > 0) {
                next[key] = { track, length, seconds, at: now, rate: p.rate || 1, playing: row.isPlaying }
                continue
            }
            const old = tabClocks[key]
            if (!old || old.track !== track) continue
            const elapsed = elapsedAt(old, now)
            if (elapsed > old.length) continue
            next[key] = old.playing === row.isPlaying ? old
                : Object.assign({}, old, { seconds: elapsed, at: now, playing: row.isPlaying })
        }
        tabClocks = next
        tickTime = now
    }
    readonly property var savedClock: {
        if (!active?.tab) return null
        const sample = tabClocks[active.dbusName]
        return sample?.track === tabTrackKey(active)
            && elapsedAt(sample, tickTime) <= sample.length ? sample : null
    }
    readonly property bool livePosition: !!clockPlayer?.positionSupported && Number.isFinite(clockPlayer.position)
    readonly property real duration: lengthOf(clockPlayer) || savedClock?.length || 0
    readonly property bool positionKnown: livePosition || !!savedClock
    readonly property real position: livePosition ? Math.max(0, clockPlayer.position)
        : savedClock ? elapsedAt(savedClock, tickTime) : 0

    Connections {
        target: root.clockPlayer
        function onPositionChanged() { sampleSoon.restart() }
        function onRateChanged() { sampleSoon.restart() }
    }
    Timer { id: sampleSoon; interval: 0; onTriggered: root.sampleTabClocks() }
    Timer {
        interval: 500
        repeat: true
        running: !!root.active?.isPlaying && PopupManager.currentPopup === "dashboard"
            && PopupManager.dashboardTab === "media"
        triggeredOnStart: true
        onTriggered: {
            if (root.clockPlayer) root.clockPlayer.positionChanged()
            else root.tickTime = Date.now()
        }
    }
    readonly property bool hasActive: !!active
    function capable(property) {
        return [transport, active?.raw].find(p => p?.[property] && p.isPlaying === active.isPlaying) ?? null
    }
    readonly property var previousPlayer: capable("canGoPrevious")
    readonly property var nextPlayer: capable("canGoNext")
    readonly property var playPausePlayer: capable("canTogglePlaying")

    // Cover art with a YouTube thumbnail fallback, adapted from Caelestia.
    function getArtUrl(player: var): string {
        if (!player) return ""
        if (player.trackArtUrl) return player.trackArtUrl
        const url = player.metadata?.["xesam:url"] ?? ""
        if (typeof url === "string" && url.startsWith("https://www.youtube.com/watch")) {
            const m = url.match(/[?&]v=([\w-]{11})/)
            if (m) return `https://img.youtube.com/vi/${m[1]}/hqdefault.jpg`
        }
        return ""
    }

    function getIdentity(player: var): string {
        if (!player) return ""
        return player.identity || (player.dbusName ?? "").split(".").pop() || "Unknown"
    }

    function formatTime(seconds: real): string {
        if (!seconds || seconds < 0 || !isFinite(seconds)) return "0:00"
        const total = Math.floor(seconds)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = (total % 60).toString().padStart(2, "0")
        if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s}`
        return `${m}:${s}`
    }
}
