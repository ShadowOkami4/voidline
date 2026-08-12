import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property color activeContainer: Theme.accentContainer
    property color activeContent: Theme.accent
    signal clicked

    implicitHeight: 78
    opacity: available ? 1 : 0.44
    scale: tap.pressed ? 0.975 : 1

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: hover.hovered
            ? Theme.surfaceHigh
            : (root.active ? root.activeContainer : Theme.surfaceLow)

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 11
        }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Theme.radiusMedium
            color: root.active ? root.activeContent : Theme.surfaceHover

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: 22
                color: root.active ? Theme.accentInk : Theme.textMuted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        MaterialIcon {
            text: "chevron_right"
            size: 17
            color: Theme.textMuted
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.available
        onTapped: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Motion.instant; easing.type: Motion.standardCurve } }
}
