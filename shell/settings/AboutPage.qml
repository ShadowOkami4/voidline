import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    spacing: 24

    // Read once when the page opens.
    property var facts: ({})
    Process {
        running: true
        command: ["sh", "-c", "echo \"host=$(cat /etc/hostname 2>/dev/null)\"; . /etc/os-release 2>/dev/null; echo \"os=$PRETTY_NAME\"; echo \"kernel=$(uname -r)\"; echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')\"; echo \"mem=$(awk '/MemTotal/ {printf \"%.0f\", $2/1048576}' /proc/meminfo)\"; echo \"gpu=$(lspci 2>/dev/null | grep -m1 -iE 'vga|3d|display' | sed -E 's/.*: //; s/ \\(rev.*//')\"; echo \"model=$(cat /sys/class/dmi/id/product_version 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                page.facts = out
            }
        }
    }
    // Hero: big type next to an oversized expressive shape.
    ClippingRectangle {
        Layout.fillWidth: true
        implicitHeight: 190
        radius: Theme.cornerXXL
        color: Theme.primaryContainer

        Blob {
            x: parent.width - width * 0.72
            y: -height * 0.18
            size: 300
            lobes: 9
            turn: 0.3
            fill: Theme.primary
            opacity: 0.9
        }
        Blob {
            x: parent.width - 150
            y: 96
            size: 120
            lobes: 4
            turn: 0.5
            fill: Theme.tertiary
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 32
            spacing: 6
            Label {
                text: "Voidline"
                font.pixelSize: 56
                font.weight: Font.Black
                font.letterSpacing: -1.5
                color: Theme.inkOnPrimaryContainer
            }
            Rectangle {
                width: versionLabel.implicitWidth + 24
                height: 30
                radius: 15
                color: Theme.inkOnPrimaryContainer
                Label {
                    id: versionLabel
                    anchors.centerIn: parent
                    text: Shell.version
                    font.pixelSize: Theme.textLabel
                    font.weight: Font.Bold
                    color: Theme.primaryContainer
                }
            }
        }
    }

    SegGroup {
        title: "This computer"
        SegItem { icon: "computer"; hue: 0; lobes: 8; title: page.facts.host || "Computer"; description: page.facts.model || "" }
        SegItem { icon: "deployed_code"; hue: 1; lobes: 4; title: "Operating system"; description: (page.facts.os || "") + (page.facts.kernel ? "  ·  Linux " + page.facts.kernel : "") }
        SegItem { icon: "memory"; hue: 2; lobes: 0; title: "Processor"; description: page.facts.cpu || "" }
        SegItem { icon: "memory_alt"; hue: 3; lobes: 5; title: "Memory"; description: page.facts.mem ? page.facts.mem + " GB" : "" }
        SegItem { icon: "developer_board"; hue: 4; lobes: 8; title: "Graphics"; description: page.facts.gpu || "" }
    }

    // Counts pending updates without changing anything (pacman-contrib).
    property string updates: ""
    property bool checking: false
    Process {
        id: check
        command: ["sh", "-c", "command -v checkupdates >/dev/null || { echo missing; exit 0; }; checkupdates 2>/dev/null | wc -l"]
        onStarted: page.checking = true
        stdout: StdioCollector { onStreamFinished: { page.updates = text.trim(); page.checking = false } }
    }
    SegGroup {
        title: "Software"
        SegItem {
            icon: "system_update_alt"
            hue: 0
            lobes: 5
            title: page.checking ? "Checking…" : (page.updates === "" ? "Updates"
                : (page.updates === "missing" ? "Updates" : (page.updates === "0" ? "Up to date" : page.updates + " updates available")))
            description: page.updates === "missing" ? "Checking needs the package “pacman-contrib”."
                : (parseInt(page.updates) > 0 ? "Install them in a terminal with:  sudo pacman -Syu" : "Looks for new package versions. Nothing is installed.")
            clickable: !page.checking
            onClicked: check.running = true
            MIcon { icon: "refresh"; size: 22; color: Theme.inkMuted }
        }
    }

    SegGroup {
        title: "Shell"
        SegItem {
            icon: "window"
            hue: 1
            lobes: 4
            title: "Window manager"
            description: Compositor.name === "hyprland" ? "Hyprland" : (Compositor.name === "niri" ? "Niri" : "Not detected")
        }
        SegItem {
            icon: "widgets"
            hue: 2
            lobes: 8
            title: "Built with"
            description: "Quickshell and Material 3 Expressive"
        }
        SegItem {
            icon: "description"
            hue: 3
            lobes: 0
            title: "Settings file"
            description: Config.path.replace(Quickshell.env("HOME"), "~")
        }
    }

    SegGroup {
        title: "Project"
        SegItem {
            icon: "code"
            hue: 4
            lobes: 5
            title: "Source code"
            description: "github.com/ShadowOkami4/voidline"
            clickable: true
            onClicked: Apps.openUrl("https://github.com/ShadowOkami4/voidline")
            MIcon { icon: "arrow_outward"; size: 22; color: Theme.inkMuted }
        }
        SegItem {
            icon: "public"
            hue: 5
            lobes: 8
            title: "Website"
            description: "shadowokami.com/Voidline"
            clickable: true
            onClicked: Apps.openUrl("https://shadowokami.com/Voidline")
            MIcon { icon: "arrow_outward"; size: 22; color: Theme.inkMuted }
        }
    }
}
