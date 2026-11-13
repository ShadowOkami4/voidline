import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 24

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
        title: "This system"
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
