import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool vertical: false
    property var shellScreen

    implicitWidth: vertical ? 52 : horizontalContent.implicitWidth + 20
    implicitHeight: vertical ? 68 : 36

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: ShellState.isClockScreen(root.shellScreen) ? Theme.accentContainer
            : (hover.hovered ? Theme.surfaceHover : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        id: horizontalContent
        anchors.centerIn: parent
        spacing: Appearance.clockStyle === "minimal" ? 0 : 8
        visible: !root.vertical

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Theme.text
            font.family: Appearance.clockFont
            font.pixelSize: Appearance.clockStyle === "compact" ? 16 : 18
            font.weight: Font.Bold
            font.letterSpacing: -0.35
            font.preferTypoLineMetrics: true
            font.features: { "tnum": 1 }
            font.variableAxes: {
                "wght": 760, "wdth": 90, "opsz": 18, "GRAD": 60
            }
        }

        Rectangle {
            Layout.preferredWidth: 4
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.accent
            visible: Appearance.clockStyle === "split"
        }

        ColumnLayout {
            spacing: -2
            visible: Appearance.clockStyle === "split"
                || Appearance.clockStyle === "stacked"

            Text {
                text: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
                color: Theme.accent
                font.family: Appearance.clockFont
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
            }
            Text {
                text: Qt.formatDateTime(clock.date, "dd MMM")
                color: Theme.textMuted
                font.family: Appearance.clockFont
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }

        Text {
            text: Qt.formatDateTime(clock.date, "ddd dd")
            visible: Appearance.clockStyle === "compact"
            color: Theme.textMuted
            font.family: Appearance.clockFont
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: -3
        visible: root.vertical

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "hh")
            color: Theme.text
            font.family: Appearance.clockFont
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "mm")
            color: Theme.accent
            font.family: Appearance.clockFont
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "ddd")
            visible: Appearance.clockStyle !== "minimal"
            color: Theme.textMuted
            font.family: Appearance.clockFont
            font.pixelSize: 8
            font.weight: Font.DemiBold
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: ShellState.toggleClock(root.shellScreen) }
}
