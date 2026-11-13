import QtQuick
import qs.core

// M3 Expressive slider: thick track, inset icon, a thin handle that narrows
// while dragging, and a gap between the active and inactive track.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property color accent: Theme.primary
    signal moved(real value)

    implicitHeight: 44
    implicitWidth: 240

    readonly property real handleW: area.pressed ? 2 : 4
    readonly property real gap: 6
    readonly property real pos: Math.max(0, Math.min(1, value)) * (width - handleW)

    Rectangle {
        id: active
        height: parent.height
        width: Math.max(0, root.pos - root.gap)
        radius: Theme.cornerL
        topRightRadius: Theme.cornerXS
        bottomRightRadius: Theme.cornerXS
        color: root.accent
        clip: true

        MIcon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: 20
            color: Theme.inkOnPrimary
            opacity: active.width > 40 ? 1 : 0
            Behavior on opacity { Fade {} }
        }
    }

    Rectangle {
        x: root.pos + root.handleW + root.gap
        width: Math.max(0, parent.width - x)
        height: parent.height
        radius: Theme.cornerL
        topLeftRadius: Theme.cornerXS
        bottomLeftRadius: Theme.cornerXS
        color: Theme.secondaryContainer
    }

    Rectangle {
        x: root.pos
        y: -4
        width: root.handleW
        height: parent.height + 8
        radius: 2
        color: root.accent
        Behavior on width { Spring {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function apply(mouseX) { root.moved(Math.max(0, Math.min(1, mouseX / width))) }
        onPressed: mouse => apply(mouse.x)
        onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
