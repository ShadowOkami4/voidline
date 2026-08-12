import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../panels"
import "../services"

PanelWindow {
    id: bar

    readonly property string position: Appearance.barPosition
    readonly property bool horizontal: position === "top" || position === "bottom"
    readonly property int curveSize: Theme.concaveRadius
    readonly property int railSize: horizontal ? Theme.barHeight : Theme.sideBarWidth

    anchors {
        top: position !== "bottom"
        bottom: position !== "top"
        left: position !== "right"
        right: position !== "left"
    }

    implicitWidth: horizontal ? 0 : railSize + curveSize
    implicitHeight: horizontal ? railSize + curveSize : 0
    exclusiveZone: railSize
    color: "transparent"

    Rectangle {
        id: barSurface
        x: position === "right" ? curveSize : 0
        y: position === "bottom" ? curveSize : 0
        width: horizontal ? bar.width : railSize
        height: horizontal ? railSize : bar.height
        color: Theme.panel
        opacity: Appearance.barVisible ? 1 : 0
        scale: Appearance.barVisible ? 1 : 0.985

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.barVisible ? Motion.barRelocateIn : Motion.barRelocateOut
                easing.type: Appearance.barVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.barVisible ? Motion.barRelocateIn : Motion.barRelocateOut
                easing.type: Appearance.barVisible ? Easing.OutQuart : Easing.InCubic
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 20 + bar.curveSize
                rightMargin: 20 + bar.curveSize
            }
            spacing: 0
            visible: bar.horizontal

            Item {
                Layout.preferredWidth: (barSurface.width - 40 - bar.curveSize * 2) / 3
                Layout.fillHeight: true
                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    ClockGroup { shellScreen: bar.screen }
                    WorkspaceIndicator {
                        visible: Appearance.workspacePlacement === "clock"
                    }
                    MusicButton {
                        shellScreen: bar.screen
                        visible: Appearance.musicPlacement === "clock"
                    }
                }
            }

            Item {
                Layout.preferredWidth: (barSurface.width - 40 - bar.curveSize * 2) / 3
                Layout.fillHeight: true
                WorkspaceGroup {
                    anchors.centerIn: parent
                    shellScreen: bar.screen
                }
            }

            Item {
                Layout.preferredWidth: (barSurface.width - 40 - bar.curveSize * 2) / 3
                Layout.fillHeight: true
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    TrayGroup {
                        barWindow: bar
                        barPosition: bar.position
                    }
                    MusicButton {
                        shellScreen: bar.screen
                        visible: Appearance.musicPlacement === "action"
                    }
                    WorkspaceIndicator {
                        visible: Appearance.workspacePlacement === "action"
                    }
                    StatusGroup {
                        panelActive: ShellState.isControlCenterScreen(bar.screen)
                        onClicked: ShellState.toggleControlCenter(bar.screen)
                    }
                }
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                topMargin: 10
                bottomMargin: 10
            }
            spacing: 8
            visible: !bar.horizontal

            ClockGroup {
                Layout.alignment: Qt.AlignHCenter
                vertical: true
                shellScreen: bar.screen
            }

            MusicButton {
                Layout.alignment: Qt.AlignHCenter
                shellScreen: bar.screen
                visible: Appearance.musicPlacement === "clock"
            }

            WorkspaceIndicator {
                Layout.alignment: Qt.AlignHCenter
                vertical: true
                visible: Appearance.workspacePlacement === "clock"
            }

            Item { Layout.fillHeight: true }

            MusicButton {
                Layout.alignment: Qt.AlignHCenter
                shellScreen: bar.screen
                visible: Appearance.musicPlacement === "bar"
            }

            IconButton {
                Layout.alignment: Qt.AlignHCenter
                icon: "apps"
                accessibleName: "Launcher"
                active: ShellState.isLauncherScreen(bar.screen)
                onClicked: ShellState.toggleLauncher(bar.screen)
            }

            WorkspaceIndicator {
                Layout.alignment: Qt.AlignHCenter
                vertical: true
                visible: Appearance.workspacePlacement === "center"
            }

            Item { Layout.fillHeight: true }

            MusicButton {
                Layout.alignment: Qt.AlignHCenter
                shellScreen: bar.screen
                visible: Appearance.musicPlacement === "action"
            }

            WorkspaceIndicator {
                Layout.alignment: Qt.AlignHCenter
                vertical: true
                visible: Appearance.workspacePlacement === "action"
            }

            TrayGroup {
                Layout.alignment: Qt.AlignHCenter
                barWindow: bar
                barPosition: bar.position
                vertical: true
            }

            IconButton {
                Layout.alignment: Qt.AlignHCenter
                icon: SystemActionService.hotspotActive ? "wifi_tethering"
                    : (ConnectivityService.ethernetConnected ? "lan"
                        : (ConnectivityService.wifiConnected ? "wifi"
                            : (ConnectivityService.wifiEnabled ? "wifi_find" : "signal_wifi_off")))
                accessibleName: "Action Center"
                active: ShellState.isControlCenterScreen(bar.screen)
                onClicked: ShellState.toggleControlCenter(bar.screen)
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: AudioService.outputMuted ? "volume_off" : "volume_up"
                size: 17
                color: AudioService.outputMuted ? Theme.textMuted : Theme.accent
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: PowerService.available
                text: PowerService.percentage + "%"
                color: PowerService.percentage <= 15 ? Theme.danger : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }
    }

    ConcaveJoin {
        id: firstCorner
        width: curveSize
        height: curveSize
        x: position === "right" ? 0 : (horizontal ? 0 : railSize)
        y: position === "bottom" ? 0 : (horizontal ? railSize : 0)
        fillColor: Theme.panel
        opacity: Appearance.barVisible ? 1 : 0
        scale: Appearance.barVisible ? 1 : 0.985
        orientation: position === "top" ? "top-right"
            : (position === "bottom" ? "bottom-right"
                : (position === "left" ? "top-right" : "top-left"))

        Behavior on opacity { NumberAnimation { duration: Appearance.barVisible ? Motion.barRelocateIn : Motion.barRelocateOut; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: Appearance.barVisible ? Motion.barRelocateIn : Motion.barRelocateOut; easing.type: Easing.InOutCubic } }
    }

    ConcaveJoin {
        id: secondCorner
        width: curveSize
        height: curveSize
        x: horizontal ? bar.width - width : (position === "left" ? railSize : 0)
        y: horizontal ? (position === "top" ? railSize : 0) : bar.height - height
        fillColor: Theme.panel
        opacity: Appearance.barVisible ? 1 : 0
        scale: Appearance.barVisible ? 1 : 0.985
        orientation: position === "top" ? "top-left"
            : (position === "bottom" ? "bottom-left"
                : (position === "left" ? "bottom-right" : "bottom-left"))

        Behavior on opacity { NumberAnimation { duration: Appearance.barVisible ? Motion.barRelocateIn : Motion.barRelocateOut; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: Appearance.barVisible ? Motion.barRelocateIn : Motion.barRelocateOut; easing.type: Easing.InOutCubic } }
    }

    ControlCenter { parentBar: bar }
    Launcher { parentBar: bar }
    MusicPanel { parentBar: bar }
    ClockPanel { parentBar: bar }
}
