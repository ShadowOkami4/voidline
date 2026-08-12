import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string icon: "info"
    property string title: ""
    property string value: ""
    property string subtitle: ""
    property color accentColor: Theme.accent
    property color containerColor: Theme.accentContainer

    implicitHeight: Math.round(104 * Metrics.scale)
    radius: Metrics.tileRadius
    color: Theme.groupSurfaceRaised
    border.width: Metrics.border
    border.color: Theme.outlineSoft

    RowLayout {
        anchors.fill: parent
        anchors.margins: Metrics.cardPaddingWide
        spacing: Metrics.spaceM

        Rectangle {
            Layout.preferredWidth: Metrics.controlL
            Layout.preferredHeight: Metrics.controlL
            radius: Metrics.iconContainerRadius
            color: root.containerColor

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Metrics.iconL
                color: root.accentColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.titleSubtitleGap

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextCaption
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.value
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextTitle
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextCaption
                elide: Text.ElideMiddle
            }
        }
    }
}
