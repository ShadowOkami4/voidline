import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Lock and sleep: what happens when the computer is left alone.
ColumnLayout {
    id: page
    spacing: 24

    // What the system does when the lid closes or the power button is
    // pressed. These are system-wide settings (systemd-logind); changing
    // them asks for the administrator password.
    property string lid: ""
    property string button: ""
    property string buttonsNote: ""
    function readButtons() { buttonsRead.running = true }
    function setButtons(lidValue, buttonValue) {
        const ok = ["suspend", "lock", "ignore", "poweroff", "hibernate"]
        if (!ok.includes(lidValue) || !ok.includes(buttonValue)) return
        buttonsNote = ""
        buttonsWrite.command = ["pkexec", "sh", "-c",
            "mkdir -p /etc/systemd/logind.conf.d && printf '# Written by Voidline Settings\\n[Login]\\nHandleLidSwitch=%s\\nHandleLidSwitchExternalPower=%s\\nHandlePowerKey=%s\\n' \"$1\" \"$1\" \"$2\" > /etc/systemd/logind.conf.d/50-voidline.conf && systemctl kill -s HUP systemd-logind",
            "sh", lidValue, buttonValue]
        buttonsWrite.running = true
    }
    Process {
        id: buttonsRead
        running: true
        command: ["sh", "-c", "for p in HandleLidSwitch HandlePowerKey; do busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager $p 2>/dev/null | sed 's/^s \"\\(.*\\)\"$/'\"$p\"'=\\1/'; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const p = line.split("=")
                    if (p[0] === "HandleLidSwitch") page.lid = p[1]
                    else if (p[0] === "HandlePowerKey") page.button = p[1]
                }
            }
        }
    }
    Process {
        id: buttonsWrite
        onExited: code => { page.buttonsNote = code === 0 ? "" : Lang.t("Not changed. It needs your password."); page.readButtons() }
    }

    component Minutes: Choice {
        Layout.fillWidth: true
        options: [
            { value: 0, label: Lang.t("Never") },
            { value: 2, label: "2 min" },
            { value: 5, label: "5 min" },
            { value: 10, label: "10 min" },
            { value: 15, label: "15 min" },
            { value: 30, label: "30 min" },
            { value: 60, label: Lang.t("1 hour") }
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
            text: Lang.t("The timers are not available.")
        }
    }

    SegGroup {
        SegItem {
            icon: "lock"
            hue: 0
            lobes: 8
            title: Lang.t("Lock now")
            description: Lang.t("Also on Super + L and in quick settings.")
            clickable: true
            onClicked: Shell.lock()
        }
    }

    SegGroup {
        title: Lang.t("When left alone")
        opacity: Idle.hasSwayidle ? 1 : 0.5
        enabled: Idle.hasSwayidle
        SegItem {
            icon: "lock_clock"
            hue: 1
            lobes: 0
            title: Lang.t("Lock the screen")
            description: Config.lockAfter > 0 ? Lang.t("After ") + Config.lockAfter + Lang.t(" minutes without input.") : Lang.t("Only when you ask.")
            extra: Minutes { value: Config.lockAfter; onPicked: v => Config.lockAfter = v }
        }
        SegItem {
            icon: "desktop_access_disabled"
            hue: 2
            lobes: 4
            title: Lang.t("Turn the screen off")
            description: Config.screenOffAfter > 0 ? Lang.t("After ") + Config.screenOffAfter + Lang.t(" minutes. Any key or mouse movement wakes it.") : Lang.t("Stays on.")
            extra: Minutes { value: Config.screenOffAfter; onPicked: v => Config.screenOffAfter = v }
        }
        SegItem {
            icon: "bedtime"
            hue: 3
            lobes: 5
            title: Lang.t("Go to sleep")
            description: Config.sleepAfter > 0 ? Lang.t("After ") + Config.sleepAfter + Lang.t(" minutes.") : Lang.t("Never on its own.")
            extra: Minutes { value: Config.sleepAfter; onPicked: v => Config.sleepAfter = v }
        }
    }

    SegGroup {
        title: Lang.t("Sleep")
        SegItem {
            icon: "shield_lock"
            hue: 4
            lobes: 8
            title: Lang.t("Lock before sleep")
            description: Lang.t("Ask for your password after closing the lid or waking up.")
            Toggle { checked: Config.lockOnSleep; onToggled: v => Config.lockOnSleep = v }
        }
    }

    SegGroup {
        visible: page.lid.length > 0
        title: Lang.t("Lid and power button")
        SegItem {
            icon: "laptop_chromebook"
            hue: 5
            lobes: 0
            title: Lang.t("When the lid closes")
            description: page.buttonsNote || Lang.t("Asks for your password to change.")
            Dropdown {
                width: 220
                value: page.lid
                options: [
                    { value: "suspend", label: Lang.t("Sleep") },
                    { value: "lock", label: Lang.t("Lock") },
                    { value: "ignore", label: Lang.t("Do nothing") },
                    { value: "poweroff", label: Lang.t("Shut down") }
                ]
                onPicked: v => page.setButtons(v, page.button || "poweroff")
            }
        }
        SegItem {
            icon: "power_settings_new"
            hue: 0
            lobes: 5
            title: Lang.t("Power button")
            description: Lang.t("A short press. Holding it for several seconds always switches off.")
            Dropdown {
                width: 220
                value: page.button
                options: [
                    { value: "poweroff", label: Lang.t("Shut down") },
                    { value: "suspend", label: Lang.t("Sleep") },
                    { value: "lock", label: Lang.t("Lock") },
                    { value: "ignore", label: Lang.t("Do nothing") }
                ]
                onPicked: v => page.setButtons(page.lid || "suspend", v)
            }
        }
    }
}
