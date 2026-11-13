import QtQuick
import qs.core

// Base for everything clickable: a shaped container with an M3 state layer.
// Expressive detail: the shape tightens while pressed (shape morph).
Rectangle {
    id: root

    property color tint: Theme.ink
    property int restRadius: Theme.cornerFull
    property int pressedRadius: Theme.cornerM
    property bool selected: false
    property bool enabledInput: true
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    property alias acceptedButtons: area.acceptedButtons
    property alias cursorShape: area.cursorShape

    signal clicked(var mouse)
    signal wheel(var wheel)

    color: "transparent"
    radius: Math.min(height / 2, pressed ? pressedRadius : restRadius)
    Behavior on radius { Spring {} }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.tint
        opacity: !root.enabledInput ? 0 : (root.pressed ? 0.14 : (root.hovered ? 0.08 : 0))
        Behavior on opacity { Fade { duration: Motion.effectsFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabledInput
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheel(wheel)
    }
}
