import QtQuick
import "../core"

Text {
    property int size: 20

    color: Theme.text
    font.family: Theme.symbolFont
    font.pixelSize: size
    font.weight: Font.Normal
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
