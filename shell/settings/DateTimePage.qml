import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Date and time. Reads and changes system time settings through timedatectl;
// changes ask for permission through the password dialog.
ColumnLayout {
    id: page
    spacing: 24

    property string zone: ""
    property bool ntp: false
    property bool canNtp: true
    property bool synced: false
    property var zones: []
    property bool picking: false
    property string problem: ""

    readonly property var matches: {
        const q = filter.text.trim().toLowerCase().replace(/ /g, "_")
        return q.length === 0 ? zones : zones.filter(z => z.toLowerCase().includes(q))
    }
    function pretty(z) { return z.replace(/_/g, " ").replace(/\//g, " / ") }

    function refresh() { status.running = true }
    function run(args) {
        problem = ""
        change.command = ["timedatectl"].concat(args)
        change.running = true
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    Process {
        id: status
        command: ["timedatectl", "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) v[line.slice(0, i)] = line.slice(i + 1)
                }
                page.zone = v.Timezone ?? ""
                page.ntp = v.NTP === "yes"
                page.canNtp = v.CanNTP !== "no"
                page.synced = v.NTPSynchronized === "yes"
            }
        }
    }
    Process {
        id: listZones
        command: ["timedatectl", "list-timezones"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.zones = text.split("\n").filter(z => z.length > 0) }
    }
    Process {
        id: change
        onExited: code => {
            if (code !== 0) page.problem = Lang.t("That was not changed. It needs your password.")
            else page.picking = false
            page.refresh()
        }
    }

    // ---- hero -------------------------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Theme.cornerXXL
        color: Theme.primaryContainer

        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Label {
                text: Qt.formatDateTime(clock.date, Config.clock24h ? "HH:mm:ss" : "h:mm:ss AP")
                font.pixelSize: 60
                font.weight: Font.Black
                font.letterSpacing: -2
                color: Theme.inkOnPrimaryContainer
            }
            Label {
                text: Lang.date(clock.date, Lang.t("dddd, d MMMM yyyy")) + (page.zone.length > 0 ? "  ·  " + page.pretty(page.zone) : "")
                font.weight: Font.DemiBold
                color: Theme.inkOnPrimaryContainer
                opacity: 0.85
            }
        }
    }

    Rectangle {
        visible: page.problem.length > 0
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.cornerL
        color: Theme.errorContainer
        Label {
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            text: page.problem
            font.weight: Font.DemiBold
            color: Theme.inkOnErrorContainer
        }
    }

    SegGroup {
        title: Lang.t("Time")
        SegItem {
            visible: page.canNtp
            icon: "sync"
            hue: 0
            lobes: 8
            title: Lang.t("Set time automatically")
            description: !page.ntp ? Lang.t("The clock runs on its own.") : (page.synced ? Lang.t("In step with internet time.") : Lang.t("Waiting for internet time."))
            Toggle { checked: page.ntp; onToggled: v => page.run(["set-ntp", v ? "true" : "false"]) }
        }
        SegItem {
            icon: "public"
            hue: 1
            lobes: 0
            title: Lang.t("Time zone")
            description: page.zone.length > 0 ? page.pretty(page.zone) : Lang.t("Unknown")
            clickable: true
            onClicked: { page.picking = !page.picking; if (page.picking) filter.forceActiveFocus() }
            MIcon { icon: page.picking ? "expand_less" : "expand_more"; size: 24; color: Theme.inkMuted }

            extra: ColumnLayout {
                visible: page.picking
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: filter.activeFocus ? Theme.cornerM : height / 2
                    color: Theme.surfaceContainerHighest
                    Behavior on radius { Spring {} }
                    MIcon { id: glass; x: 16; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 20; color: Theme.inkMuted }
                    TextInput {
                        id: filter
                        anchors.left: glass.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.ink
                        selectionColor: Theme.primaryContainer
                        font.family: Theme.font
                        font.pixelSize: Theme.textBody
                        clip: true
                        Keys.onEscapePressed: page.picking = false
                        Keys.onReturnPressed: if (page.matches.length > 0) page.run(["set-timezone", page.matches[0]])
                        Label {
                            visible: filter.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lang.t("Search city or region")
                            color: Theme.inkMuted
                        }
                    }
                }

                ListView {
                    id: zoneList
                    Layout.fillWidth: true
                    // Open at the zone in use.
                    onVisibleChanged: if (visible && filter.text.length === 0) positionViewAtIndex(Math.max(0, page.zones.indexOf(page.zone)), ListView.Center)
                    implicitHeight: Math.min(280, contentHeight)
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: page.matches
                    delegate: Pressable {
                        id: zoneRow
                        required property string modelData
                        readonly property bool current: modelData === page.zone
                        width: ListView.view.width
                        height: 44
                        wheelEnabled: false
                        color: current ? Theme.secondaryContainer : "transparent"
                        restRadius: Theme.cornerM
                        pressedRadius: Theme.cornerS
                        onClicked: page.run(["set-timezone", modelData])
                        Label {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.pretty(zoneRow.modelData)
                            font.weight: zoneRow.current ? Font.Bold : Font.Normal
                            color: zoneRow.current ? Theme.inkOnSecondaryContainer : Theme.ink
                        }
                        MIcon {
                            visible: zoneRow.current
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "check"
                            size: 20
                            color: Theme.inkOnSecondaryContainer
                        }
                    }
                }
                Label {
                    visible: page.matches.length === 0
                    text: Lang.t("No time zone matches")
                    color: Theme.inkMuted
                }
            }
        }
    }

    SegGroup {
        title: Lang.t("Clock in the bar")
        SegItem {
            icon: "schedule"
            hue: 2
            lobes: 4
            title: Lang.t("24-hour clock")
            description: Config.clock24h ? Lang.t("Shown as 19:30") : Lang.t("Shown as 7:30 PM")
            Toggle { checked: Config.clock24h; onToggled: v => Config.clock24h = v }
        }
        SegItem {
            icon: "timer_10_select"
            hue: 3
            lobes: 5
            title: Lang.t("Show seconds")
            description: Lang.t("Updates the bar every second.")
            Toggle { checked: Config.clockSeconds; onToggled: v => Config.clockSeconds = v }
        }
    }

    SegGroup {
        title: Lang.t("Weather")
        SegItem {
            icon: "partly_cloudy_day"
            hue: 4
            lobes: 8
            title: Lang.t("Weather in the calendar")
            description: Config.weatherPlace.length === 0 ? Lang.t("Off. Type your town to switch it on; only its name is sent to open-meteo.com.")
                : (Weather.ready ? Weather.temperature + "°, " + Weather.words(Weather.code) + " in " + Weather.where + "." : (Weather.problem || Lang.t("Looking it up…")))
            Rectangle {
                width: 220
                height: 46
                radius: town.activeFocus ? Theme.cornerM : height / 2
                color: Theme.surfaceContainerHighest
                border.width: town.activeFocus ? 2 : 0
                border.color: Theme.primary
                Behavior on radius { Spring {} }
                TextInput {
                    id: town
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    text: Config.weatherPlace
                    color: Theme.ink
                    selectionColor: Theme.primaryContainer
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    clip: true
                    onEditingFinished: Config.weatherPlace = text.trim()
                    Label { visible: town.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: Lang.t("Town"); color: Theme.inkMuted }
                }
            }
        }
    }

    SegGroup {
        title: Lang.t("Calendar")
        SegItem {
            icon: "notifications_active"
            hue: 1
            lobes: 6
            title: Lang.t("Remind me of events")
            description: Lang.t("A notification ten minutes before an event with a time.")
            Toggle { checked: Config.eventReminders; onToggled: v => Config.eventReminders = v }
        }
        Repeater {
            model: Config.calendars
            SegItem {
                id: feed
                required property string modelData
                icon: "event_repeat"
                hue: 2
                lobes: 7
                // Only the host is shown: the rest of such an address is a secret key.
                title: modelData.startsWith("/") ? modelData.replace(/^.*\//, "") : modelData.replace(/^[a-z]+:\/\//, "").replace(/\/.*$/, "")
                description: Events.loading ? Lang.t("Reading…") : (Events.problem || Lang.t("Shown in the calendar, read again every half hour."))
                IconBtn { icon: "delete"; size: 40; tonal: true; onClicked: Config.calendars = Config.calendars.filter(c => c !== feed.modelData) }
            }
        }
        SegItem {
            icon: "add_link"
            hue: 5
            lobes: 9
            title: Lang.t("Add a calendar")
            description: Lang.t("Paste its iCal address (ends in .ics), from Google, Nextcloud or your school. It is only read, never changed.")
            Rectangle {
                width: 260
                height: 46
                radius: link.activeFocus ? Theme.cornerM : height / 2
                color: Theme.surfaceContainerHighest
                border.width: link.activeFocus ? 2 : 0
                border.color: Theme.primary
                Behavior on radius { Spring {} }
                TextInput {
                    id: link
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.ink
                    selectionColor: Theme.primaryContainer
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    clip: true
                    function take() {
                        const t = text.trim()
                        if (/^(https?:\/\/|webcal:\/\/|\/)\S+$/.test(t) && !Config.calendars.includes(t)) { Config.calendars = Config.calendars.concat([t]); text = "" }
                    }
                    Keys.onReturnPressed: take()
                    Keys.onEnterPressed: take()
                    Label { visible: link.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "https://…/basic.ics"; color: Theme.inkMuted }
                }
            }
        }
    }
}
