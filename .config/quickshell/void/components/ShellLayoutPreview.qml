import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    property string barPosition: Appearance.requestedBarPosition
    property string clockStyle: Appearance.clockStyle
    property string workspacePlacement: Appearance.workspacePlacement
    property string musicPlacement: Appearance.musicPlacement

    readonly property bool horizontal: barPosition === "top"
        || barPosition === "bottom"
    readonly property real edge: 5
    readonly property real barThickness: horizontal ? 25 : 31
    readonly property real panelWidth: horizontal
        ? preview.width * 0.38 : preview.width * 0.48
    readonly property real panelHeight: horizontal
        ? preview.height * 0.58 : preview.height * 0.43

    function hyprColor(source, fallback) {
        const match = String(source || "").match(
            /^rgba?\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\)$/)
        return match ? "#" + match[1] : fallback
    }

    implicitHeight: Math.max(250, Math.min(410, width * 0.56))

    Rectangle {
        id: preview
        anchors.fill: parent
        radius: Metrics.cardRadius
        color: Theme.background
        clip: true

        Image {
            anchors.fill: parent
            source: Appearance.wallpaperPath.length > 0
                ? "file://" + Appearance.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.34
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.withAlpha(Theme.background, Theme.darkMode ? 0.38 : 0.24)
        }

        Rectangle {
            x: secondaryWindow.x + Math.round(4 * Metrics.scale)
            y: secondaryWindow.y + Math.round(5 * Metrics.scale)
            width: secondaryWindow.width
            height: secondaryWindow.height
            radius: secondaryWindow.radius
            color: Theme.withAlpha(Theme.shadow, Metrics.shadowOpacity)
        }

        Rectangle {
            id: secondaryWindow
            x: preview.width * 0.08
            y: preview.height * 0.27
            width: preview.width * 0.25
            height: preview.height * 0.45
            radius: Math.max(2, Math.min(22,
                SystemSettingsService.windowRounding * 0.55))
            color: Theme.surfaceLow
            border.width: Math.max(1, Math.min(5,
                SystemSettingsService.borderSize * 0.32))
            border.color: root.hyprColor(
                SystemSettingsService.inactiveBorderColor, Theme.outlineSoft)

            ColumnLayout {
                anchors { fill: parent; margins: Metrics.spaceM }
                spacing: Metrics.spaceS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: Metrics.trackRadius
                    color: Theme.textMuted
                }
                Repeater {
                    model: 4
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        radius: Metrics.radiusS
                        color: index === 0
                            ? Theme.secondaryContainer : Theme.groupSurfaceRaised
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        Rectangle {
            x: sampleWindow.x + Math.round(4 * Metrics.scale)
            y: sampleWindow.y + Math.round(5 * Metrics.scale)
            width: sampleWindow.width
            height: sampleWindow.height
            radius: sampleWindow.radius
            color: Theme.withAlpha(Theme.shadow, Metrics.shadowOpacity)
        }

        Rectangle {
            id: sampleWindow
            x: preview.width * 0.35
            y: preview.height * 0.23
            width: preview.width * 0.43
            height: preview.height * 0.48
            radius: Math.max(2, Math.min(22,
                SystemSettingsService.windowRounding * 0.55))
            color: Theme.groupSurface
            border.width: Math.max(1, Math.min(5,
                SystemSettingsService.borderSize * 0.32))
            border.color: root.hyprColor(
                SystemSettingsService.activeBorderColor, Theme.accent)

            ColumnLayout {
                anchors { fill: parent; margins: Metrics.spaceM }
                spacing: Metrics.spaceS

                Rectangle {
                    Layout.preferredWidth: parent.width * 0.58
                    Layout.preferredHeight: 8
                    radius: Metrics.trackRadius
                    color: Theme.text
                    opacity: 0.82
                }
                Repeater {
                    model: 3
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: index === 1 ? 38 : 24
                        radius: Metrics.radiusS
                        color: index === 1
                            ? Theme.accentContainer : Theme.groupSurfaceRaised
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        Rectangle {
            id: previewBar
            x: root.horizontal ? root.edge
                : (root.barPosition === "left" ? root.edge
                    : preview.width - root.edge - width)
            y: root.horizontal
                ? (root.barPosition === "top" ? root.edge
                    : preview.height - root.edge - height)
                : root.edge
            width: root.horizontal ? preview.width - root.edge * 2
                : root.barThickness
            height: root.horizontal ? root.barThickness
                : preview.height - root.edge * 2
            radius: Math.min(Metrics.radiusM, 12)
            color: Theme.panel

            Rectangle {
                id: workspaceMark
                width: root.horizontal ? 54 : parent.width - 8
                height: root.horizontal ? parent.height - 8 : 48
                radius: Math.min(Metrics.radiusS, 8)
                color: Theme.accentContainer
                x: root.horizontal
                    ? (root.workspacePlacement === "clock" ? 5
                        : (root.workspacePlacement === "center"
                            ? (parent.width - width) / 2
                            : parent.width - width - 5))
                    : 4
                y: root.horizontal ? 4
                    : (root.workspacePlacement === "clock" ? 5
                        : (root.workspacePlacement === "center"
                            ? (parent.height - height) / 2
                            : parent.height - height - 5))

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: root.horizontal ? 4 : 2
                        Rectangle {
                            width: index === 1 ? 11 : 5
                            height: 5
                            radius: 3
                            color: index === 1 ? Theme.accent : Theme.textMuted
                        }
                    }
                }
            }

            Rectangle {
                visible: root.musicPlacement !== "hidden"
                width: root.horizontal ? 42 : parent.width - 8
                height: root.horizontal ? parent.height - 8 : 38
                radius: Math.min(Metrics.radiusS, 8)
                color: Theme.secondaryContainer
                x: root.horizontal
                    ? (root.musicPlacement === "bar"
                        ? (parent.width - width) / 2
                        : (root.musicPlacement === "clock" ? 64
                            : parent.width - width - 64))
                    : 4
                y: root.horizontal ? 4
                    : (root.musicPlacement === "clock" ? 59
                        : (root.musicPlacement === "action"
                            ? parent.height - height - 59
                            : (parent.height - height) / 2))

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    size: 13
                    color: Theme.secondary
                }
            }

            Text {
                visible: root.horizontal
                anchors.centerIn: parent
                text: root.clockStyle === "stacked" ? "12\n48"
                    : (root.clockStyle === "minimal" ? "12:48" : "12:48  Tue")
                color: Theme.text
                font.family: Appearance.clockFont
                font.pixelSize: root.clockStyle === "stacked" ? 7 : 9
                font.weight: Font.Bold
                lineHeight: 0.76
            }
        }

        Rectangle {
            id: attachedPanel
            x: root.horizontal
                ? preview.width - root.edge - width
                : (root.barPosition === "left"
                    ? root.edge + root.barThickness : preview.width
                        - root.edge - root.barThickness - width)
            y: root.horizontal
                ? (root.barPosition === "top"
                    ? root.edge + root.barThickness
                    : preview.height - root.edge - root.barThickness - height)
                : preview.height - root.edge - height
            width: root.panelWidth
            height: root.panelHeight
            radius: Math.min(Metrics.panelRadius, 16)
            color: Theme.panel

            // Fill the two screen-attached corners while leaving the free
            // corners rounded, matching the real direction-aware panel.
            Rectangle {
                visible: root.horizontal
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: parent.radius
                color: parent.color
            }
            Rectangle {
                visible: !root.horizontal
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.radius
                color: parent.color
            }

            ColumnLayout {
                anchors { fill: parent; margins: Metrics.spaceM }
                spacing: Metrics.spaceS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spaceS
                    Repeater {
                        model: 2
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: Metrics.radiusS
                            color: index === 0
                                ? Theme.accentContainer : Theme.groupSurfaceRaised
                        }
                    }
                }
                Repeater {
                    model: 2
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        radius: Metrics.trackRadius
                        color: index === 0 ? Theme.secondary : Theme.outlineSoft
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Metrics.radiusM
                    color: Theme.groupSurface
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: preview.radius
            color: "transparent"
            border.width: Metrics.border
            border.color: Theme.outlineSoft
        }
    }
}
