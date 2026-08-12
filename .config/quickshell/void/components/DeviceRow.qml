import QtQuick
import "../core"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool active: false
    property bool available: true
    property bool showChevron: false
    signal clicked

    implicitHeight: 64
    opacity: available ? 1 : 0.5
    scale: tap.pressed ? 0.985 : 1

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.active ? Theme.accentContainer
            : (hover.hovered ? Theme.groupSurfaceRaised : "transparent")
        border.width: 0

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Rectangle {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 11
        }
        width: 42
        height: 42
        radius: Theme.radiusMedium
        color: root.active ? Theme.accent : Theme.surfaceHover

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            size: 22
            color: root.active ? Theme.accentInk : Theme.text
        }
    }

    Text {
        anchors {
            left: parent.left
            right: trailingText.left
            top: parent.top
            leftMargin: 64
            rightMargin: 10
            topMargin: 12
        }
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        anchors {
            left: parent.left
            right: trailingText.left
            bottom: parent.bottom
            leftMargin: 64
            rightMargin: 10
            bottomMargin: 11
        }
        text: root.subtitle
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Text {
        id: trailingText
        anchors {
            right: chevron.left
            verticalCenter: parent.verticalCenter
            rightMargin: root.showChevron ? 3 : 14
        }
        width: Math.min(78, implicitWidth)
        text: root.trailing
        color: root.active ? Theme.accent : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    MaterialIcon {
        id: chevron
        visible: root.showChevron
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 10
        }
        text: "chevron_right"
        size: 19
        color: Theme.textMuted
    }

    HoverHandler { id: hover }

    TapHandler {
        id: tap
        enabled: root.available
        onTapped: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Motion.instant } }

    SettingsDivider { rightInset: 14 }
}
