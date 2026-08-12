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

    implicitHeight: Math.round(112 * Metrics.scale)
    radius: Metrics.tileRadius
    color: hover.hovered && interactive
        ? Theme.groupSurfaceRaised : Theme.surfaceLow
    border.width: Metrics.border
    border.color: Theme.outlineSoft
    scale: tap.pressed && interactive ? 0.99 : 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: Metrics.cardPaddingWide
        spacing: Metrics.spaceM

        Rectangle {
            Layout.preferredWidth: Metrics.controlL
            Layout.preferredHeight: Metrics.controlL
            radius: Metrics.iconContainerRadius
            color: Theme.groupSurfaceRaised

            Image {
                anchors.fill: parent
                anchors.margins: Metrics.spaceS
                source: root.logoSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                sourceSize.width: 160
                sourceSize.height: 160
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.titleSubtitleGap

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spaceS
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: root.value
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextCaption
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextSupporting
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    HoverHandler { id: hover; enabled: root.interactive }
    TapHandler {
        id: tap
        enabled: root.interactive
        onTapped: root.clicked()
    }
    Behavior on color { ColorAnimation { duration: Motion.fast } }
    Behavior on scale { NumberAnimation { duration: Motion.instant } }
}
