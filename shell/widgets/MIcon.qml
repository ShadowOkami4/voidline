import QtQuick
import qs.core

// Material Symbols glyph (variable font: fill and weight are animatable axes).
Text {
    property string icon: ""
    property int size: 20
    property bool filled: false

    text: icon
    color: Theme.ink
    font.family: Theme.iconFont
    font.pixelSize: size
    font.variableAxes: ({ FILL: filled ? 1 : 0, wght: 500, opsz: Math.max(20, Math.min(48, size)) })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    // Without the icon font the ligature name would render as a long word.
    visible: Theme.iconFontAvailable
    renderType: Text.NativeRendering
}
