import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Accessibility: make things larger, calmer and easier to see.
ColumnLayout {
    id: page
    spacing: 24

    // Text size of apps (GTK and many others read this).
    property real textScale: 1
    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "text-scaling-factor"]
        stdout: StdioCollector { onStreamFinished: page.textScale = parseFloat(text) || 1 }
    }
    function setTextScale(v) {
        textScale = v
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", String(v)])
    }

    SegGroup {
        title: "Seeing"
        SegItem {
            icon: "format_size"
            hue: 0
            lobes: 8
            title: "Size of the shell"
            description: "Bar, panels and Settings. The shell restarts briefly."
            extra: Choice {
                Layout.fillWidth: true
                value: Config.uiScale
                options: [
                    { value: 0.75, label: "Default" },
                    { value: 0.9, label: "Large" },
                    { value: 1.0, label: "Larger" },
                    { value: 1.2, label: "Largest" }
                ]
                onPicked: v => Config.uiScale = v
            }
        }
        SegItem {
            icon: "text_increase"
            hue: 1
            lobes: 0
            title: "Text size in apps"
            description: "Restart an app to see the new size."
            extra: Choice {
                Layout.fillWidth: true
                value: page.textScale
                options: [
                    { value: 1, label: "Default" },
                    { value: 1.15, label: "Large" },
                    { value: 1.3, label: "Larger" },
                    { value: 1.5, label: "Largest" }
                ]
                onPicked: v => page.setTextScale(v)
            }
        }
        SegItem {
            icon: "arrow_selector_tool"
            hue: 2
            lobes: 4
            title: "Mouse pointer size"
            description: "Easier to find on a large or bright screen."
            extra: Choice {
                Layout.fillWidth: true
                value: Appearance.cursorSize
                options: [
                    { value: 24, label: "Default" },
                    { value: 32, label: "Large" },
                    { value: 48, label: "Larger" },
                    { value: 64, label: "Largest" }
                ]
                onPicked: v => Appearance.setCursor(Appearance.cursorTheme || "Voidline", v)
            }
        }
    }

    SegGroup {
        title: "Motion and focus"
        SegItem {
            icon: "animation"
            hue: 3
            lobes: 5
            title: "Reduce motion"
            description: "Switches the shell's animations off."
            Toggle { checked: Config.reduceMotion; onToggled: v => Config.reduceMotion = v }
        }
        SegItem {
            icon: "blur_off"
            hue: 4
            lobes: 8
            title: "Calm windows"
            description: "No window animations, blur or shadows (the same switch as game mode)."
            Toggle { checked: Config.gameMode; onToggled: v => Config.gameMode = v }
        }
        SegItem {
            icon: "timer"
            hue: 5
            lobes: 0
            title: "Notifications stay longer"
            description: "Popups remain for 15 seconds."
            Toggle { checked: Config.notifTimeout >= 15; onToggled: v => Config.notifTimeout = v ? 15 : 5 }
        }
    }

    SegGroup {
        title: "Not available yet"
        SegItem {
            icon: "info"
            hue: 1
            lobes: 4
            title: "Screen reader and on-screen keyboard"
            description: "Voidline has neither of its own yet. The screen reader Orca and the keyboard wvkbd work with it when installed."
        }
    }
}
