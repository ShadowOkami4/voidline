import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool enabled: true
    property color iconContainerColor: checked ? Theme.accentContainer : Theme.surfaceContainerHighest
    property color iconContentColor: checked ? Theme.accentContainerInk : Theme.text
    signal toggled(bool checked)

    implicitHeight: subtitle.length > 0
        ? Metrics.settingRowComfortable : Metrics.settingRowCompact
    radius: 0
    color: "transparent"
    border.width: 0
    opacity: enabled ? 1 : 0.64

    Rectangle {
        id: hoverSurface
        anchors.fill: parent
        radius: Metrics.segmentInnerRadius
        color: hover.hovered && root.enabled
            ? Theme.withAlpha(Theme.text, 0.06) : "transparent"
        border.width: Appearance.focusIndicators && hover.hovered
            && root.enabled ? 2 : 0
        border.color: Theme.secondary
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Metrics.cardPadding
            rightMargin: Metrics.cardPadding
        }
        spacing: Metrics.spaceM

        Rectangle {
            Layout.preferredWidth: Math.round(40 * Metrics.scale)
            Layout.preferredHeight: Math.round(40 * Metrics.scale)
            radius: width / 2
            color: root.iconContainerColor

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Metrics.iconM
                color: root.iconContentColor
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
                font.pixelSize: Metrics.appTextBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                visible: text.length > 0
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextCaption
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        ToggleSwitch {
            checked: root.checked
            enabled: root.enabled
            onToggled: value => root.toggled(value)
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: rowTap
        enabled: root.enabled
        onTapped: root.toggled(!root.checked)
    }
    SettingsDivider { }
}
