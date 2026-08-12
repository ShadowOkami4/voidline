import QtQuick
import "../core"

Item {
    id: root

    property string icon: ""
    property string accessibleName: ""
    property bool active: false
    property int size: 34
    signal clicked

    implicitWidth: size
    implicitHeight: size
    scale: tap.pressed ? 0.93 : 1

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.active ? Theme.surfaceActive : (hover.hovered ? Theme.surfaceHover : "transparent")

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        size: 19
        color: root.active ? Theme.accent : Theme.textMuted
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        onTapped: root.clicked()
    }

    Behavior on scale {
        NumberAnimation { duration: Motion.instant; easing.type: Motion.standardCurve }
    }
}
