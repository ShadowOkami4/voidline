import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.widgets

ColumnLayout {
    spacing: 24

    SegGroup {
        title: "Size"
        SegItem {
            icon: "format_size"
            hue: 0
            lobes: 8
            title: "Interface size"
            description: "The shell restarts briefly to apply this."

            // Button group: the letters show the size you get.
            extra: RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [
                        { value: 0.65, label: "Small", px: 13 },
                        { value: 0.75, label: "Default", px: 16 },
                        { value: 0.9, label: "Large", px: 20 },
                        { value: 1.0, label: "Huge", px: 24 }
                    ]
                    Pressable {
                        id: size
                        required property var modelData
                        readonly property bool current: Math.abs(Config.uiScale - modelData.value) < 0.01
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 72
                        color: current ? Theme.primary : Theme.surfaceContainerHighest
                        tint: current ? Theme.inkOnPrimary : Theme.ink
                        restRadius: current ? Theme.cornerFull : Theme.cornerL
                        pressedRadius: Theme.cornerM
                        Behavior on color { Tint {} }
                        onClicked: Config.uiScale = modelData.value

                        Column {
                            anchors.centerIn: parent
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Aa"
                                font.pixelSize: size.modelData.px
                                font.weight: Font.Black
                                color: size.current ? Theme.inkOnPrimary : Theme.ink
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: size.modelData.label
                                font.pixelSize: Theme.textLabelS
                                color: size.current ? Theme.inkOnPrimary : Theme.inkMuted
                            }
                        }
                    }
                }
            }
        }
    }

    SegGroup {
        title: "Text"
        SegItem {
            icon: "font_download"
            hue: 1
            lobes: 0
            title: "Font"
            description: "Used everywhere in the shell: " + Theme.font
            extra: Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [""].concat(["Roboto Flex", "Roboto", "Inter", "Noto Sans", "Adwaita Sans", "Cantarell", "Open Sans", "Ubuntu", "DejaVu Sans", "Liberation Sans"]
                        .filter(f => Theme.families.includes(f)))
                    Pressable {
                        id: face
                        required property string modelData
                        readonly property bool current: Config.font === modelData
                        width: faceLabel.implicitWidth + 34
                        height: 42
                        color: current ? Theme.primary : Theme.surfaceContainerHighest
                        tint: current ? Theme.inkOnPrimary : Theme.ink
                        restRadius: current ? Theme.cornerFull : Theme.cornerM
                        Behavior on color { Tint {} }
                        onClicked: Config.font = modelData
                        Label {
                            id: faceLabel
                            anchors.centerIn: parent
                            text: face.modelData || "Automatic"
                            font.family: face.modelData || Theme.font
                            font.weight: Font.DemiBold
                            color: face.current ? Theme.inkOnPrimary : Theme.ink
                        }
                    }
                }
            }
        }
    }

    SegGroup {
        visible: Compositor.name === "hyprland"
        title: "Bar"
        SegItem {
            icon: "workspaces"
            hue: 2
            lobes: 4
            title: "Workspaces shown"
            description: "Minimum number of workspace dots in the bar."
            Row {
                spacing: 4
                IconBtn { icon: "remove"; size: 40; tonal: true; onClicked: Config.workspaceCount = Math.max(1, Config.workspaceCount - 1) }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    horizontalAlignment: Text.AlignHCenter
                    text: Config.workspaceCount
                    font.pixelSize: Theme.textTitle + 2
                    font.weight: Font.Black
                }
                IconBtn { icon: "add"; size: 40; tonal: true; onClicked: Config.workspaceCount = Math.min(20, Config.workspaceCount + 1) }
            }
        }
    }

    SegGroup {
        title: "Behaviour"
        SegItem {
            icon: "animation"
            hue: 4
            lobes: 5
            title: "Reduce motion"
            description: "Turn animations off."
            Toggle { checked: Config.reduceMotion; onToggled: v => Config.reduceMotion = v }
        }
    }
}
