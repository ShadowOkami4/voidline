import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// You, your password, the language of the system, and printers.
ColumnLayout {
    id: page
    spacing: 24

    property var facts: ({})
    property var locales: []
    property string problem: ""
    property string pendingLang: ""

    function refresh() { read.running = true }
    function terminal(command) {
        Quickshell.execDetached(["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF",
            Config.terminal, "-e", "sh", "-c", command + "; echo; echo 'Press Enter to close.'; read _"])
    }
    // "de_DE.UTF-8" -> "Deutsch (Deutschland)" where Qt knows the language.
    function pretty(code) {
        const l = Qt.locale(code.split(".")[0])
        return l.nativeLanguageName ? l.nativeLanguageName.charAt(0).toUpperCase() + l.nativeLanguageName.slice(1)
            + (l.nativeTerritoryName ? " (" + l.nativeTerritoryName + ")" : "") : code
    }

    Process {
        id: read
        running: true
        command: ["sh", "-c", "echo \"user=$USER\"; echo \"name=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1)\"; echo \"host=$(cat /etc/hostname 2>/dev/null)\"; echo \"admin=$(id -nG | tr ' ' '\\n' | grep -cx wheel)\"; echo \"lang=$(localectl status 2>/dev/null | sed -n 's/.*LANG=//p' | head -n 1)\"; echo \"printers=$(command -v system-config-printer >/dev/null && echo yes)\"; echo \"cups=$(systemctl is-active cups.service cups.socket 2>/dev/null | grep -c '^active')\"; locale -a 2>/dev/null | grep -i 'utf' | sed 's/^/locale=/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}, list = []
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i <= 0) continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "locale") list.push(v.replace(/utf8$/i, "UTF-8"))
                    else out[k] = v
                }
                page.facts = out
                page.locales = list.filter(l => !l.startsWith("C.") && !l.startsWith("POSIX"))
            }
        }
    }
    Process {
        id: setLang
        onExited: code => {
            page.problem = code === 0 ? "" : "The language was not changed. It needs your password."
            if (code === 0) page.pendingLang = setLang.command[setLang.command.length - 1].replace("LANG=", "")
            page.refresh()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 132
        radius: Theme.cornerXXL
        color: Theme.primaryContainer
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 22
            Item {
                implicitWidth: 76
                implicitHeight: 76
                Blob { anchors.fill: parent; lobes: 9; fill: Theme.primary }
                Label {
                    anchors.centerIn: parent
                    text: (page.facts.name || page.facts.user || "?").charAt(0).toUpperCase()
                    font.pixelSize: 34
                    font.weight: Font.Black
                    color: Theme.inkOnPrimary
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: page.facts.name || page.facts.user || ""
                    font.pixelSize: 30
                    font.weight: Font.Black
                    color: Theme.inkOnPrimaryContainer
                }
                Label {
                    text: (page.facts.user || "") + (page.facts.host ? " on " + page.facts.host : "")
                        + (page.facts.admin === "1" ? "  ·  administrator" : "")
                    font.weight: Font.DemiBold
                    color: Theme.inkOnPrimaryContainer
                    opacity: 0.85
                }
            }
        }
    }

    Rectangle {
        visible: page.problem.length > 0
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.cornerL
        color: Theme.errorContainer
        Label { anchors.verticalCenter: parent.verticalCenter; x: 20; text: page.problem; font.weight: Font.DemiBold; color: Theme.inkOnErrorContainer }
    }

    SegGroup {
        title: "Account"
        SegItem {
            icon: "password"
            hue: 0
            lobes: 8
            title: "Change password"
            description: "Opens a terminal that asks for the old and the new password."
            clickable: true
            onClicked: page.terminal("passwd")
            MIcon { icon: "arrow_outward"; size: 22; color: Theme.inkMuted }
        }
        SegItem {
            icon: "lock"
            hue: 1
            lobes: 0
            title: "Lock and sign-in"
            description: "When the screen locks on its own."
            clickable: true
            onClicked: Shell.openSettings("lock")
            MIcon { icon: "chevron_right"; size: 22; color: Theme.inkMuted }
        }
    }

    SegGroup {
        title: "Language and region"
        SegItem {
            icon: "translate"
            hue: 2
            lobes: 4
            title: "Language of the system"
            description: page.pendingLang.length > 0 ? "Changed. Log out and back in to see it everywhere."
                : "Used by apps for text, dates and numbers. Voidline itself is English for now. Asks for your password."
            Dropdown {
                width: 260
                value: page.pendingLang || page.facts.lang || ""
                options: page.locales.map(l => ({ value: l, label: page.pretty(l) }))
                onPicked: v => {
                    if (!/^[A-Za-z_@.0-9-]+$/.test(v)) return
                    setLang.command = ["localectl", "set-locale", "LANG=" + v]
                    setLang.running = true
                }
            }
        }
        SegItem {
            icon: "keyboard"
            hue: 3
            lobes: 5
            title: "Keyboard layout"
            description: "Set on the window manager page; switch layouts with Super + Alt + Space."
            clickable: true
            onClicked: Shell.openSettings("wm")
            MIcon { icon: "chevron_right"; size: 22; color: Theme.inkMuted }
        }
        SegItem {
            icon: "schedule"
            hue: 4
            lobes: 8
            title: "Date, time and time zone"
            clickable: true
            onClicked: Shell.openSettings("datetime")
            MIcon { icon: "chevron_right"; size: 22; color: Theme.inkMuted }
        }
    }

    SegGroup {
        title: "Printers and scanners"
        SegItem {
            icon: "print"
            hue: 5
            lobes: 0
            title: "Printers"
            description: page.facts.printers !== "yes" ? "Needs the packages “cups” and “system-config-printer”."
                : (page.facts.cups === "0" ? "The print service is not running. Start it with:  sudo systemctl enable --now cups.socket" : "Add and manage printers.")
            clickable: page.facts.printers === "yes"
            onClicked: Quickshell.execDetached(["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", "system-config-printer"])
            MIcon { visible: page.facts.printers === "yes"; icon: "arrow_outward"; size: 22; color: Theme.inkMuted }
        }
    }
}
