import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string icon: "devices_other"
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property string actionIcon: ""
    property string actionAccessibleName: "More actions"
    property bool active: false
    property bool available: true
    property bool busy: false
    property color accentColor: Theme.accent
    property color containerColor: active ? Theme.accentContainer : Theme.surfaceLow
    signal clicked
    signal actionClicked

    implicitHeight: active ? 76 : 68
    opacity: available ? 1 : 0.48
    scale: rowTap.pressed ? 0.988 : 1

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: rowHover.hovered && root.available ? Theme.surfaceHigh : root.containerColor
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 11

        Rectangle {
            Layout.preferredWidth: root.active ? 50 : 44
            Layout.preferredHeight: width
            radius: width / 2
            color: root.active ? root.accentColor : Theme.surfaceHover

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Motion.fast; easing.type: Motion.enterCurve }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.busy ? "progress_activity" : root.icon
                size: root.active ? 25 : 22
                color: root.active ? Theme.accentInk : Theme.text

                RotationAnimator on rotation {
                    running: root.busy
                    from: 0
                    to: 360
                    duration: Motion.spinner
                    loops: Animation.Infinite
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.active ? 15 : 14
                font.weight: root.active ? Font.Bold : Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: root.active ? root.accentColor : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: root.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.trailing.length > 0
            text: root.trailing
            color: root.active ? root.accentColor : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        IconButton {
            id: actionButton
            visible: root.actionIcon.length > 0
            icon: root.actionIcon
            size: 40
            active: root.active
            accessibleName: root.actionAccessibleName
            onClicked: root.actionClicked()
        }
    }

    HoverHandler { id: rowHover }

    Item {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            rightMargin: actionButton.visible ? 54 : 0
        }

        TapHandler {
            id: rowTap
            enabled: root.available
            onTapped: root.clicked()
        }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.standardCurve }
    }
    Behavior on scale { NumberAnimation { duration: Motion.instant } }
}
