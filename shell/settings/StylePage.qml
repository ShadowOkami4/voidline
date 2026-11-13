import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

ColumnLayout {
    spacing: 24

    // Three large cards with a drawn miniature of each layout.
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Repeater {
            model: [
                { id: "voidline", name: "Voidline", text: "Connected bar, screen frame and panels that grow out of it." },
                { id: "windows", name: "Windows", text: "Taskbar at the bottom with a start menu and running apps." },
                { id: "macos", name: "macOS", text: "Menu bar on top and a floating dock." }
            ]

            Pressable {
                id: card
                required property var modelData
                readonly property bool current: Config.style === modelData.id
                readonly property color ink: current ? Theme.inkOnPrimaryContainer : Theme.ink

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                implicitHeight: column.implicitHeight + 28
                color: current ? Theme.primaryContainer : Theme.surfaceContainerHigh
                restRadius: current ? Theme.cornerXXL : Theme.cornerXL
                pressedRadius: Theme.cornerL
                Behavior on color { Tint {} }
                onClicked: Config.style = modelData.id

                ColumnLayout {
                    id: column
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 12

                    // Miniature screen
                    ClippingRectangle {
                        id: mini
                        Layout.fillWidth: true
                        implicitHeight: width * 0.6
                        radius: card.current ? Theme.cornerXL : Theme.cornerL
                        color: Theme.surface
                        Behavior on radius { Spring {} }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.tertiaryContainer }
                                GradientStop { position: 1; color: Theme.surface }
                            }
                        }

                        readonly property color bar: Theme.surfaceContainerLow
                        readonly property string kind: card.modelData.id

                        // Voidline: bar + frame + attached panel
                        Item {
                            anchors.fill: parent
                            visible: mini.kind === "voidline"
                            Rectangle { width: parent.width; height: 12; color: mini.bar }
                            Rectangle { width: 3; height: parent.height; color: mini.bar }
                            Rectangle { x: parent.width - 3; width: 3; height: parent.height; color: mini.bar }
                            Rectangle { y: parent.height - 3; width: parent.width; height: 3; color: mini.bar }
                            Rectangle { x: parent.width - 3 - width; y: 12; width: parent.width * 0.28; height: parent.height * 0.5; color: mini.bar; bottomLeftRadius: 8 }
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 4; width: 22; height: 4; radius: 2; color: Theme.primary }
                        }
                        // Windows: bottom taskbar + start menu
                        Item {
                            anchors.fill: parent
                            visible: mini.kind === "windows"
                            Rectangle { y: parent.height - 14; width: parent.width; height: 14; color: mini.bar }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height - 11
                                spacing: 3
                                Repeater { model: 4; Rectangle { required property int index; width: 8; height: 8; radius: 2; color: index === 0 ? Theme.primary : Theme.inkMuted } }
                            }
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 14 - height - 4; width: parent.width * 0.36; height: parent.height * 0.45; radius: 6; color: mini.bar }
                        }
                        // macOS: menu bar + dock
                        Item {
                            anchors.fill: parent
                            visible: mini.kind === "macos"
                            Rectangle { width: parent.width; height: 8; color: mini.bar; opacity: 0.85 }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height - height - 4
                                width: parent.width * 0.42
                                height: 16
                                radius: 6
                                color: mini.bar
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater { model: 5; Rectangle { required property int index; width: 9; height: 9; radius: 3; color: index === 0 ? Theme.primary : Theme.inkMuted } }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Label {
                            Layout.fillWidth: true
                            text: card.modelData.name
                            font.pixelSize: Theme.textTitle + 2
                            font.weight: Font.Black
                            color: card.ink
                        }
                        Item {
                            implicitWidth: 26
                            implicitHeight: 26
                            scale: card.current ? 1 : 0
                            Behavior on scale { Spring {} }
                            Blob { anchors.fill: parent; lobes: 8; fill: Theme.primary }
                            MIcon { anchors.centerIn: parent; icon: "check"; size: 16; color: Theme.inkOnPrimary }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.bottomMargin: 2
                        text: card.modelData.text
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.textLabel + 1
                        color: card.ink
                        opacity: 0.8
                    }
                }
            }
        }
    }

    SegGroup {
        title: "Good to know"
        SegItem {
            icon: "keyboard"
            hue: 1
            lobes: 4
            title: "Switch from the keyboard"
            description: "Super + Alt + S moves to the next style."
        }
        SegItem {
            icon: "minimize"
            hue: 2
            lobes: 8
            title: "Minimise windows"
            description: "Super + N hides the focused window; it stays in the taskbar or dock. Super + Shift + N brings the last one back."
        }
    }
}
