import QtQuick

// Scalloped shape, painted once and then only moved (cheap to animate).
Canvas {
    id: root
    property color fill: "#8E6BFF"
    property int lobes: 8
    property real depth: 0.08
    antialiasing: true
    onFillChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const c = width / 2, base = width / 2
        ctx.fillStyle = fill
        ctx.beginPath()
        for (let i = 0; i <= 120; ++i) {
            const a = i / 120 * Math.PI * 2
            const r = base * (1 - depth + depth * Math.cos(lobes * a))
            if (i === 0) ctx.moveTo(c + r * Math.cos(a), c + r * Math.sin(a))
            else ctx.lineTo(c + r * Math.cos(a), c + r * Math.sin(a))
        }
        ctx.closePath()
        ctx.fill()
    }
}
