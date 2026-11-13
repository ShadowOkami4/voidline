import Quickshell
import QtQuick
import qs.core
import qs.widgets

// layout: "split" (bold time + small stacked date, Voidline),
//         "stacked" (time over date, right aligned, Windows),
//         "inline" (date and time on one line, macOS)
Item {
    id: root

    property string layout: "split"
    readonly property string timeText: Qt.formatDateTime(clock.date, Config.clock24h ? "HH:mm" : "h:mm AP")

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: root.layout === "split" ? split : (root.layout === "stacked" ? stacked : inline)
    }

    Component {
        id: split
        Row {
            spacing: 8
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeText
                font.pixelSize: 17
                font.weight: Font.Black
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    text: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                    color: Theme.primary
                }
                Label {
                    text: Qt.formatDateTime(clock.date, "d MMM")
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.inkMuted
                }
            }
        }
    }

    Component {
        id: stacked
        Column {
            Label {
                anchors.right: parent.right
                text: root.timeText
                font.pixelSize: Theme.textLabel
                font.weight: Font.DemiBold
            }
            Label {
                anchors.right: parent.right
                text: Qt.formatDateTime(clock.date, "dd.MM.yyyy")
                font.pixelSize: Theme.textLabelS
                color: Theme.inkMuted
            }
        }
    }

    Component {
        id: inline
        Label {
            text: Qt.formatDateTime(clock.date, "ddd d MMM") + "   " + root.timeText
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
}
