import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: "Clock design"
    property string subtitle: ""
    property var options: []
    property var optionLabels: []
    property string value: ""
    property int maxColumns: 2
    signal selected(string value)

    readonly property int columns: Math.max(1,
        Math.min(maxColumns, options.length))
    readonly property int rows: Math.max(1,
        Math.ceil(options.length / columns))

    readonly property int tileHeight: Math.round(116 * Metrics.scale)
    implicitHeight: Metrics.spaceXL * 2 + Metrics.appTextTitle + Metrics.labelControlGap
        + (subtitle.length > 0 ? Metrics.appTextSupporting + 4 : 0)
        + rows * tileHeight + Math.max(0, rows - 1) * Metrics.spaceS
    color: "transparent"

    ColumnLayout {
        anchors {
            fill: parent
            margins: Metrics.spaceXL
            // Line up with the text column of icon rows.
            leftMargin: Metrics.spaceXL + Math.round(40 * Metrics.scale) + Metrics.spaceM
        }
        spacing: Metrics.labelControlGap

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextTitle
                font.weight: Font.Normal
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextSupporting
                elide: Text.ElideRight
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.columns
            columnSpacing: Metrics.spaceS
            rowSpacing: Metrics.spaceS

            Repeater {
                model: root.options

                Rectangle {
                    id: preview
                    required property int index
                    required property var modelData
                    readonly property bool selectedPreview:
                        String(modelData) === root.value

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.tileHeight
                    // The selected design morphs to a tighter shape.
                    radius: selectedPreview ? Metrics.radiusM : Metrics.radiusXL
                    color: selectedPreview
                        ? Theme.accentContainer : Theme.groupSurfaceRaised
                    border.width: selectedPreview ? 2 : 0
                    border.color: Theme.accent
                    scale: previewTap.pressed ? 0.97 : 1

                    Item {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            bottom: label.top
                            margins: Metrics.spaceS
                        }

                        LockClock {
                            anchors.fill: parent
                            date: new Date(2026, 6, 28, 9, 41)
                            style: String(preview.modelData)
                            preview: true
                            showDate: preview.modelData === "digital-compact"
                                || preview.modelData === "horizontal"
                            datePlacement: preview.modelData === "horizontal"
                                ? "side" : "below"
                            clockScale: preview.modelData === "analog" ? 0.9 : 0.72
                            colorMode: "custom"
                            customColor1: preview.selectedPreview ? Theme.accent : Theme.text
                            customColor2: preview.selectedPreview ? Theme.accent : Theme.textMuted
                        }
                    }

                    Text {
                        id: label
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            bottomMargin: Metrics.spaceS
                        }
                        text: root.optionLabels.length > preview.index
                            ? root.optionLabels[preview.index]
                            : String(preview.modelData)
                        color: preview.selectedPreview ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textSupporting
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    TapHandler {
                        id: previewTap
                        onTapped: root.selected(String(preview.modelData))
                    }
                    Behavior on color {
                        ColorAnimation { duration: Motion.fast }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Motion.instant }
                    }
                }
            }
        }
    }

    SettingsDivider {
        leftInset: Metrics.cardPadding
        rightInset: Metrics.cardPadding
    }
}
