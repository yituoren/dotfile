pragma ComponentBehavior: Bound

import QtQuick

Canvas {
    id: root

    required property var samples
    required property color fill
    readonly property int bands: 12
    property var levels: Array(bands).fill(0)
    readonly property var targets: {
        const result = []
        for (let i = 0; i < bands; ++i) {
            const first = Math.floor(i * samples.length / bands)
            const end = Math.floor((i + 1) * samples.length / bands)
            let sum = 0
            for (let j = first; j < end; ++j)
                sum += samples[j] * samples[j]
            const rms = Math.sqrt(sum / Math.max(1, end - first))
            // Taper both ends. Each quiet frequency band recedes to the bottom edge of the bar.
            const edge = Math.min(1, (i + 1) / 3, (bands - i) / 3)
            result.push(Math.max(0, (rms - 0.025) / 0.975) * edge * edge * (3 - 2 * edge))
        }
        return result
    }

    FrameAnimation {
        running: root.visible && root.targets.some((v, i) => v !== root.levels[i])
        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            const rise = 1 - Math.exp(-dt / 0.055)
            const fall = 1 - Math.exp(-dt / 0.145)
            root.levels = root.levels.map((v, i) => {
                const target = root.targets[i]
                const delta = target - v
                return Math.abs(delta) < 0.001 ? target : v + delta * (delta > 0 ? rise : fall)
            })
        }
    }

    onVisibleChanged: {
        if (!visible) levels = Array(bands).fill(0)
    }
    onLevelsChanged: requestPaint()
    onFillChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!levels.some(v => v > 0)) return

        // Connect the midpoints between control points with quadratic curves and meet the bar horizontally.
        const baseline = 0
        const step = width / (bands + 3)
        let x = step
        let y = baseline
        ctx.beginPath()
        ctx.moveTo(0, baseline)
        for (let i = 0; i <= bands; ++i) {
            const nextX = (i + 2) * step
            const nextY = baseline + (i < bands ? levels[i] * (height - 2) : 0)
            ctx.quadraticCurveTo(x, y, (x + nextX) / 2, (y + nextY) / 2)
            x = nextX
            y = nextY
        }
        ctx.quadraticCurveTo(x, y, width, baseline)
        ctx.lineTo(width, 0)
        ctx.lineTo(0, 0)
        ctx.closePath()
        ctx.fillStyle = fill
        ctx.fill()
    }
}
