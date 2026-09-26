import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property url logoSource
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property bool interactive: false
    signal clicked

    implicitHeight: Metrics.settingRowComfortable
    color: "transparent"
    radius: 0

    Rectangle {
        anchors { fill: parent; margins: Metrics.space2XS }
        radius: Metrics.stateRadius
        color: root.interactive && hover.hovered
            ? Theme.withAlpha(Theme.text, 0.06) : "transparent"
        scale: tap.pressed ? 0.992 : 1
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.instant } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Metrics.spaceXL
            rightMargin: Metrics.spaceXL
        }
        spacing: Metrics.spaceM

        Rectangle {
            // Wordmark logos need a wider pill than the 40 px icon column.
            Layout.preferredWidth: Math.round(58 * Metrics.scale)
            Layout.preferredHeight: Math.round(40 * Metrics.scale)
            radius: height / 2
            color: Theme.surfaceContainerHighest

            Image {
                anchors { fill: parent; margins: Metrics.spaceXS }
                source: root.logoSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 64
            }
        }

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
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextBody
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.maximumWidth: parent.width * 0.3
            text: root.value
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextSupporting
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    HoverHandler { id: hover; enabled: root.interactive }
    TapHandler {
        id: tap
        enabled: root.interactive
        onTapped: root.clicked()
    }
    SettingsDivider { }
}
