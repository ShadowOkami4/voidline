import QtQuick
import qs.core

// M3 icon button. `tonal` gives it a filled container; `selected` switches to
// the primary container and a filled glyph.
Pressable {
    id: root

    property string icon: ""
    property int size: 36
    property int iconSize: Math.round(size * 0.55)
    property bool tonal: false

    implicitWidth: size
    implicitHeight: size
    color: selected ? Theme.primaryContainer : (tonal ? Theme.surfaceContainerHighest : "transparent")
    tint: selected ? Theme.inkOnPrimaryContainer : Theme.ink
    restRadius: selected ? Theme.cornerL : Theme.cornerFull
    Behavior on color { Tint {} }

    MIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        filled: root.selected
        color: root.selected ? Theme.inkOnPrimaryContainer : Theme.inkMuted
    }
}
