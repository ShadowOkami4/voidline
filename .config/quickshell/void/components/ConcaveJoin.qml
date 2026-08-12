import QtQuick
import "../core"

Canvas {
    id: root

    // The canonical curve is the existing top-left bar-to-panel join.
    // Mirroring it produces every other edge orientation without changing
    // the radius or curve character.
    property string orientation: "top-left"
    property color fillColor: Theme.panel
    readonly property bool mirrorX: orientation === "top-right"
        || orientation === "bottom-right"
        || orientation === "left-top"
        || orientation === "left-bottom"
    readonly property bool mirrorY: orientation === "bottom-left"
        || orientation === "bottom-right"
        || orientation === "left-top"
        || orientation === "right-top"
    readonly property real curve: 0.5522847498

    implicitWidth: Theme.concaveRadius
    implicitHeight: Theme.concaveRadius
    antialiasing: true

    function mappedX(value) {
        return mirrorX ? width - value : value
    }

    function mappedY(value) {
        return mirrorY ? height - value : value
    }

    onOrientationChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const context = getContext("2d")
        context.reset()
        context.fillStyle = root.fillColor
        context.beginPath()
        context.moveTo(mappedX(0), mappedY(0))
        context.lineTo(mappedX(width), mappedY(0))
        context.lineTo(mappedX(width), mappedY(height))
        context.bezierCurveTo(
            mappedX(width), mappedY(height * (1 - curve)),
            mappedX(width * curve), mappedY(0),
            mappedX(0), mappedY(0))
        context.closePath()
        context.fill()
    }
}
