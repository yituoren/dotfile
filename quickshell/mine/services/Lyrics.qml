pragma Singleton
pragma ComponentBehavior: Bound

// Read embedded MPRIS lyrics first, then query the public catalogues.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property var active: MediaPlayer.active

    readonly property string trackTitle: MediaPlayer.trackTitle
    readonly property string trackArtist: MediaPlayer.trackArtist
    readonly property string trackAlbum: MediaPlayer.trackAlbum
    readonly property real duration: MediaPlayer.duration
    readonly property real position: MediaPlayer.position

    // Parsed lyric rows: [{time: seconds, text: string}]
    property var lines: []
    property string status: "idle"
    property string source: ""

    readonly property string trackUrl: active?.metadata["xesam:url"] || ""
    readonly property string supplied: active?.metadata["xesam:asText"] || ""
    // Apple Music can publish its browser stream clock across track changes.
    readonly property bool streamClock: /^https:\/\/music\.apple\.com(?:\/|$)/i.test(trackUrl)
    readonly property int lookupDuration: streamClock ? 0 : Math.round(duration)
    readonly property bool canSync: MediaPlayer.positionKnown
    readonly property string signature: JSON.stringify([active?.dbusName || "", trackTitle, trackArtist, trackAlbum,
        lookupDuration, trackUrl, active?.metadata["mpris:trackid"] || "", supplied])
    property real catalogDuration: 0
    property var pending: null
    onSignatureChanged: scheduleFetch()
    Component.onCompleted: scheduleFetch()

    function scheduleFetch(): void {
        debounce.stop()
        catalogDuration = 0
        if (pending) {
            const previous = pending
            pending = null
            previous.running = false
            previous.destroy()
        }
        lines = []
        source = ""
        if (/(?:[（(\[]|\s[-–—]\s)\s*(?:instrumental|off vocal|伴奏|纯音乐|純音樂)\s*(?:version|ver\.?|版)?\s*[）)\]]?\s*$/i.test(trackTitle)) {
            status = "instrumental"
            return
        }
        if (supplied.trim()) {
            const timed = parseLrc(supplied)
            const rows = timed.length ? timed : supplied.split("\n").map(l => ({ time: -1, text: l }))
            if (showLyrics(rows, timed.length ? "ok" : "plain", "MPRIS")) return
        }
        if (active && (trackTitle || trackUrl)) {
            status = "loading"
            debounce.restart()
        } else status = "idle"
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            const p = lookup.createObject(root, { command: ["/usr/bin/python", Quickshell.shellPath("scripts/media_lyrics.py"),
                root.trackTitle, root.trackArtist, root.trackAlbum, String(root.lookupDuration), root.trackUrl] })
            root.pending = p
            p.running = true
        }
    }
    Component {
        id: lookup
        Process {
            id: task
            stdout: SplitParser {
                onRead: line => {
                    if (root.pending !== task) return
                    try {
                        const result = JSON.parse(line)
                        if (Number.isFinite(result.duration) && result.duration > 0) root.catalogDuration = result.duration
                        root.showLyrics(result.lines, result.status, result.source || "")
                    } catch (_) { root.status = "error" }
                }
            }
            onExited: {
                if (root.pending !== task) return
                if (root.status === "loading") root.status = "error"
                root.pending = null
                destroy()
            }
        }
    }

    // Apply the same display rules to embedded lyrics, catalogue results and cached tracks.
    function showLyrics(rows, kind, provider): bool {
        const creditRole = /^(?:作[词詞曲]人?|[词詞]曲?|曲|[编編]曲|[製制]作人|填[词詞]|混音|母[带帶]|[录錄]音|演唱|歌手|[专專][辑輯]|lyrics?|music|composer|lyricist|producer|arranger)$/i
        const byline = /^(?:lyrics(?:\s+(?:and|&)\s+music)?|music|written|composed|arranged|produced)\s+by(?:\s*[:：]|\s+)/i
        const instrumental = /^(?:此歌曲为没有填词的)?(?:纯音乐|純音樂|纯伴奏|純伴奏|伴奏|instrumental(?: version)?|无歌词|無歌詞)(?:\s*[,，。！!·-]?\s*(?:请您?欣赏|請您?欣賞))?[。.!！]?$/i
        let markedInstrumental = kind === "instrumental"
        const words = []
        for (const row of rows) {
            const text = row.text.trim()
            const label = text.replace(/^[\[【（(]\s*|\s*[\]】）)]$/g, "")
            if (instrumental.test(label)) { markedInstrumental = true; continue }
            const colon = label.search(/[:：]/)
            const credit = colon > 0 && label.slice(0, colon).split(/[/／、&和・]/).every(role => creditRole.test(role.trim()))
            if (/^\[(?:intro|verse|pre-chorus|chorus|bridge|outro)(?:\s+\d+)?\]$/i.test(text)) continue
            if (!text || credit || byline.test(label) || /^\[(?:ar|al|ti|au|by|offset|re|ve|length):/i.test(text)) continue
            words.push(row)
        }
        lines = words
        source = provider
        status = kind
        if (!words.length && (kind === "ok" || kind === "plain"))
            status = markedInstrumental ? "instrumental" : "miss"
        return words.length > 0 || markedInstrumental
    }
    function parseLrc(text: string): var {
        const out = []
        const lines = text.split("\n")
        const re = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/g
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            re.lastIndex = 0
            const stamps = []
            let m
            let lastIdx = 0
            while ((m = re.exec(line)) !== null) {
                const min = parseInt(m[1], 10)
                const sec = parseInt(m[2], 10)
                const fracStr = m[3] ?? ""
                const frac = fracStr ? Number("0." + fracStr) : 0
                stamps.push(min * 60 + sec + frac)
                lastIdx = m.index + m[0].length
            }
            if (stamps.length === 0) continue
            const txt = line.substring(lastIdx).trim()
            for (let j = 0; j < stamps.length; j++) {
                out.push({ time: stamps[j], text: txt })
            }
        }
        out.sort((a, b) => a.time - b.time)
        return out
    }

    // Find the last line with a timestamp at or before the current playback position.
    readonly property int currentIndex: {
        const n = root.lines.length
        if (n === 0) return -1
        // Untimed lyrics use time = -1 and have no current line.
        if (root.lines[0].time < 0) return -1
        const p = root.position
        let lo = 0, hi = n - 1, ans = -1
        while (lo <= hi) {
            const mid = (lo + hi) >> 1
            if (root.lines[mid].time <= p) {
                ans = mid
                lo = mid + 1
            } else hi = mid - 1
        }
        return ans
    }

    readonly property string currentLine: root.currentIndex >= 0 ? root.lines[root.currentIndex].text : ""
    readonly property string prevLine: root.currentIndex >= 1 ? root.lines[root.currentIndex - 1].text : ""
    readonly property string nextLine: (root.currentIndex >= 0 && root.currentIndex + 1 < root.lines.length)
        ? root.lines[root.currentIndex + 1].text : ""

    readonly property bool hasSynced: root.status === "ok"
}
