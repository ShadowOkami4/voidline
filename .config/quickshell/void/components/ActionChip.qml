import QtQuick
import "../core"

Item {
    id: root

    property string label: ""
    property string icon: ""
    property bool active: false
    property bool available: true
    property color activeContainer: Theme.accentContainer
    property color activeContent: Theme.accent
    signal clicked

    implicitWidth: 70
    implicitHeight: Metrics.tileHeight
    opacity: available ? 1 : 0.42
    scale: tap.pressed ? 0.96 : 1

    Rectangle {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.min(70, root.width)
        height: Math.max(40, root.height - 19)
        radius: Metrics.tileRadius
        color: root.active ? root.activeContainer : (hover.hovered ? Theme.surfaceHigh : Theme.surfaceLow)

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            size: root.active ? Metrics.iconL : Metrics.iconM
            color: root.active ? root.activeContent : Theme.textMuted

            Behavior on size { NumberAnimation { duration: Motion.selectionPulse; easing.type: Motion.expressiveCurve } }
        }

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Text {
        anchors {
            bottom: parent.bottom
            bottomMargin: 1
            left: parent.left
            right: parent.right
        }
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.available
        onTapped: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Motion.instant } }
}
