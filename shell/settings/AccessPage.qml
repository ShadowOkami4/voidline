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
        title: Lang.t("Seeing")
        SegItem {
            icon: "format_size"
            hue: 0
            lobes: 8
            title: Lang.t("Size of the shell")
            description: Lang.t("Bar, panels and Settings. The shell restarts briefly.")
            extra: Choice {
                Layout.fillWidth: true
                value: Config.uiScale
                options: [
                    { value: 0.75, label: Lang.t("Default") },
                    { value: 0.9, label: Lang.t("Large") },
                    { value: 1.0, label: Lang.t("Larger") },
                    { value: 1.2, label: Lang.t("Largest") }
                ]
                onPicked: v => Config.uiScale = v
            }
        }
        SegItem {
            icon: "text_increase"
            hue: 1
            lobes: 0
            title: Lang.t("Text size in apps")
            description: Lang.t("Restart an app to see the new size.")
            extra: Choice {
                Layout.fillWidth: true
                value: page.textScale
                options: [
                    { value: 1, label: Lang.t("Default") },
                    { value: 1.15, label: Lang.t("Large") },
                    { value: 1.3, label: Lang.t("Larger") },
                    { value: 1.5, label: Lang.t("Largest") }
                ]
                onPicked: v => page.setTextScale(v)
            }
        }
        SegItem {
            icon: "arrow_selector_tool"
            hue: 2
            lobes: 4
            title: Lang.t("Mouse pointer size")
            description: Lang.t("Easier to find on a large or bright screen.")
            extra: Choice {
                Layout.fillWidth: true
                value: Appearance.cursorSize
                options: [
                    { value: 24, label: Lang.t("Default") },
                    { value: 32, label: Lang.t("Large") },
                    { value: 48, label: Lang.t("Larger") },
                    { value: 64, label: Lang.t("Largest") }
                ]
                onPicked: v => Appearance.setCursor(Appearance.cursorTheme || "Voidline", v)
            }
        }
    }

    SegGroup {
        visible: Access.canSee
        title: Lang.t("Magnifier and colours")
        SegItem {
            icon: "zoom_in"
            hue: 4
            lobes: 8
            title: Lang.t("Magnifier")
            description: Config.zoom > 1 ? Lang.t("The screen is magnified %1 times around the pointer. Super + Alt + Minus zooms out.", Number(Config.zoom).toLocaleString(Lang.locale, "f", Config.zoom % 1 === 0 ? 0 : 2))
                : Lang.t("Magnifies the screen around the pointer. Super + Alt + Plus to zoom in, Super + Alt + Minus to zoom out.")
            Row {
                spacing: 6
                IconBtn { anchors.verticalCenter: parent.verticalCenter; icon: "remove"; size: 40; tonal: true; enabledInput: Config.zoom > 1; opacity: enabledInput ? 1 : 0.4; onClicked: Access.zoomOut() }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    horizontalAlignment: Text.AlignHCenter
                    text: Config.zoom > 1 ? Number(Config.zoom).toLocaleString(Lang.locale, "f", Config.zoom % 1 === 0 ? 0 : 2) + "×" : Lang.t("Off")
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.Black
                    color: Theme.primary
                }
                IconBtn { anchors.verticalCenter: parent.verticalCenter; icon: "add"; size: 40; tonal: true; enabledInput: Config.zoom < 8; opacity: enabledInput ? 1 : 0.4; onClicked: Access.zoomIn() }
            }
        }
        SegItem {
            icon: "palette"
            hue: 5
            lobes: 4
            title: Lang.t("Colour filter")
            description: Lang.t("Changes the colours of the whole screen, for colour blindness or less glare. Screenshots keep the real colours.")
            Dropdown {
                width: 250
                value: Config.colourFilter
                options: [
                    { value: "", label: Lang.t("None") },
                    { value: "deutan", label: Lang.t("Red-green (green weak)") },
                    { value: "protan", label: Lang.t("Red-green (red weak)") },
                    { value: "tritan", label: Lang.t("Blue-yellow") },
                    { value: "grayscale", label: Lang.t("Shades of grey") },
                    { value: "invert", label: Lang.t("Inverted colours") }
                ]
                onPicked: v => Config.colourFilter = v
            }
        }
    }

    SegGroup {
        title: Lang.t("Contrast")
        SegItem {
            icon: "contrast"
            hue: 3
            lobes: 5
            title: Lang.t("High contrast")
            description: Lang.t("Pure white or black text and stronger outlines in the shell.")
            Toggle { checked: Config.highContrast; onToggled: v => Config.highContrast = v }
        }
    }

    SegGroup {
        title: Lang.t("Motion and focus")
        SegItem {
            icon: "animation"
            hue: 3
            lobes: 5
            title: Lang.t("Reduce motion")
            description: Lang.t("Switches the shell's animations off.")
            Toggle { checked: Config.reduceMotion; onToggled: v => Config.reduceMotion = v }
        }
        SegItem {
            icon: "blur_off"
            hue: 4
            lobes: 8
            title: Lang.t("Calm windows")
            description: Lang.t("No window animations, blur or shadows (the same switch as game mode).")
            Toggle { checked: Config.gameMode; onToggled: v => Config.gameMode = v }
        }
        SegItem {
            icon: "timer"
            hue: 5
            lobes: 0
            title: Lang.t("Notifications stay longer")
            description: Lang.t("Popups remain for 15 seconds.")
            Toggle { checked: Config.notifTimeout >= 15; onToggled: v => Config.notifTimeout = v ? 15 : 5 }
        }
    }

    SegGroup {
        title: Lang.t("Without keyboard or sight")
        SegItem {
            icon: "keyboard"
            hue: 1
            lobes: 4
            title: Lang.t("On-screen keyboard")
            description: Access.canType ? Lang.t("Keys to tap or click at the bottom of the screen. Also on Super + Alt + K.")
                : Lang.t("Needs the package “wtype”.")
            Toggle {
                enabled: Access.canType
                opacity: enabled ? 1 : 0.5
                checked: Config.onScreenKeyboard
                onToggled: v => Config.onScreenKeyboard = v
            }
        }
        SegItem {
            icon: "tablet"
            hue: 3
            lobes: 0
            title: Lang.t("Tablet mode")
            description: Lang.t("Puts a keyboard button into the bar and lets you swipe between workspaces on a touch screen.")
            Toggle { checked: Config.tabletMode; onToggled: v => Config.tabletMode = v }
        }
        SegItem {
            icon: "record_voice_over"
            hue: 2
            lobes: 8
            title: Lang.t("Screen reader")
            description: Access.hasReader ? Lang.t("Orca reads apps aloud. Voidline's own bar and menus are not read yet.")
                : Lang.t("Needs the package “orca”.")
            Toggle {
                enabled: Access.hasReader
                opacity: enabled ? 1 : 0.5
                checked: Config.screenReader
                onToggled: v => Config.screenReader = v
            }
        }
    }
}
