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
    signal clicked

    implicitWidth: 112
    implicitHeight: 82
    opacity: available ? 1 : 0.45
    scale: tap.pressed ? 0.965 : 1

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: root.active ? Theme.surfaceActive : (hover.hovered ? Theme.surfaceHover : Theme.surface)
        border.width: root.active ? 1 : 0
        border.color: Theme.outline

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 5

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            size: 25
            color: root.active ? Theme.accent : Theme.text
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.subtitle
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.available
        onTapped: root.clicked()
    }

    Behavior on scale {
        NumberAnimation { duration: Motion.instant; easing.type: Motion.standardCurve }
    }
}
