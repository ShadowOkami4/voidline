import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets
import qs.settings

// Shown once, the first time Voidline starts: pick a look and learn the three
// shortcuts that matter. Everything here can be changed later in Settings.
FloatingWindow {
    id: window

    title: "Welcome to Voidline"
    color: Theme.surface
    implicitWidth: 760
    implicitHeight: 720
    minimumSize: Qt.size(640, 600)
    onVisibleChanged: if (!visible) Config.welcomed = true

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            x: 36
            y: 32
            width: parent.width - 72
            spacing: 22

            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                Item {
                    implicitWidth: 84
                    implicitHeight: 84
                    Blob { anchors.fill: parent; lobes: 9; fill: Theme.primary }
                    MIcon { anchors.centerIn: parent; icon: "blur_on"; size: 40; color: Theme.inkOnPrimary }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Welcome to Voidline"; font.pixelSize: 36; font.weight: Font.Black; font.letterSpacing: -1 }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.inkMuted
                        text: "A desktop around " + (Compositor.name === "niri" ? "Niri" : "Hyprland") + ". Choose how it should look; you can change all of this later in Settings."
                    }
                }
            }

            SegGroup {
                title: "Layout"
                SegItem {
                    icon: "dashboard_customize"
                    hue: 0
                    lobes: 8
                    title: Config.style === "windows" ? "Windows" : (Config.style === "macos" ? "macOS" : "Voidline")
                    description: Config.style === "windows" ? "Taskbar at the bottom with your open windows."
                        : (Config.style === "macos" ? "Slim bar on top and a dock at the bottom." : "A bar that flows into a frame around the screen.")
                    extra: Choice {
                        Layout.fillWidth: true
                        value: Config.style
                        options: [
                            { value: "voidline", label: "Voidline" },
                            { value: "windows", label: "Windows" },
                            { value: "macos", label: "macOS" }
                        ]
                        onPicked: v => Config.style = v
                    }
                }
                SegItem {
                    icon: Config.dark ? "dark_mode" : "light_mode"
                    hue: 1
                    lobes: 0
                    title: "Dark theme"
                    Toggle { checked: Config.dark; onToggled: v => Config.dark = v }
                }
                SegItem {
                    icon: "format_size"
                    hue: 2
                    lobes: 4
                    title: "Size"
                    description: "The shell restarts briefly when this changes."
                    extra: Choice {
                        Layout.fillWidth: true
                        value: Config.uiScale
                        options: [
                            { value: 0.65, label: "Small" },
                            { value: 0.75, label: "Default" },
                            { value: 0.9, label: "Large" },
                            { value: 1.0, label: "Huge" }
                        ]
                        onPicked: v => Config.uiScale = v
                    }
                }
            }

            SegGroup {
                title: "Good to know"
                Repeater {
                    model: ["launcher", "quick", "settings", "lock"]
                    SegItem {
                        id: tip
                        required property string modelData
                        required property int index
                        readonly property var action: Keybinds.actions.find(a => a.id === modelData)
                        icon: action.icon
                        hue: index + 3
                        lobes: [5, 8, 0, 4][index]
                        title: action.label
                        Row {
                            spacing: 6
                            Repeater {
                                model: Keybinds.parts(Keybinds.combo(tip.modelData))
                                Rectangle {
                                    required property string modelData
                                    width: Math.max(38, cap.implicitWidth + 22)
                                    height: 38
                                    radius: Theme.cornerS
                                    color: Theme.surfaceContainerHighest
                                    border.width: 1
                                    border.color: Theme.outlineVariant
                                    Label { id: cap; anchors.centerIn: parent; text: parent.modelData; font.weight: Font.Bold; font.pixelSize: Theme.textLabel + 1 }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Pressable {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 54
                    color: Theme.surfaceContainerHighest
                    onClicked: { Config.welcomed = true; Shell.openSettings("colours") }
                    Label { anchors.centerIn: parent; text: "Pick a wallpaper"; font.weight: Font.DemiBold }
                }
                Pressable {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 54
                    color: Theme.primary
                    tint: Theme.inkOnPrimary
                    onClicked: Config.welcomed = true
                    Label { anchors.centerIn: parent; text: "Start using Voidline"; font.weight: Font.Bold; color: Theme.inkOnPrimary }
                }
            }
        }
    }
}
