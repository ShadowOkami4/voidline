import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 24

    SegGroup {
        SegItem {
            icon: Config.doNotDisturb ? "notifications_off" : "notifications_active"
            hue: 0
            lobes: 8
            title: Lang.t("Do not disturb")
            description: !Config.doNotDisturb ? Lang.t("Notifications pop up as they arrive.")
                : (Config.dndUntil > 0 ? Lang.t("Quiet until ") + Lang.date(new Date(Config.dndUntil), "ddd HH:mm") + "." : Lang.t("Notifications are collected quietly."))
            Toggle { checked: Config.doNotDisturb; onToggled: v => { Config.dndUntil = 0; Config.doNotDisturb = v } }
            extra: Choice {
                Layout.fillWidth: true
                value: -99
                options: [
                    { value: 1, label: Lang.t("For 1 hour") },
                    { value: 3, label: Lang.t("For 3 hours") },
                    { value: -1, label: Lang.t("Until tomorrow 7:00") }
                ]
                onPicked: v => Notifs.quiet(v)
            }
        }
    }

    SegGroup {
        title: "Popups"
        SegItem {
            icon: "timer"
            hue: 1
            lobes: 0
            title: Lang.t("Time on screen")
            description: Lang.t("Used when the app does not ask for its own.")
            extra: Choice {
                Layout.fillWidth: true
                value: Config.notifTimeout
                options: [
                    { value: 3, label: Lang.t("3 seconds") },
                    { value: 5, label: Lang.t("5 seconds") },
                    { value: 8, label: Lang.t("8 seconds") },
                    { value: 15, label: Lang.t("15 seconds") }
                ]
                onPicked: v => Config.notifTimeout = v
            }
        }
        SegItem {
            icon: "stacks"
            hue: 2
            lobes: 4
            title: Lang.t("Shown at once")
            description: Lang.t("More than this wait in the notification list.")
            Row {
                spacing: 4
                IconBtn { icon: "remove"; size: 40; tonal: true; onClicked: Config.notifMaxPopups = Math.max(1, Config.notifMaxPopups - 1) }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    horizontalAlignment: Text.AlignHCenter
                    text: Config.notifMaxPopups
                    font.pixelSize: Theme.textTitle + 2
                    font.weight: Font.Black
                }
                IconBtn { icon: "add"; size: 40; tonal: true; onClicked: Config.notifMaxPopups = Math.min(6, Config.notifMaxPopups + 1) }
            }
        }
        SegItem {
            icon: "priority_high"
            hue: 3
            lobes: 5
            title: Lang.t("Keep urgent ones")
            description: Lang.t("Urgent notifications stay until you dismiss them.")
            Toggle { checked: Config.notifKeepUrgent; onToggled: v => Config.notifKeepUrgent = v }
        }
    }

    SegGroup {
        title: Lang.t("Notification list")
        SegItem {
            icon: "inbox"
            hue: 4
            lobes: 8
            title: Notifs.list.length === 0 ? Lang.t("No notifications") : (Notifs.list.length === 1 ? Lang.t("1 notification") : Notifs.list.length + Lang.t(" notifications"))
            description: Lang.t("Open the list with the bell in quick settings.")
            Pressable {
                visible: Notifs.list.length > 0
                width: clearLabel.implicitWidth + 36
                height: 40
                color: Theme.secondaryContainer
                tint: Theme.inkOnSecondaryContainer
                onClicked: Notifs.clear()
                Label { id: clearLabel; anchors.centerIn: parent; text: Lang.t("Clear all"); font.weight: Font.DemiBold; color: Theme.inkOnSecondaryContainer }
            }
        }
        SegItem {
            icon: "send"
            hue: 5
            lobes: 4
            title: Lang.t("Send a test notification")
            description: Lang.t("Shows what a popup looks like with these settings.")
            clickable: true
            onClicked: Quickshell.execDetached(["notify-send", "-a", "Voidline", "-i", "voidline-notifications_active",
                Lang.t("Test notification"), Lang.t("This is what a notification looks like.")])
        }
    }

    SegGroup {
        visible: Notifs.apps.length > 0
        title: "Apps"
        Repeater {
            model: Notifs.apps
            SegItem {
                id: appRow
                required property string modelData
                required property int index
                readonly property bool muted: Config.notifMuted.includes(modelData)
                icon: muted ? "notifications_off" : "notifications"
                hue: index
                lobes: [8, 0, 4, 5][index % 4]
                title: modelData
                description: muted ? Lang.t("Collected quietly, no popups.") : Lang.t("Popups allowed.")
                Toggle { checked: !appRow.muted; onToggled: v => Notifs.setMuted(appRow.modelData, !v) }
            }
        }
    }
}
