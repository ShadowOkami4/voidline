import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// Month calendar, opened by clicking the clock.
PanelSurface {
    id: root

    open: Shell.panel === "calendar"
    anchor: Style.calendarAnchor
    panelWidth: 380
    panelHeight: column.implicitHeight + 40

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date today: clock.date
    // First day of the month on show.
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    onOpenChanged: if (open) month = new Date(today.getFullYear(), today.getMonth(), 1)

    function shift(by) { month = new Date(month.getFullYear(), month.getMonth() + by, 1) }
    readonly property int firstDay: Qt.locale().firstDayOfWeek      // 0 = Sunday
    // 42 cells, starting on the first weekday of the locale.
    readonly property var days: {
        const lead = (month.getDay() - firstDay + 7) % 7
        const out = []
        for (let i = 0; i < 42; ++i) {
            const d = new Date(month.getFullYear(), month.getMonth(), 1 - lead + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month.getMonth(),
                today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            })
        }
        return out
    }

    ColumnLayout {
        id: column
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                leftPadding: 6
                text: Qt.formatDateTime(root.today, "dddd")
                font.pixelSize: Theme.textTitle
                font.weight: Font.Bold
                color: Theme.primary
            }
            Label {
                leftPadding: 6
                text: Qt.formatDateTime(root.today, "d MMMM yyyy")
                font.pixelSize: 30
                font.weight: Font.Black
                font.letterSpacing: -0.5
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Label {
                Layout.fillWidth: true
                leftPadding: 6
                text: Qt.formatDateTime(root.month, "MMMM yyyy")
                font.weight: Font.Bold
            }
            IconBtn { icon: "today"; size: 36; onClicked: root.month = new Date(root.today.getFullYear(), root.today.getMonth(), 1) }
            IconBtn { icon: "chevron_left"; size: 36; tonal: true; onClicked: root.shift(-1) }
            IconBtn { icon: "chevron_right"; size: 36; tonal: true; onClicked: root.shift(1) }
        }

        Grid {
            id: grid
            Layout.fillWidth: true
            columns: 7
            readonly property real cell: Math.floor(width / 7)

            Repeater {
                model: 7
                Label {
                    required property int index
                    width: grid.cell
                    height: 28
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                    font.pixelSize: Theme.textLabel
                    font.weight: Font.Bold
                    color: Theme.inkMuted
                }
            }
            Repeater {
                model: root.days
                Item {
                    id: cell
                    required property var modelData
                    width: grid.cell
                    height: 42
                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        // Today is a rounded square, the M3 "selected" shape.
                        radius: cell.modelData.today ? Theme.cornerM : 19
                        color: cell.modelData.today ? Theme.primary : "transparent"
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        font.weight: cell.modelData.today ? Font.Black : Font.Medium
                        opacity: cell.modelData.inMonth ? 1 : 0.32
                        color: cell.modelData.today ? Theme.inkOnPrimary : (cell.modelData.weekend ? Theme.tertiary : Theme.ink)
                    }
                }
            }
        }
    }
}
