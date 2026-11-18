import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Month calendar with events, opened by clicking the clock. Click a day to
// see what is planned and to add something.
PanelSurface {
    id: root

    open: Shell.panel === "calendar"
    anchor: Style.calendarAnchor
    panelWidth: 380
    panelHeight: column.implicitHeight + 40
    Behavior on panelHeight { Spring { duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date today: clock.date
    // First day of the month on show.
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    // The day whose events are listed.
    property date picked: today
    readonly property string pickedKey: Events.key(picked)
    readonly property var plans: Events.on(picked)
    // How often a new event comes back: "" | "weekly" | "monthly" | "yearly"
    property string repeat: ""

    onOpenChanged: if (open) {
        editing = ""
        month = new Date(today.getFullYear(), today.getMonth(), 1)
        picked = today
        repeat = ""
        what.text = ""
        when.text = ""
    }

    // Turning the page: the grid slides out one way and in from the other.
    property real flip: 0
    function shift(by) { if (!turn.running) { turn.by = by; turn.start() } }
    function show(d) {
        const by = (d.getFullYear() - month.getFullYear()) * 12 + d.getMonth() - month.getMonth()
        if (by !== 0) { turn.by = by; turn.restart() }
    }
    function pick(d) { picked = d; show(d) }
    SequentialAnimation {
        id: turn
        property int by: 0
        readonly property int way: by > 0 ? 1 : -1
        NumberAnimation { target: root; property: "flip"; to: -turn.way; duration: Motion.effectsFast; easing.type: Easing.InCubic }
        ScriptAction { script: { root.month = new Date(root.month.getFullYear(), root.month.getMonth() + turn.by, 1); root.flip = turn.way } }
        NumberAnimation { target: root; property: "flip"; to: 0; duration: Motion.spatialFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialFastCurve }
    }

    // Id of the own event being changed, or "".
    property string editing: ""
    function editEvent(e) {
        editing = e.id
        what.text = e.title
        when.text = e.time || ""
        repeat = e.repeat === "daily" ? "" : (e.repeat || "")
        what.forceActiveFocus()
        what.selectAll()
    }
    function stopEditing() { editing = ""; what.text = ""; when.text = ""; repeat = "" }
    onPickedKeyChanged: if (editing.length > 0) stopEditing()

    function addEvent() {
        if (what.text.trim().length === 0) return
        if (editing.length > 0) Events.update(editing, when.text, what.text, repeat)
        else Events.add(pickedKey, when.text, what.text, repeat)
        stopEditing()
    }

    readonly property int firstDay: Lang.locale.firstDayOfWeek      // 0 = Sunday
    // 42 cells, starting on the first weekday of the locale.
    readonly property var days: {
        const lead = (month.getDay() - firstDay + 7) % 7
        const out = []
        for (let i = 0; i < 42; ++i) {
            const d = new Date(month.getFullYear(), month.getMonth(), 1 - lead + i)
            out.push({
                date: d,
                day: d.getDate(),
                inMonth: d.getMonth() === month.getMonth(),
                today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate(),
                weekend: d.getDay() === 0 || d.getDay() === 6,
                busy: Events.busy(d)
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
            opacity: root.shown(0)
            transform: Translate { y: (1 - root.shown(0)) * 18 }
            Label {
                leftPadding: 6
                text: Lang.date(root.today, "dddd")
                font.pixelSize: Theme.textTitle
                font.weight: Font.Bold
                color: Theme.primary
            }
            Label {
                leftPadding: 6
                text: Lang.date(root.today, Lang.t("d MMMM yyyy"))
                font.pixelSize: 30
                font.weight: Font.Black
                font.letterSpacing: -0.5
            }
        }

        // Other places, and when the next alarm rings.
        Flow {
            Layout.fillWidth: true
            visible: Config.worldClocks.length > 0 || !!Clocks.next
            spacing: 6
            opacity: root.shown(0.6)
            Repeater {
                model: Config.worldClocks
                Rectangle {
                    id: place
                    required property string modelData
                    readonly property var at: Clocks.timeIn(modelData, root.today)
                    width: placeRow.implicitWidth + 24
                    height: 40
                    radius: Theme.cornerL
                    color: Theme.surfaceContainerHighest
                    Row {
                        id: placeRow
                        anchors.centerIn: parent
                        spacing: 8
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: place.at ? Qt.formatDateTime(place.at, Config.clock24h ? "HH:mm" : "h:mm AP") : "–"
                            font.weight: Font.Black
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Label { text: Clocks.cityOf(place.modelData); font.pixelSize: Theme.textLabelS; font.weight: Font.Bold }
                            Label {
                                text: Clocks.difference(place.modelData, root.today)
                                    + (place.at && place.at.getDate() !== root.today.getDate() ? "  ·  " + (place.at > root.today ? Lang.t("tomorrow") : Lang.t("yesterday")) : "")
                                font.pixelSize: Theme.textLabelS - 1
                                color: Theme.inkMuted
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: !!Clocks.next
                width: alarmRow.implicitWidth + 24
                height: 40
                radius: Theme.cornerL
                color: Theme.tertiaryContainer
                Row {
                    id: alarmRow
                    anchors.centerIn: parent
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "alarm"; size: 18; filled: true; color: Theme.inkOnTertiaryContainer }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Clocks.next ? Lang.date(Clocks.next, Clocks.next.getDate() === root.today.getDate() ? "HH:mm" : "ddd HH:mm") : ""
                        font.weight: Font.Bold
                        color: Theme.inkOnTertiaryContainer
                    }
                }
            }
        }

        // Weather, when a place is set in Settings > Date & time.
        Rectangle {
            Layout.fillWidth: true
            visible: Weather.wanted
            implicitHeight: 92
            radius: Theme.cornerXL
            color: Theme.secondaryContainer
            opacity: root.shown(1)
            transform: Translate { y: (1 - root.shown(1)) * 18 }

            Label {
                visible: !Weather.ready
                anchors.centerIn: parent
                text: Weather.problem || Lang.t("Getting the weather…")
                color: Theme.inkOnSecondaryContainer
            }
            Row {
                visible: Weather.ready
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Weather.icon(Weather.code); filled: true; size: 40; color: Theme.inkOnSecondaryContainer }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: Weather.temperature + "°"; font.pixelSize: 30; font.weight: Font.Black; color: Theme.inkOnSecondaryContainer }
                    Label { width: 110; elide: Text.ElideRight; text: Weather.words(Weather.code) + ", " + Weather.where; font.pixelSize: Theme.textLabelS; color: Theme.inkOnSecondaryContainer; opacity: 0.85 }
                }
            }
            Row {
                visible: Weather.ready
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Repeater {
                    model: Weather.days.slice(1, 4)
                    Column {
                        id: day
                        required property var modelData
                        spacing: 1
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: day.modelData.day; font.pixelSize: Theme.textLabelS; font.weight: Font.Bold; color: Theme.inkOnSecondaryContainer }
                        MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Weather.icon(day.modelData.code); size: 22; color: Theme.inkOnSecondaryContainer }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: day.modelData.max + "° " + day.modelData.min + "°"; font.pixelSize: Theme.textLabelS; color: Theme.inkOnSecondaryContainer; opacity: 0.85 }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            opacity: root.shown(2)
            Label {
                Layout.fillWidth: true
                leftPadding: 6
                text: Lang.date(root.month, "MMMM yyyy")
                font.weight: Font.Bold
            }
            IconBtn { icon: "today"; size: 36; onClicked: root.pick(root.today) }
            IconBtn { icon: "chevron_left"; size: 36; tonal: true; onClicked: root.shift(-1) }
            IconBtn { icon: "chevron_right"; size: 36; tonal: true; onClicked: root.shift(1) }
        }

        Grid {
            id: grid
            Layout.fillWidth: true
            columns: 7
            readonly property real cell: Math.floor(width / 7)
            opacity: 1 - Math.abs(root.flip)
            transform: Translate { x: root.flip * 44 }

            Repeater {
                model: 7
                Label {
                    required property int index
                    width: grid.cell
                    height: 28
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Lang.locale.dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                    font.pixelSize: Theme.textLabel
                    font.weight: Font.Bold
                    color: Theme.inkMuted
                    opacity: root.shown(2.4)
                }
            }
            Repeater {
                model: root.days
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool picked: Events.key(modelData.date) === root.pickedKey
                    readonly property real arrived: root.shown(2.8 + Math.floor(index / 7) * 0.45)
                    width: grid.cell
                    height: 44
                    opacity: arrived
                    transform: Translate { y: (1 - cell.arrived) * 14 }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        // Today and the chosen day are rounded squares, the M3 "selected" shape.
                        radius: cell.modelData.today || cell.picked ? Theme.cornerM : 19
                        color: cell.modelData.today ? Theme.primary
                            : (cell.picked ? Theme.secondaryContainer : Theme.alpha(Theme.ink, press.pressed ? 0.14 : (press.containsMouse ? 0.08 : 0)))
                        scale: press.pressed ? 0.88 : 1
                        Behavior on radius { Spring {} }
                        Behavior on scale { Spring {} }
                        Behavior on color { Tint {} }
                    }
                    Label {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: cell.modelData.busy ? -3 : 0
                        text: cell.modelData.day
                        font.weight: cell.modelData.today ? Font.Black : Font.Medium
                        opacity: cell.modelData.inMonth ? 1 : 0.32
                        color: cell.modelData.today ? Theme.inkOnPrimary
                            : (cell.picked ? Theme.inkOnSecondaryContainer : (cell.modelData.weekend ? Theme.tertiary : Theme.ink))
                    }
                    // Something is planned on this day.
                    Rectangle {
                        visible: cell.modelData.busy
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 31
                        width: 5
                        height: 5
                        radius: 2.5
                        opacity: cell.modelData.inMonth ? 1 : 0.4
                        color: cell.modelData.today ? Theme.inkOnPrimary : Theme.primary
                    }
                    MouseArea {
                        id: press
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(cell.modelData.date)
                    }
                }
            }
        }

        // ---- the chosen day ------------------------------------------------------------
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 2
            leftPadding: 6
            text: Lang.date(root.picked, Lang.t("dddd, d MMMM"))
            font.weight: Font.Bold
            color: Theme.primary
            opacity: root.shown(6)
        }

        ListView {
            id: planList
            Layout.fillWidth: true
            Layout.topMargin: -6
            implicitHeight: Math.min(contentHeight, 152)
            visible: count > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.plans
            opacity: root.shown(6.4)
            delegate: Rectangle {
                id: plan
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 48
                radius: root.editing === modelData.id ? Theme.cornerM : Theme.cornerL
                color: root.editing === modelData.id ? Theme.secondaryContainer : (change.containsMouse && modelData.own ? Theme.alpha(Theme.secondaryContainer, 0.6) : Theme.surfaceContainerHighest)
                Behavior on color { Tint {} }
                // Click your own event to change it.
                MouseArea {
                    id: change
                    anchors.fill: parent
                    enabled: !!plan.modelData.own
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editing === plan.modelData.id ? root.stopEditing() : root.editEvent(plan.modelData)
                }
                // Each one slides in when the day changes.
                NumberAnimation on opacity { from: 0; to: 1; duration: Motion.effectsSlow }
                transform: Translate { id: slide; x: 0 }
                NumberAnimation { target: slide; property: "x"; from: 26 + plan.index * 10; to: 0; running: true; duration: Motion.spatialFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialFastCurve }

                Rectangle {
                    id: stripe
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 26
                    radius: 2
                    color: plan.modelData.own ? Theme.primary : Theme.tertiary
                }
                Column {
                    anchors.left: stripe.right
                    anchors.leftMargin: 10
                    anchors.right: gone.visible ? gone.left : parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        text: plan.modelData.title
                        font.weight: Font.DemiBold
                    }
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (plan.modelData.time || Lang.t("All day"))
                            + (plan.modelData.repeat === "daily" ? "  ·  " + Lang.t("Daily") : plan.modelData.repeat === "weekly" ? "  ·  " + Lang.t("Weekly")
                                : plan.modelData.repeat === "monthly" ? "  ·  " + Lang.t("Monthly") : plan.modelData.repeat === "yearly" ? "  ·  " + Lang.t("Yearly") : "")
                        font.pixelSize: Theme.textLabelS
                        color: Theme.inkMuted
                    }
                }
                IconBtn {
                    id: gone
                    visible: !!plan.modelData.own
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    size: 30
                    onClicked: { if (root.editing === plan.modelData.id) root.stopEditing(); Events.remove(plan.modelData.id) }
                }
            }
        }

        // New event: what, and when you start typing also when and how often.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: what.activeFocus ? Theme.cornerM : height / 2
            color: Theme.surfaceContainerHighest
            border.width: what.activeFocus ? 2 : 0
            border.color: Theme.primary
            opacity: root.shown(6.8)
            Behavior on radius { Spring {} }

            MIcon { id: plus; x: 14; anchors.verticalCenter: parent.verticalCenter; icon: root.editing.length > 0 ? "edit" : "add"; size: 20; color: root.editing.length > 0 ? Theme.primary : Theme.inkMuted }
            TextInput {
                id: what
                anchors.left: plus.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 16
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: 80
                color: Theme.ink
                selectionColor: Theme.primaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                clip: true
                Keys.onReturnPressed: root.addEvent()
                Keys.onEnterPressed: root.addEvent()
                Keys.onEscapePressed: root.editing.length > 0 ? root.stopEditing() : Shell.close()
                KeyNavigation.tab: when
                Label {
                    visible: what.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.editing.length > 0 ? Lang.t("What is it called?") : (root.plans.length === 0 ? Lang.t("Nothing planned. Add something…") : Lang.t("Add something…"))
                    color: Theme.inkMuted
                }
            }
        }

        RowLayout {
            id: more
            readonly property bool wanted: what.text.length > 0 || when.activeFocus || root.editing.length > 0
            Layout.fillWidth: true
            Layout.topMargin: wanted ? -6 : -14
            property real tall: wanted ? 42 : 0
            Layout.preferredHeight: Math.max(0, tall)
            opacity: wanted ? 1 : 0
            visible: tall > 1
            spacing: 6
            clip: true
            Behavior on tall { Spring {} }
            Behavior on opacity { Fade {} }

            Rectangle {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 42
                radius: when.activeFocus ? Theme.cornerM : height / 2
                color: Theme.surfaceContainerHighest
                border.width: when.activeFocus ? 2 : (when.text.length > 0 && Events.tidyTime(when.text) === "" ? 2 : 0)
                border.color: when.text.length > 0 && Events.tidyTime(when.text) === "" ? Theme.error : Theme.primary
                Behavior on radius { Spring {} }
                MIcon { id: watch; x: 12; anchors.verticalCenter: parent.verticalCenter; icon: "schedule"; size: 18; color: Theme.inkMuted }
                TextInput {
                    id: when
                    anchors.left: watch.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 5
                    color: Theme.ink
                    selectionColor: Theme.primaryContainer
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    clip: true
                    Keys.onReturnPressed: root.addEvent()
                    Keys.onEnterPressed: root.addEvent()
                    Keys.onEscapePressed: Shell.close()
                    KeyNavigation.tab: what
                    Label {
                        visible: when.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Lang.t("All day")
                        font.pixelSize: Theme.textLabel
                        color: Theme.inkMuted
                    }
                }
            }
            // Click to go through: once, weekly, monthly, yearly.
            Pressable {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: root.repeat.length > 0 ? Theme.secondaryContainer : Theme.surfaceContainerHighest
                restRadius: root.repeat.length > 0 ? Theme.cornerM : Theme.cornerFull
                Behavior on color { Tint {} }
                onClicked: root.repeat = root.repeat === "" ? "weekly" : (root.repeat === "weekly" ? "monthly" : (root.repeat === "monthly" ? "yearly" : ""))
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.repeat.length > 0 ? "repeat" : "looks_one"; size: 18; color: root.repeat.length > 0 ? Theme.inkOnSecondaryContainer : Theme.inkMuted }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.repeat === "weekly" ? Lang.t("Weekly") : (root.repeat === "monthly" ? Lang.t("Monthly") : (root.repeat === "yearly" ? Lang.t("Yearly") : Lang.t("Once")))
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.DemiBold
                        color: root.repeat.length > 0 ? Theme.inkOnSecondaryContainer : Theme.ink
                    }
                }
            }
            IconBtn {
                icon: "check"
                size: 42
                selected: true
                onClicked: root.addEvent()
            }
        }
    }
}
