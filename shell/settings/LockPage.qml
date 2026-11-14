import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Lock and sleep: what happens when the computer is left alone.
ColumnLayout {
    spacing: 24

    component Minutes: Choice {
        Layout.fillWidth: true
        options: [
            { value: 0, label: "Never" },
            { value: 2, label: "2 min" },
            { value: 5, label: "5 min" },
            { value: 10, label: "10 min" },
            { value: 15, label: "15 min" },
            { value: 30, label: "30 min" },
            { value: 60, label: "1 hour" }
        ]
    }

    Rectangle {
        visible: !Idle.hasSwayidle
        Layout.fillWidth: true
        implicitHeight: note.implicitHeight + 40
        radius: Theme.cornerXL
        color: Theme.tertiaryContainer
        Label {
            id: note
            x: 22
            y: 20
            width: parent.width - 44
            wrapMode: Text.Wrap
            color: Theme.inkOnTertiaryContainer
            text: "The timers are not available."
        }
    }

    SegGroup {
        SegItem {
            icon: "lock"
            hue: 0
            lobes: 8
            title: "Lock now"
            description: "Also on Super + L and in quick settings."
            clickable: true
            onClicked: Shell.lock()
        }
    }

    SegGroup {
        title: "When left alone"
        opacity: Idle.hasSwayidle ? 1 : 0.5
        enabled: Idle.hasSwayidle
        SegItem {
            icon: "lock_clock"
            hue: 1
            lobes: 0
            title: "Lock the screen"
            description: Config.lockAfter > 0 ? "After " + Config.lockAfter + " minutes without input." : "Only when you ask."
            extra: Minutes { value: Config.lockAfter; onPicked: v => Config.lockAfter = v }
        }
        SegItem {
            icon: "desktop_access_disabled"
            hue: 2
            lobes: 4
            title: "Turn the screen off"
            description: Config.screenOffAfter > 0 ? "After " + Config.screenOffAfter + " minutes. Any key or mouse movement wakes it." : "Stays on."
            extra: Minutes { value: Config.screenOffAfter; onPicked: v => Config.screenOffAfter = v }
        }
        SegItem {
            icon: "bedtime"
            hue: 3
            lobes: 5
            title: "Go to sleep"
            description: Config.sleepAfter > 0 ? "After " + Config.sleepAfter + " minutes." : "Never on its own."
            extra: Minutes { value: Config.sleepAfter; onPicked: v => Config.sleepAfter = v }
        }
    }

    SegGroup {
        title: "Sleep"
        SegItem {
            icon: "shield_lock"
            hue: 4
            lobes: 8
            title: "Lock before sleep"
            description: "Ask for your password after closing the lid or waking up."
            Toggle { checked: Config.lockOnSleep; onToggled: v => Config.lockOnSleep = v }
        }
    }
}
