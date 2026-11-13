import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

Rectangle {
    id: root

    required property var notification
    property color base: Theme.surfaceContainerHigh
    signal dismissed()

    implicitHeight: layout.implicitHeight + 24
    radius: Theme.cornerLInc
    color: base

    RowLayout {
        id: layout
        x: 14
        y: 12
        width: parent.width - 28
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            radius: Theme.cornerM
            color: Theme.primaryContainer

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                implicitSize: 22
                visible: source.toString().length > 0
                source: root.notification.image
                    || (root.notification.appIcon ? Quickshell.iconPath(root.notification.appIcon, true) : "")
            }
            MIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                icon: "notifications"
                size: 20
                color: Theme.inkOnPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: root.notification.summary || root.notification.appName
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.notification.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                font.pixelSize: Theme.textLabel
                color: Theme.inkMuted
            }
        }

        IconBtn {
            Layout.alignment: Qt.AlignTop
            icon: "close"
            size: 28
            onClicked: root.dismissed()
        }
    }
}
