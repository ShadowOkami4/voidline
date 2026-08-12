import QtQuick
import "../core"

Item {
    id: root

    property var primaryValues: []
    property var secondaryValues: []
    property color primaryColor: Theme.accent
    property color secondaryColor: Theme.tertiary

    onPrimaryValuesChanged: graph.requestPaint()
    onSecondaryValuesChanged: graph.requestPaint()
    onPrimaryColorChanged: graph.requestPaint()
    onSecondaryColorChanged: graph.requestPaint()

    Canvas {
        id: graph
        anchors.fill: parent
        antialiasing: true

        function drawSeries(context, values, color, fill) {
            if (!values || values.length < 2)
                return

            const step = width / Math.max(1, values.length - 1)
            context.beginPath()
            for (let index = 0; index < values.length; ++index) {
                const x = index * step
                const y = height - Math.max(0, Math.min(100, values[index])) / 100 * (height - 10) - 5
                if (index === 0)
                    context.moveTo(x, y)
                else
                    context.lineTo(x, y)
            }

            if (fill) {
                context.lineTo(width, height)
                context.lineTo(0, height)
                context.closePath()
                context.globalAlpha = 0.13
                context.fillStyle = color
                context.fill()
                context.globalAlpha = 1
            }

            context.beginPath()
            for (let row = 0; row < values.length; ++row) {
                const lineX = row * step
                const lineY = height - Math.max(0, Math.min(100, values[row])) / 100 * (height - 10) - 5
                if (row === 0)
                    context.moveTo(lineX, lineY)
                else
                    context.lineTo(lineX, lineY)
            }
            context.strokeStyle = color
            context.lineWidth = 2.5
            context.lineJoin = "round"
            context.lineCap = "round"
            context.stroke()
        }

        onPaint: {
            const context = getContext("2d")
            context.reset()
            context.strokeStyle = Theme.outlineSoft
            context.globalAlpha = 0.22
            context.lineWidth = 1
            for (let index = 1; index < 4; ++index) {
                const y = height * index / 4
                context.beginPath()
                context.moveTo(0, y)
                context.lineTo(width, y)
                context.stroke()
            }
            context.globalAlpha = 1
            drawSeries(context, root.primaryValues, root.primaryColor, true)
            drawSeries(context, root.secondaryValues, root.secondaryColor, false)
        }
    }
}
