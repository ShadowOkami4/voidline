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
            title: "Do not disturb"
            description: !Config.doNotDisturb ? "Notifications pop up as they arrive."
                : (Config.dndUntil > 0 ? "Quiet until " + Qt.formatDateTime(new Date(Config.dndUntil), "ddd HH:mm") + "." : "Notifications are collected quietly.")
            Toggle { checked: Config.doNotDisturb; onToggled: v => { Config.dndUntil = 0; Config.doNotDisturb = v } }
            extra: Choice {
                Layout.fillWidth: true
                value: -99
                options: [
                    { value: 1, label: "For 1 hour" },
                    { value: 3, label: "For 3 hours" },
                    { value: -1, label: "Until tomorrow 7:00" }
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
            title: "Time on screen"
            description: "Used when the app does not ask for its own."
            extra: Choice {
                Layout.fillWidth: true
                value: Config.notifTimeout
                options: [
                    { value: 3, label: "3 seconds" },
                    { value: 5, label: "5 seconds" },
                    { value: 8, label: "8 seconds" },
                    { value: 15, label: "15 seconds" }
                ]
                onPicked: v => Config.notifTimeout = v
            }
        }
        SegItem {
            icon: "stacks"
            hue: 2
            lobes: 4
            title: "Shown at once"
            description: "More than this wait in the notification list."
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
            title: "Keep urgent ones"
            description: "Urgent notifications stay until you dismiss them."
            Toggle { checked: Config.notifKeepUrgent; onToggled: v => Config.notifKeepUrgent = v }
        }
    }

    SegGroup {
        title: "Notification list"
        SegItem {
            icon: "inbox"
            hue: 4
            lobes: 8
            title: Notifs.list.length === 0 ? "No notifications" : (Notifs.list.length === 1 ? "1 notification" : Notifs.list.length + " notifications")
            description: "Open the list with the bell in quick settings."
            Pressable {
                visible: Notifs.list.length > 0
                width: clearLabel.implicitWidth + 36
                height: 40
                color: Theme.secondaryContainer
                tint: Theme.inkOnSecondaryContainer
                onClicked: Notifs.clear()
                Label { id: clearLabel; anchors.centerIn: parent; text: "Clear all"; font.weight: Font.DemiBold; color: Theme.inkOnSecondaryContainer }
            }
        }
        SegItem {
            icon: "send"
            hue: 5
            lobes: 4
            title: "Send a test notification"
            description: "Shows what a popup looks like with these settings."
            clickable: true
            onClicked: Quickshell.execDetached(["notify-send", "-a", "Voidline", "-i", "preferences-system",
                "Test notification", "This is what a notification looks like."])
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
                description: muted ? "Collected quietly, no popups." : "Popups allowed."
                Toggle { checked: !appRow.muted; onToggled: v => Notifs.setMuted(appRow.modelData, !v) }
            }
        }
    }
}
