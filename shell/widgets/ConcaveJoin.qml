import QtQuick
import qs.core

// The Voidline signature: an inverted corner that lets two surfaces flow into
// each other. `corner` names the solid corner of the square: "tl" "tr" "bl" "br".
Canvas {
    id: root

    property string corner: "tl"
    property color fill: Theme.surfaceContainerLow

    implicitWidth: Style.frameRadius
    implicitHeight: Style.frameRadius
    antialiasing: true

    onCornerChanged: requestPaint()
    onFillChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        // Draw the "tl" shape, mirrored as needed.
        ctx.translate(corner[1] === "r" ? width : 0, corner[0] === "b" ? height : 0)
        ctx.scale(corner[1] === "r" ? -1 : 1, corner[0] === "b" ? -1 : 1)
        ctx.fillStyle = fill
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(width, 0)
        ctx.arc(width, height, width, -Math.PI / 2, Math.PI, true)
        ctx.lineTo(0, 0)
        ctx.closePath()
        ctx.fill()
    }
}
