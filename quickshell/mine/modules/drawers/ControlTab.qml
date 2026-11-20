pragma ComponentBehavior: Bound

// ControlTab —— dashboard "Control" tab
//
// The btop-style panel uses fixed positions and theme colors. Dimensions target a 600 px popup
// with 520 px of content and 16 px of padding between sections.
//
//   y 16-44     header strip       h 28    uptime / load / CPU temp
//   y 60-244: two columns of three 60 px metric rows with two 4 px gaps (184 px total).
//   y 260-360: CPU and GPU charts, each 390 px wide and 100 px tall.
//   y 376-496: network section with two 42 px throughput plots.
//
// An 860 px content area with 28 px side margins leaves 804 px.
//         Columns start at x = 28 and 442, each 390 px wide with a 24 px gap.

import QtQuick
import qs.services

Item {
    id: root

    Component.onCompleted: SysMonitor.enabled = true
    Component.onDestruction: SysMonitor.enabled = false

    readonly property bool hasData:
        SysMonitor.cpuPerCore.length > 0 || SysMonitor.memTotalGB > 0

    // =============== Text helpers ===============
    function shortCpu(s: string): string {
        return s.replace(/\(R\)|\(TM\)|\bCPU\b|\bProcessor\b/g, "")
            .replace(/\s+/g, " ").trim()
    }
    function shortGpu(s: string): string {
        return s.replace(/NVIDIA |GeForce /g, "").trim()
    }

    // =============== Data model ===============
    readonly property var leftMetrics: {
        const out = []
        out.push({
            icon: "memory",
            label: "CPU",
            pct: SysMonitor.cpuUsage,
            value: (SysMonitor.cpuTempC > 0
                ? Math.round(SysMonitor.cpuTempC) + "°C"
                : "—"),
            spec: SysMonitor.cpuModel
                ? root.shortCpu(SysMonitor.cpuModel) + " · " + SysMonitor.cpuPerCore.length + " cores"
                : SysMonitor.cpuPerCore.length + " cores"
        })
        out.push({
            icon: "developer_board",
            label: "RAM",
            pct: SysMonitor.memUsagePct,
            value: SysMonitor.memUsedGB.toFixed(1) + "/" + SysMonitor.memTotalGB.toFixed(1) + " GB",
            spec: SysMonitor.memTotalGB.toFixed(0) + " GB total"
        })
        // First disk
        if (SysMonitor.diskMounts.length > 0) {
            const d = SysMonitor.diskMounts[0]
            out.push({
                icon: "hard_drive",
                label: d.mount,
                pct: d.pct,
                value: d.usedGB.toFixed(0) + "/" + d.totalGB.toFixed(0) + " GB",
                spec: "Filesystem " + d.totalGB.toFixed(0) + " GB"
            })
        }
        return out
    }

    readonly property var rightMetrics: {
        const out = []
        if (SysMonitor.gpuName) {
            out.push({
                icon: "deployed_code",
                label: "GPU",
                pct: SysMonitor.gpuUsage,
                value: SysMonitor.gpuTempC > 0
                    ? Math.round(SysMonitor.gpuTempC) + "°C"
                    : "—",
                spec: root.shortGpu(SysMonitor.gpuName)
            })
            out.push({
                icon: "auto_awesome_mosaic",
                label: "VRAM",
                pct: SysMonitor.gpuMemTotalGB > 0
                    ? SysMonitor.gpuMemUsedGB / SysMonitor.gpuMemTotalGB
                    : 0,
                value: SysMonitor.gpuMemUsedGB.toFixed(1) + "/" + SysMonitor.gpuMemTotalGB.toFixed(1) + " GB",
                spec: SysMonitor.gpuMemTotalGB.toFixed(0) + " GB GDDR"
            })
        }
        if (SysMonitor.swapTotalGB > 0) {
            out.push({
                icon: "swap_horiz",
                label: "Swap",
                pct: SysMonitor.swapTotalGB > 0
                    ? SysMonitor.swapUsedGB / SysMonitor.swapTotalGB
                    : 0,
                value: SysMonitor.swapUsedGB.toFixed(1) + "/" + SysMonitor.swapTotalGB.toFixed(1) + " GB",
                spec: SysMonitor.swapTotalGB.toFixed(0) + " GB swap"
            })
        }
        // Additional disks
        for (let i = 1; i < SysMonitor.diskMounts.length && out.length < 3; i++) {
            const d = SysMonitor.diskMounts[i]
            out.push({
                icon: "hard_drive",
                label: d.mount,
                pct: d.pct,
                value: d.usedGB.toFixed(0) + "/" + d.totalGB.toFixed(0) + " GB",
                spec: "Filesystem " + d.totalGB.toFixed(0) + " GB"
            })
        }
        return out
    }

    // =============== Loading placeholder ===============
    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: !root.hasData

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "memory"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 48
            color: Theme.colors.on_surface_variant
            opacity: 0.45
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Loading system stats…"
            color: Theme.colors.on_surface_variant
            opacity: 0.6
            font.family: "Maple Mono NF CN"
            font.pixelSize: 13
            font.styleName: "Medium"
        }
    }

    // ═══════════════ Header strip (y 16, h 28) ═══════════════
    Item {
        x: 28
        y: 16
        width: 804
        height: 28
        visible: root.hasData

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Row {
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "schedule"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.colors.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Uptime"
                    color: Theme.colors.on_surface_variant
                    opacity: 0.7
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Medium"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SysMonitor.uptimeStr
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "ExtraBold"
                }
            }

            Row {
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "speed"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.colors.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Load"
                    color: Theme.colors.on_surface_variant
                    opacity: 0.7
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Medium"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SysMonitor.load1.toFixed(2) + "  "
                        + SysMonitor.load5.toFixed(2) + "  "
                        + SysMonitor.load15.toFixed(2)
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "ExtraBold"
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "device_thermostat"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: SysMonitor.cpuTempC > 80
                    ? Theme.colors.error
                    : Theme.colors.on_surface_variant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitor.cpuTempC > 0
                    ? Math.round(SysMonitor.cpuTempC) + "°C"
                    : "—"
                color: Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 13
                font.styleName: "ExtraBold"
            }
        }
    }

    // =============== Reusable metric row ===============
    // A 60 px row contains a 36 px main line, a 4 px gap and a 20 px detail line.
    // Layout within the 390 px column:
    //   icon 22 / gap 6 / label 56 / gap 6 / % 44 / gap 6 / bar 168 / gap 6 / right 76
    component MetricRow: Item {
        id: row
        property var metric: ({})
        width: 390
        height: 60

        // Main line
        Item {
            x: 0
            y: 0
            width: 390
            height: 36

            Text {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: row.metric.icon ?? ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: Theme.colors.on_surface_variant
            }
            Text {
                x: 28
                width: 56
                anchors.verticalCenter: parent.verticalCenter
                text: row.metric.label ?? ""
                color: Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 14
                font.styleName: "ExtraBold"
                elide: Text.ElideRight
            }
            Text {
                x: 90
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round((row.metric.pct ?? 0) * 100) + "%"
                color: (row.metric.pct ?? 0) > 0.85
                    ? Theme.colors.error
                    : Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 16
                font.styleName: "ExtraBold"
                horizontalAlignment: Text.AlignRight
            }
            Rectangle {
                x: 140
                anchors.verticalCenter: parent.verticalCenter
                width: 168
                height: 12
                radius: 6
                color: Theme.colors.surface_container_high
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, row.metric.pct ?? 0))
                    radius: 6
                    color: (row.metric.pct ?? 0) > 0.85
                        ? Theme.colors.error
                        : Theme.colors.primary
                }
            }
            Text {
                x: 314
                width: 76
                anchors.verticalCenter: parent.verticalCenter
                text: row.metric.value ?? ""
                color: Theme.colors.on_surface_variant
                font.family: "Maple Mono NF CN"
                font.pixelSize: 12
                font.styleName: "Medium"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        // Detail line
        Text {
            x: 28
            y: 40
            width: 362
            height: 20
            text: row.metric.spec ?? ""
            color: Theme.colors.on_surface_variant
            opacity: 0.6
            font.family: "Maple Mono NF CN"
            font.pixelSize: 11
            font.styleName: "Medium"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    // =============== Left metrics (x 28, y 60) ===============
    // Three 60 px rows at a 64 px pitch use 184 px.
    Repeater {
        model: root.leftMetrics
        delegate: MetricRow {
            required property var modelData
            required property int index
            metric: modelData
            x: 28
            y: 60 + index * 64
            visible: root.hasData
        }
    }

    // =============== Right metrics (x 442, y 60) ===============
    Repeater {
        model: root.rightMetrics
        delegate: MetricRow {
            required property var modelData
            required property int index
            metric: modelData
            x: 442
            y: 60 + index * 64
            visible: root.hasData
        }
    }

    // =============== Reusable history chart ===============
    component HistoryGraph: Item {
        id: graph
        property var values: []
        property color tint: Theme.colors.primary
        property string title: ""
        property string subtitle: ""
        property real maxVal: 1

        // Card background
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.colors.surface_container
        }

        // Heading
        Item {
            x: 14
            y: 8
            width: graph.width - 28
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: graph.title
                color: Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 11
                font.styleName: "ExtraBold"
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: graph.subtitle
                color: Theme.colors.on_surface_variant
                opacity: 0.7
                font.family: "Maple Mono NF CN"
                font.pixelSize: 10
                font.styleName: "ExtraBold"
            }
        }

        // Chart canvas
        Canvas {
            id: canv
            x: 8
            y: 30
            width: graph.width - 16
            height: graph.height - 38
            contextType: "2d"

            property var src: graph.values
            property color tnt: graph.tint
            property real mx: graph.maxVal
            onSrcChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const v = canv.src
                const n = v.length
                if (n < 2) return
                const pts = []
                const m = canv.mx > 0 ? canv.mx : 1
                for (let i = 0; i < n; i++) {
                    const x = (i / Math.max(1, n - 1)) * width
                    const y = height - (v[i] / m) * height
                    pts.push({ x: x, y: y })
                }
                const c = canv.tnt
                const grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.40).toString())
                grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0).toString())
                ctx.fillStyle = grad
                ctx.beginPath()
                ctx.moveTo(pts[0].x, height)
                ctx.lineTo(pts[0].x, pts[0].y)
                for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                ctx.lineTo(pts[n - 1].x, height)
                ctx.closePath()
                ctx.fill()
                ctx.strokeStyle = c.toString()
                ctx.lineWidth = 1.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                ctx.stroke()
            }
        }
    }

    // =============== CPU chart (lower left, y 260, h 100) ===============
    HistoryGraph {
        x: 28
        y: 260
        width: 390
        height: 100
        visible: root.hasData
        title: "CPU usage"
        subtitle: Math.round(SysMonitor.cpuUsage * 100) + "%"
        tint: Theme.colors.primary
        values: SysMonitor.cpuHistory
        maxVal: 1
    }

    // =============== GPU chart (lower right) ===============
    HistoryGraph {
        x: 442
        y: 260
        width: 390
        height: 100
        visible: root.hasData && SysMonitor.gpuName !== ""
        title: "GPU usage"
        subtitle: Math.round(SysMonitor.gpuUsage * 100) + "%"
        tint: Theme.colors.primary
        values: SysMonitor.gpuHistory
        maxVal: 1
    }

    // =============== Network section (y 376, h 120) ===============
    Item {
        x: 28
        y: 376
        width: 804
        height: 120
        visible: root.hasData

        Rectangle {
            x: 0
            y: 0
            width: 804
            height: 1
            color: Theme.colors.surface_container_high
        }
        Text {
            x: 0
            y: 4
            height: 20
            text: "Network"
            color: Theme.colors.on_surface
            font.family: "Maple Mono NF CN"
            font.pixelSize: 13
            font.styleName: "ExtraBold"
            verticalAlignment: Text.AlignVCenter
        }

        // Download row
        Item {
            x: 0
            y: 32
            width: 804
            height: 40

            Text {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_downward"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: Theme.colors.primary
            }
            Text {
                x: 32
                width: 150
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitor.fmtBps(SysMonitor.netRxBps)
                color: Theme.colors.primary
                font.family: "Maple Mono NF CN"
                font.pixelSize: 17
                font.styleName: "ExtraBold"
            }
            Canvas {
                id: rxCanvas
                x: 190
                y: 0
                width: 614
                height: 40
                contextType: "2d"
                property var values: SysMonitor.netRxHistory
                onValuesChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const v = rxCanvas.values
                    const n = v.length
                    if (n < 2) return
                    let mx = 0
                    for (let i = 0; i < n; i++) if (v[i] > mx) mx = v[i]
                    if (mx < 1024) mx = 1024
                    const c = Theme.colors.primary
                    const pts = []
                    for (let i = 0; i < n; i++) {
                        const x = (i / Math.max(1, n - 1)) * width
                        const y = height - (v[i] / mx) * height
                        pts.push({ x: x, y: y })
                    }
                    const grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.40).toString())
                    grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0).toString())
                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, height)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.lineTo(pts[n - 1].x, height)
                    ctx.closePath()
                    ctx.fill()
                    ctx.strokeStyle = c.toString()
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.stroke()
                }
            }
        }

        // Upload row
        Item {
            x: 0
            y: 78
            width: 804
            height: 40

            Text {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_upward"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: Theme.colors.primary
            }
            Text {
                x: 32
                width: 150
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitor.fmtBps(SysMonitor.netTxBps)
                color: Theme.colors.primary
                font.family: "Maple Mono NF CN"
                font.pixelSize: 17
                font.styleName: "ExtraBold"
            }
            Canvas {
                id: txCanvas
                x: 190
                y: 0
                width: 614
                height: 40
                contextType: "2d"
                property var values: SysMonitor.netTxHistory
                onValuesChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const v = txCanvas.values
                    const n = v.length
                    if (n < 2) return
                    let mx = 0
                    for (let i = 0; i < n; i++) if (v[i] > mx) mx = v[i]
                    if (mx < 1024) mx = 1024
                    const c = Theme.colors.primary
                    const pts = []
                    for (let i = 0; i < n; i++) {
                        const x = (i / Math.max(1, n - 1)) * width
                        const y = height - (v[i] / mx) * height
                        pts.push({ x: x, y: y })
                    }
                    const grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.40).toString())
                    grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0).toString())
                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, height)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.lineTo(pts[n - 1].x, height)
                    ctx.closePath()
                    ctx.fill()
                    ctx.strokeStyle = c.toString()
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.stroke()
                }
            }
        }
    }
}
