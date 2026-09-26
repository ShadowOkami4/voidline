import QtQuick
import "../core"

Text {
    property int size: 20
    // Material Symbols variable axes. Active and selected states use the
    // filled glyph (fill: 1), matching Material 3 Expressive icon states.
    property real fill: 0
    property int weight: 400

    color: Theme.text
    font.family: Theme.symbolFont
    font.pixelSize: size
    font.weight: Font.Normal
    font.variableAxes: ({ "FILL": fill, "wght": weight, "opsz": Math.max(20, Math.min(48, size)) })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
