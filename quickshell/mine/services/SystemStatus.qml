pragma Singleton
pragma ComponentBehavior: Bound

// Poll battery, Wi-Fi and volume state.
//
// Independent processes and timers use the following intervals:
//   - Battery: 10 s, since charge changes slowly.
//   - Wi-Fi: 5 s to pick up connection changes.
//   - Volume: 2 s, with optimistic updates from setVolume and toggleMute.
//
// Polling suffices here. Event-driven alternatives include udev, nmcli monitor and wpctl notifications.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============ Battery ============

    // -1 means unknown (including NaN), otherwise the percentage is 0 to 100.
    property int batteryPercent: -1
    property string batteryStatus: ""   // "Charging" / "Discharging" / "Not charging" / "Full" / "Unknown"
    readonly property bool batteryCharging: root.batteryStatus === "Charging"
    readonly property bool hasBattery: root.batteryPercent >= 0

    Process {
        id: batCapProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim())
                if (!isNaN(v)) root.batteryPercent = v
            }
        }
    }
    Process {
        id: batStatProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                if (s.length > 0) root.batteryStatus = s
            }
        }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batCapProc.running = true
            batStatProc.running = true
        }
    }

    // ============ WiFi ============

    property bool wifiConnected: false
    property int wifiSignal: 0          // 0-100
    property string wifiSsid: ""
    // Scanned networks, including the active connection, for the Wi-Fi popup
    // Each entry: { ssid: string, signal: int, secured: bool, inUse: bool }
    property var wifiNetworks: []

    // Wi-Fi and airplane mode
    property bool wifiEnabled: true
    // Derive airplane mode from both Wi-Fi and Bluetooth being off so it follows the hardware state.
    readonly property bool airplaneMode: !root.wifiEnabled && !root.bluetoothPowered

    Process {
        id: wifiProc
        // Terse nmcli output separates fields with colons and escapes colons inside SSIDs.
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                // Deduplicate APs by SSID, retaining the strongest BSSID unless another is in use.
                // Keep the connected entry in preference to a stronger signal.
                const bySsid = ({})
                let foundCurrent = false

                for (const line of lines) {
                    // An escaped colon belongs to the field. A bare colon separates fields.
                    const parts = []
                    let buf = ""
                    let i = 0
                    while (i < line.length) {
                        const c = line[i]
                        if (c === '\\' && i + 1 < line.length) {
                            buf += line[i + 1]
                            i += 2
                        } else if (c === ':') {
                            parts.push(buf)
                            buf = ""
                            i++
                        } else {
                            buf += c
                            i++
                        }
                    }
                    parts.push(buf)
                    if (parts.length < 4) continue

                    const inUse = parts[0] === "*"
                    const ssid = parts[1]
                    const signal = parseInt(parts[2]) || 0
                    const security = parts[3]
                    if (!ssid) continue  // Skip hidden networks.

                    const existing = bySsid[ssid]
                    // Prefer the active entry, then the strongest signal.
                    if (!existing || inUse || (!existing.inUse && signal > existing.signal)) {
                        bySsid[ssid] = {
                            ssid: ssid,
                            signal: signal,
                            secured: security !== "" && security !== "--",
                            inUse: inUse
                        }
                    }

                    if (inUse && !foundCurrent) {
                        root.wifiConnected = true
                        root.wifiSignal = signal
                        if (root.wifiMessage === "Complete the connection in WezTerm" && ssid === wifiConnect.ssid)
                            root.wifiMessage = ""
                        root.wifiSsid = ssid
                        foundCurrent = true
                    }
                }

                if (!foundCurrent) {
                    root.wifiConnected = false
                    root.wifiSignal = 0
                    root.wifiSsid = ""
                }

                // Sort by decreasing signal strength with the active connection first.
                const list = Object.values(bySsid)
                list.sort((a, b) => {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
                    return b.signal - a.signal
                })
                root.wifiNetworks = list
            }
        }
    }
    // Read Wi-Fi radio state with nmcli radio wifi.
    Process {
        id: wifiRadioProc
        command: ["nmcli", "-t", "-f", "WIFI", "g"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = this.text.trim().toLowerCase() === "enabled"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiProc.running = true
            wifiRadioProc.running = true
        }
    }

    // Refresh once when the popup opens.
    function refreshWifi(): void {
        wifiProc.running = true
        wifiRadioProc.running = true
    }

    property string wifiMessage: ""
    property string bluetoothMessage: ""

    function scanWifi(): void {
        wifiScan.running = true
    }

    Process {
        id: wifiScan
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: code => {
            root.wifiMessage = code === 0 ? "" : "Wi-Fi scan failed"
            root.refreshWifi()
        }
    }

    function connectWifi(ssid: string, secured: bool): void {
        if (wifiConnect.running) return
        wifiConnect.ssid = ssid
        wifiConnect.secured = secured
        root.wifiMessage = "Connecting to " + ssid
        wifiConnect.command = ["nmcli", "--wait", "20", "device", "wifi", "connect", ssid]
        wifiConnect.running = true
    }

    function toggleWifi(): void {
        wifiToggle.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]
        wifiToggle.running = true
        root.wifiEnabled = !root.wifiEnabled  // Update local state immediately.
    }

    // Airplane mode disables both radios. Turning it off restores them.
    function toggleAirplaneMode(): void {
        const turningOn = !root.airplaneMode
        wifiToggle.command = ["nmcli", "radio", "wifi", turningOn ? "off" : "on"]
        wifiToggle.running = true
        airplaneBtProc.command = ["bluetoothctl", "power", turningOn ? "off" : "on"]
        airplaneBtProc.running = true
        root.wifiEnabled = !turningOn
        root.bluetoothPowered = !turningOn
    }

    Process {
        id: wifiConnect
        property string ssid
        property bool secured
        onExited: code => {
            if (code !== 0 && secured) {
                // Let NetworkManager request credentials on its own TTY.
                Quickshell.execDetached(["wezterm", "start", "--", "nmcli", "--ask",
                                         "device", "wifi", "connect", ssid])
                root.wifiMessage = "Complete the connection in WezTerm"
            } else {
                root.wifiMessage = code === 0 ? "" : "Connection failed: " + ssid
            }
            root.refreshWifi()
        }
    }
    Process {
        id: wifiToggle
        onExited: code => {
            root.wifiMessage = code === 0 ? "" : "Wi-Fi radio change failed"
            root.refreshWifi()
        }
    }
    Process {
        id: airplaneBtProc
        onExited: code => {
            root.bluetoothMessage = code === 0 ? "" : "Bluetooth power change failed"
            root.refreshBluetooth()
        }
    }

    // ============ Bluetooth ============
    //
    // Bluetooth queries use bluetoothctl from bluez-utils. When it is unavailable,
    // the properties keep their defaults (false or zero) and the widget shows the off state.
    //
    // Three states:
    //   bluetoothPowered=false: powered off or bluez-utils unavailable.
    //   bluetoothPowered=true, conn=0: powered on with no connections.
    //   bluetoothConnected=true: at least one device is connected.

    property bool bluetoothPowered: false
    property bool bluetoothConnected: false
    property int bluetoothDeviceCount: 0
    // Paired devices for the Bluetooth popup
    // Each entry: { mac: string, name: string, connected: bool }
    property var bluetoothDevices: []

    Process {
        id: btShowProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Read "Powered: yes" or "Powered: no" from the output.
                root.bluetoothPowered = this.text.includes("Powered: yes")
            }
        }
    }

    // Read paired and connected devices in one shell command, separated by markers.
    Process {
        id: btDevsProc
        command: ["sh", "-c", "echo '###paired'; bluetoothctl devices Paired; echo '###connected'; bluetoothctl devices Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const pairedSec = text.match(/###paired\n([\s\S]*?)\n###connected/)
                const connSec = text.match(/###connected\n([\s\S]*)/)

                const paired = []
                const connectedMacs = ({})

                if (pairedSec) {
                    for (const line of pairedSec[1].split("\n")) {
                        const m = line.match(/^Device (\S+) (.+)$/)
                        if (m) paired.push({ mac: m[1], name: m[2] })
                    }
                }
                if (connSec) {
                    for (const line of connSec[1].split("\n")) {
                        const m = line.match(/^Device (\S+) /)
                        if (m) connectedMacs[m[1]] = true
                    }
                }

                const devices = paired.map(d => ({
                    mac: d.mac,
                    name: d.name,
                    connected: !!connectedMacs[d.mac]
                }))
                // Sort connected devices first, then by name.
                devices.sort((a, b) => {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    return a.name.localeCompare(b.name)
                })

                const connCount = Object.keys(connectedMacs).length
                root.bluetoothDevices = devices
                root.bluetoothDeviceCount = connCount
                root.bluetoothConnected = connCount > 0
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            btShowProc.running = true
            btDevsProc.running = true
        }
    }

    function refreshBluetooth(): void {
        btShowProc.running = true
        btDevsProc.running = true
    }

    function toggleBluetooth(): void {
        btToggle.command = [
            "bluetoothctl", "power", root.bluetoothPowered ? "off" : "on"
        ]
        btToggle.running = true
        root.bluetoothPowered = !root.bluetoothPowered  // Update local state immediately.
    }

    function connectBluetoothDevice(mac: string): void {
        if (btConnect.running) return
        root.bluetoothMessage = "Connecting…"
        btConnect.command = ["bluetoothctl", "--timeout", "25", "connect", mac]
        btConnect.running = true
    }

    function disconnectBluetoothDevice(mac: string): void {
        if (btConnect.running) return
        root.bluetoothMessage = "Disconnecting…"
        btConnect.command = ["bluetoothctl", "--timeout", "25", "disconnect", mac]
        btConnect.running = true
    }

    Process {
        id: btToggle
        onExited: code => {
            root.bluetoothMessage = code === 0 ? "" : "Bluetooth power change failed"
            root.refreshBluetooth()
        }
    }
    Process {
        id: btConnect
        onExited: code => {
            root.bluetoothMessage = code === 0 ? "" : "Device connection change failed"
            root.refreshBluetooth()
        }
    }

    // ============ Volume ============

    property real volume: 0             // 0.0 - 1.0
    property bool volumeMuted: false
    readonly property int volumePercent: Math.round(root.volume * 100)
    readonly property bool volumeSilent: root.volumeMuted || root.volumePercent === 0
    readonly property string volumeIcon: root.volumeSilent ? "volume_off"
                                       : root.volumePercent < 34 ? "volume_down" : "volume_up"

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Expected output: "Volume: 0.40" or "Volume: 0.40 [MUTED]"
                const m = this.text.match(/Volume:\s*([0-9.]+)(\s*\[MUTED\])?/)
                if (m) {
                    root.volume = parseFloat(m[1])
                    root.volumeMuted = !!m[2]
                }
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: volProc.running = true
    }

    function setVolumeDelta(stepPercent: int): void {
        // Relative adjustment for scrolling the bar widget
        const sign = stepPercent >= 0 ? "+" : "-"
        const mag = Math.abs(stepPercent)
        volStep.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${mag}%${sign}`]
        volStep.running = true
        const next = Math.max(0, Math.min(1, root.volume + stepPercent / 100))
        root.volume = next
    }

    function setVolume(absolute: real): void {
        // Absolute value in [0, 1] for dragging the slider
        const p = Math.max(0, Math.min(1, absolute))
        volSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(p)]
        volSet.running = true
        root.volume = p
    }

    function toggleMute(): void {
        volMute.running = true
        root.volumeMuted = !root.volumeMuted
    }

    Process { id: volStep }
    Process { id: volSet }
    Process {
        id: volMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    }

    // ============ Audio output devices (sinks) ============
    //
    // Read the default sink and sink list together with pactl for the popup.
    // Each entry: { id, name, description, isDefault }
    property var audioSinks: []
    property string defaultSinkName: ""

    Process {
        id: audioSinksProc
        command: ["sh", "-c", "pactl get-default-sink; echo '###sinks###'; pactl list sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sections = this.text.split("###sinks###")
                if (sections.length < 2) return
                const defaultName = sections[0].trim()
                const sinksText = sections[1]

                const sinks = []
                // Split pactl list sinks into blocks beginning with Sink #N.
                const blocks = sinksText.split(/^Sink #/m).slice(1)
                for (const block of blocks) {
                    const idMatch = block.match(/^(\d+)/)
                    const nameMatch = block.match(/\n\s*Name:\s+(\S+)/)
                    const descMatch = block.match(/\n\s*Description:\s+(.+)/)
                    if (idMatch && nameMatch) {
                        const sinkName = nameMatch[1].trim()
                        sinks.push({
                            id: parseInt(idMatch[1]),
                            name: sinkName,
                            description: descMatch ? descMatch[1].trim() : sinkName,
                            isDefault: sinkName === defaultName
                        })
                    }
                }
                // Sort the default sink first, then by description.
                sinks.sort((a, b) => {
                    if (a.isDefault !== b.isDefault) return a.isDefault ? -1 : 1
                    return a.description.localeCompare(b.description)
                })
                root.audioSinks = sinks
                root.defaultSinkName = defaultName
            }
        }
    }

    Timer {
        interval: 10000  // Sink changes are infrequent. Poll every ten seconds.
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: audioSinksProc.running = true
    }

    function refreshAudio(): void {
        audioSinksProc.running = true
        volProc.running = true
    }

    function setDefaultSink(sinkName: string): void {
        setDefaultSinkProc.command = ["pactl", "set-default-sink", sinkName]
        setDefaultSinkProc.running = true
        // Update local state immediately.
        root.defaultSinkName = sinkName
        root.audioSinks = root.audioSinks.map(s => ({
            id: s.id, name: s.name, description: s.description,
            isDefault: s.name === sinkName
        }))
    }

    Process { id: setDefaultSinkProc }

    // ============ Per-output brightness ============
    //
    // Internal eDP/LVDS/DSI panels use brightnessctl and /sys/class/backlight for fast reads.
    // External displays use ddcutil over I2C/DDC-CI. Access needs the i2c group or a udev rule and takes 1-3 s per call.
    //
    // brightnessByScreen maps output names to values, for example {"eDP-1": 0.85, "DP-2": 0.50}.
    // Read the value for PopupManager.currentScreen.name.
    property var brightnessByScreen: ({})

    function brightnessBackendFor(screenName: string): string {
        return /^(eDP|LVDS|DSI)/i.test(screenName) ? "brightnessctl" : "ddcutil"
    }

    function fetchBrightnessFor(screenName: string): void {
        if (!screenName) return
        const backend = root.brightnessBackendFor(screenName)
        if (backend === "brightnessctl") {
            brightnessctlRead._target = screenName
            brightnessctlRead.running = true
        } else {
            ddcutilRead._target = screenName
            ddcutilRead.running = true
        }
    }

    function setBrightnessFor(screenName: string, value: real): void {
        if (!screenName) return
        const v = Math.max(0.05, Math.min(1, value))
        const backend = root.brightnessBackendFor(screenName)
        // Update the slider immediately. Schedule the hardware write according to its backend.
        const next = Object.assign({}, root.brightnessByScreen)
        next[screenName] = v
        root.brightnessByScreen = next

        if (backend === "brightnessctl") {
            // Internal writes are fast enough to send immediately.
            brightnessctlSet.command = ["brightnessctl", "s", `${Math.round(v * 100)}%`, "-q"]
            brightnessctlSet.running = true
        } else {
            // External I2C/DDC calls can take 1-3 seconds. Queuing a call per drag event would build up a backlog.
            // Debounce for 250 ms and send only the final value.
            root._pendingBrightnessValue = v
            root._pendingBrightnessScreen = screenName
            ddcutilDebounce.restart()
        }
    }

    property real _pendingBrightnessValue: -1
    property string _pendingBrightnessScreen: ""
    Timer {
        id: ddcutilDebounce
        interval: 250
        repeat: false
        onTriggered: {
            if (!root._pendingBrightnessScreen) return
            ddcutilSet.command = [
                "ddcutil", "setvcp", "10",
                String(Math.round(root._pendingBrightnessValue * 100)),
                "--noverify",                 // Skip read-back verification to save an I2C round trip.
                "--sleep-multiplier=0.1"      // Use a tenth of ddcutil's conservative default sleep interval.
            ]
            ddcutilSet.running = true
        }
    }

    Process {
        id: brightnessctlRead
        property string _target: ""
        command: ["sh", "-c", "echo $(brightnessctl g):$(brightnessctl m)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(":")
                const cur = parseInt(parts[0])
                const max = parseInt(parts[1])
                if (!isNaN(cur) && !isNaN(max) && max > 0 && brightnessctlRead._target) {
                    const next = Object.assign({}, root.brightnessByScreen)
                    next[brightnessctlRead._target] = cur / max
                    root.brightnessByScreen = next
                }
            }
        }
    }

    Process {
        id: ddcutilRead
        property string _target: ""
        command: ["sh", "-c", "ddcutil --terse --sleep-multiplier=0.1 getvcp 10 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // ddcutil --terse getvcp 10 returns values like "VCP 10 C 75 100" (code, type, current, maximum).
                const m = this.text.trim().match(/VCP\s+\S+\s+\S+\s+(\d+)\s+(\d+)/)
                if (m && ddcutilRead._target) {
                    const cur = parseInt(m[1])
                    const max = parseInt(m[2])
                    if (max > 0) {
                        const next = Object.assign({}, root.brightnessByScreen)
                        next[ddcutilRead._target] = cur / max
                        root.brightnessByScreen = next
                    }
                }
            }
        }
    }

    Process { id: brightnessctlSet }
    Process { id: ddcutilSet }

    // Poll the internal backlight to reflect brightness changes from function keys.
    // Avoid polling the slower external DDC backend.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const sc = Quickshell.screens[i]
                if (root.brightnessBackendFor(sc.name) === "brightnessctl") {
                    root.fetchBrightnessFor(sc.name)
                    break  // One brightnessctl call covers the internal backlight.
                }
            }
        }
    }

    // Prefetch external brightness at startup so opening the popup can use the cache.
    // DDC transactions occupy the I2C bus and may briefly contend with display updates.
    //  Delay the prefetch by one second to let niri and Quickshell settle.
    Component.onCompleted: externalBrightnessPrefetch.start()
    Timer {
        id: externalBrightnessPrefetch
        interval: 1000
        repeat: false
        onTriggered: {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const sc = Quickshell.screens[i]
                if (root.brightnessBackendFor(sc.name) !== "brightnessctl") {
                    root.fetchBrightnessFor(sc.name)
                }
            }
        }
    }
}
