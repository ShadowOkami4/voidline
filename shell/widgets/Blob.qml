import QtQuick
import qs.core

// Material 3 Expressive shape: a circle (lobes = 0), a soft polygon (3-5) or a
// scalloped "cookie" (6+). Painted once, repainted only when it changes.
Canvas {
    id: root

    property color fill: Theme.primaryContainer
    property int lobes: 0
    property real depth: lobes === 0 ? 0 : (lobes <= 5 ? 0.09 : 0.065)
    property real turn: 0
    property int size: 40

    implicitWidth: size
    implicitHeight: size
    antialiasing: true

    onFillChanged: requestPaint()
    onLobesChanged: requestPaint()
    onDepthChanged: requestPaint()
    onTurnChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const cx = width / 2, cy = height / 2, base = Math.min(width, height) / 2
        ctx.fillStyle = fill
        ctx.beginPath()
        if (lobes === 0) {
            ctx.arc(cx, cy, base, 0, Math.PI * 2)
        } else {
            const steps = 120
            for (let i = 0; i <= steps; ++i) {
                const a = i / steps * Math.PI * 2
                const r = base * (1 - depth + depth * Math.cos(lobes * a))
                const x = cx + r * Math.cos(a + turn), y = cy + r * Math.sin(a + turn)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
        }
        ctx.closePath()
        ctx.fill()
    }
}
