import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string icon: "info"
    property string title: ""
    property string value: ""
    property color iconColor: Theme.textMuted

    implicitHeight: Metrics.settingRowCompact

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Metrics.spaceXL
            rightMargin: Metrics.spaceXL
        }
        spacing: Metrics.spaceM

        Rectangle {
            Layout.preferredWidth: Math.round(40 * Metrics.scale)
            Layout.preferredHeight: Math.round(40 * Metrics.scale)
            radius: width / 2
            color: Theme.surfaceContainerHighest
            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Math.round(24 * Metrics.scale)
                color: root.iconColor
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextTitle
            font.weight: Font.Normal
            elide: Text.ElideRight
        }

        Text {
            Layout.maximumWidth: parent.width * 0.52
            text: root.value
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextSupporting
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
        }
    }

    SettingsDivider { }
}
