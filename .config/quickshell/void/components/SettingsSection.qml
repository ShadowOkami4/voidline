import QtQuick
import QtQuick.Layouts
import "../core"

Column {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color iconContainerColor: Theme.accentContainer
    property color iconColor: Theme.accent
    property bool fullWidth: false
    default property alias contentData: bodyColumn.data

    width: parent && parent.isSettingsMasonry
        ? parent.itemWidth(fullWidth) : (parent ? parent.width : 0)
    spacing: Metrics.sectionHeaderGap

    RowLayout {
        width: parent.width
        height: root.subtitle.length > 0
            ? Metrics.sectionHeaderHeight : Metrics.controlS
        spacing: Metrics.spaceS

        Rectangle {
            visible: root.icon.length > 0
            Layout.preferredWidth: Metrics.controlS
            Layout.preferredHeight: Metrics.controlS
            radius: Metrics.iconContainerRadius
            color: root.iconContainerColor

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Metrics.iconM
                color: root.iconColor
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
                font.pixelSize: Metrics.appTextTitle
                font.weight: Font.DemiBold
                font.variableAxes: { "wght": 650, "wdth": 98, "opsz": 16 }
            }
            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextCaption
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }

    Rectangle {
        id: body
        width: parent.width
        implicitHeight: bodyColumn.implicitHeight
        radius: Metrics.cardRadius
        color: Theme.groupSurface
        border.width: 0
        clip: true

        Column {
            id: bodyColumn
            width: parent.width
            spacing: 0
        }
    }
}
