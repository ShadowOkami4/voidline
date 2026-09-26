import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property bool active: false
    property bool enabled: true
    property bool interactive: true
    property color iconContainerColor: "transparent"
    property color iconContentColor: active ? Theme.accent : Theme.textMuted
    signal clicked

    implicitHeight: subtitle.length > 0
        ? Metrics.settingRowComfortable : Metrics.settingRowCompact
    radius: 0
    color: "transparent"
    border.width: 0
    // Unsupported rows remain readable while their control affordance is
    // visibly inactive. The former 50% opacity lost too much contrast on
    // wallpaper-derived dark palettes.
    opacity: enabled ? 1 : 0.64
    scale: tap.pressed && interactive ? 0.992 : 1

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spaceS
        anchors.rightMargin: Metrics.spaceS
        radius: Metrics.radiusL
        color: root.active ? Theme.accentContainer
            : (hover.hovered && root.enabled && root.interactive
                ? Theme.withAlpha(Theme.text, 0.06) : "transparent")
        border.width: root.active && Appearance.highContrast ? 2
            : (Appearance.focusIndicators && hover.hovered && root.enabled ? 2 : 0)
        border.color: root.active ? Theme.accent : Theme.secondary

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

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
            color: root.iconContainerColor

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Math.round(24 * Metrics.scale)
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
                font.pixelSize: Metrics.appTextBody
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Text {
            text: root.value
            visible: text.length > 0
            color: root.active ? Theme.accent : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextSupporting
            font.weight: Font.DemiBold
        }

        MaterialIcon {
            text: "chevron_right"
            size: 19
            color: Theme.textMuted
            visible: false
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.enabled && root.interactive
        onTapped: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Motion.instant } }

    SettingsDivider { allowed: !root.active }
}
