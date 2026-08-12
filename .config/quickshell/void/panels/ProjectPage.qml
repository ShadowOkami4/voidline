import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    readonly property int requestedBodyHeight: 590
    signal back

    onActiveChanged: SystemActionService.projectPageActive = active
    Component.onDestruction: {
        if (SystemActionService.projectPageActive)
            SystemActionService.projectPageActive = false
    }

    function modeIcon(mode) {
        if (mode === "internal") return "laptop_windows"
        if (mode === "external") return "desktop_windows"
        if (mode === "duplicate") return "content_copy"
        return "space_dashboard"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        PanelHeader {
            Layout.fillWidth: true
            title: "Project"
            subtitle: SystemActionService.monitorCount === 1
                ? "Built-in display only"
                : SystemActionService.monitorCount + " displays available"
            onBack: root.back()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            Layout.maximumHeight: 104
            radius: Theme.radiusExtraLarge
            color: Theme.secondaryContainer

            RowLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 15

                Rectangle {
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 68
                    radius: Theme.radiusLarge
                    color: Theme.secondary

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.modeIcon(SystemActionService.projectionMode)
                        size: 32
                        color: Theme.accentInk
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Display arrangement"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: SystemActionService.projectionChanging
                            ? "Applying display mode…"
                            : "Current mode: " + SystemActionService.projectionMode
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: [
                    { mode: "internal", title: "PC screen", subtitle: "Primary display" },
                    { mode: "external", title: "Second screen", subtitle: "External only" },
                    { mode: "duplicate", title: "Duplicate", subtitle: "Mirror content" },
                    { mode: "extend", title: "Extend", subtitle: "More workspace" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: SystemActionService.projectionMode === modelData.mode
                    readonly property bool available: modelData.mode === "internal" || SystemActionService.monitorCount > 1

                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                    radius: Theme.radiusLarge
                    color: selected ? Theme.accentContainer : Theme.surfaceLow
                    opacity: available ? 1 : 0.42
                    scale: modeTap.pressed ? 0.975 : 1

                    RowLayout {
                        anchors { fill: parent; margins: 13 }
                        spacing: 11

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: parent.parent.selected ? Theme.accent : Theme.surfaceHigh

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.modeIcon(modelData.mode)
                                size: 23
                                color: parent.parent.parent.selected ? Theme.accentInk : Theme.textMuted
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: available ? modelData.subtitle : "Connect a display"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }

                    TapHandler {
                        id: modeTap
                        enabled: parent.available && !SystemActionService.projectionChanging
                        onTapped: SystemActionService.setProjectionMode(modelData.mode)
                    }

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on scale { NumberAnimation { duration: Motion.instant } }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 66
            radius: Theme.radiusLarge
            color: Theme.surfaceLow

            RowLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 12

                MaterialIcon {
                    text: "info"
                    size: 20
                    color: Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: SystemActionService.monitorCount > 1
                        ? "Changes are applied through Hyprland immediately."
                        : "Connect another monitor to unlock mirror, extend, and external-only modes."
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
