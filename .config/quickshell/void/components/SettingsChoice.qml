import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property var options: []
    property var optionLabels: []
    property string value: ""
    property bool enabled: true
    property int maxColumns: 4
    property var disabledOptions: []
    signal selected(string value)

    readonly property int rows: Math.max(1,
        Math.ceil(options.length / Math.max(1, maxColumns)))
    implicitHeight: Metrics.settingRowHeight + selector.implicitHeight
    radius: 0
    color: "transparent"
    border.width: 0
    opacity: enabled ? 1 : 0.46

    ColumnLayout {
        anchors {
            fill: parent
            margins: Metrics.spaceXL
        }
        spacing: Metrics.labelControlGap

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spaceS
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.titleSubtitleGap
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
                    Layout.fillWidth: true
                    text: root.subtitle
                    visible: text.length > 0
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextSupporting
                    elide: Text.ElideRight
                }
            }
        }

        SlidingChoice {
            id: selector
            Layout.fillWidth: true
            options: root.options
            optionLabels: root.optionLabels
            value: root.value
            maxColumns: root.maxColumns
            enabled: root.enabled
            disabledOptions: root.disabledOptions
            onSelected: value => root.selected(value)
        }
    }

    SettingsDivider {
        leftInset: Metrics.cardPadding
        rightInset: Metrics.cardPadding
    }
}
