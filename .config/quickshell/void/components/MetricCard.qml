import QtQuick
import "../core"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property string detail: ""
    property real progress: -1
    property color containerColor: Theme.surface
    property color accentColor: Theme.accent

    implicitHeight: 82

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: root.containerColor
    }

    MaterialIcon {
        anchors {
            top: parent.top
            left: parent.left
            margins: 13
        }
        text: root.icon
        size: 19
        color: root.accentColor
    }

    Text {
        anchors {
            top: parent.top
            right: parent.right
            margins: 13
        }
        text: root.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 17
        font.weight: Font.Bold
    }

    Text {
        anchors {
            left: parent.left
            right: parent.right
            bottom: detailText.top
            leftMargin: 13
            rightMargin: 13
        }
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        id: detailText
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 13
            rightMargin: 13
            bottomMargin: root.progress >= 0 ? 16 : 10
        }
        text: root.detail
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    Rectangle {
        visible: root.progress >= 0
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 13
            rightMargin: 13
            bottomMargin: 8
        }
        height: 3
        radius: 1.5
        color: Theme.outlineSoft

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            height: parent.height
            radius: parent.radius
            color: root.accentColor

            Behavior on width {
                NumberAnimation { duration: Motion.fast; easing.type: Motion.standardCurve }
            }
        }
    }
}
