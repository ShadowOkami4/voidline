import QtQuick
import "../core"

Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property bool enabled: true
    property bool muted: false
    property bool iconInteractive: true
    property string icon: "volume_up"
    property color activeColor: Theme.accent
    signal moved(real value)
    signal iconClicked

    readonly property real normalized: Math.max(0, Math.min(1, (value - from) / Math.max(0.001, to - from)))
    readonly property real displayedVolume: muted ? 0 : normalized
    implicitHeight: 52
    opacity: enabled ? 1 : 0.4
    scale: dragArea.pressed || iconArea.pressed ? 0.994 : 1

    function updateAt(position) {
        const fraction = Math.max(0, Math.min(1, position / Math.max(1, dragArea.width)))
        moved(from + fraction * (to - from))
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceHigh
    }

    Rectangle {
        id: iconButton
        anchors {
            left: parent.left
            leftMargin: 4
            verticalCenter: parent.verticalCenter
        }
        width: 44
        height: 44
        radius: 22
        color: iconArea.pressed ? root.activeColor : Theme.surfaceHover

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MaterialIcon {
        anchors.centerIn: iconButton
        text: root.icon
        size: iconArea.pressed ? 21 : 23
        color: iconArea.pressed ? Theme.accentInk : (root.muted ? Theme.textMuted : Theme.text)

        Behavior on size { NumberAnimation { duration: Motion.instant } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Rectangle {
        id: rail
        anchors {
            left: iconButton.right
            leftMargin: 10
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        height: 12
        radius: 6
        color: Theme.outlineSoft
        clip: true

        Rectangle {
            property real visualValue: root.displayedVolume

            width: visualValue <= 0 ? 0 : Math.max(3, parent.width * visualValue)
            height: parent.height
            radius: Math.min(height / 2, width / 2)
            color: root.activeColor

            Behavior on visualValue {
                enabled: !dragArea.pressed
                NumberAnimation { duration: Motion.fast; easing.type: Motion.standardCurve }
            }
        }
    }

    MouseArea {
        id: iconArea
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 52
        enabled: root.enabled && root.iconInteractive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.iconClicked()
    }

    MouseArea {
        id: dragArea
        anchors {
            left: rail.left
            right: rail.right
            top: parent.top
            bottom: parent.bottom
        }
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.updateAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.updateAt(mouse.x)
        }
    }

    Behavior on scale { NumberAnimation { duration: Motion.instant } }
}
