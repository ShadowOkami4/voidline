import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../panels"
import "../services"

// The bar supports five styles (Appearance.barStyle):
//   frame     solid rail joined to the screen frame; panels attach to it
//   islands   each group floats as its own pill
//   floating  one detached, rounded rail
//   minimal   no surface; a soft scrim keeps content legible
//   taskbar   bottom dock with App Center, pinned and running apps; it hides
//             below the screen edge until the pointer touches the edge
// Only "frame" draws the concave joins and attached panels.
PanelWindow {
    id: bar

    readonly property string position: Appearance.barPosition
    readonly property bool horizontal: position === "top" || position === "bottom"
    readonly property string barStyle: Appearance.barStyle
    readonly property bool framed: barStyle === "frame"
    readonly property bool islands: barStyle === "islands"
    readonly property bool floating: barStyle === "floating"
    readonly property bool minimal: barStyle === "minimal"
    readonly property bool taskbar: barStyle === "taskbar" && horizontal
    readonly property int curveSize: Theme.concaveRadius
    // Detached styles keep a gap to the screen edge.
    readonly property int edgeGap: Theme.barEdgeGap
    readonly property int railSize: Theme.barThickness
    readonly property int islandPadding: Metrics.spaceM
    readonly property color islandColor: Theme.panel
    // Auto-hide (taskbar only): reserve no space and slide the dock away
    // unless the pointer is on it or one of its panels is open.
    readonly property bool autoHide: taskbar && Appearance.taskbarAutoHide
    readonly property bool panelOpen: ShellState.isControlCenterScreen(screen)
        || ShellState.isLauncherScreen(screen)
        || ShellState.isMusicScreen(screen)
        || ShellState.isClockScreen(screen)
    property bool pointerHeld: false
    readonly property bool revealed: !autoHide || pointerHeld || panelOpen
    readonly property int hideOffset: revealed ? 0 : railSize + edgeGap + Metrics.spaceS
    readonly property int revealTriggerSize: Math.max(2, Math.round(3 * Metrics.scale))

    anchors {
        top: position !== "bottom"
        bottom: position !== "top"
        left: position !== "right"
        right: position !== "left"
    }

    implicitWidth: horizontal ? 0 : railSize + (framed ? curveSize : edgeGap * 2)
    implicitHeight: horizontal ? railSize + (framed ? curveSize : edgeGap * 2) : 0
    exclusiveZone: autoHide ? 0 : railSize + edgeGap
    color: "transparent"

    // While auto-hidden only a thin strip on the screen edge takes input;
    // when shown, only the three islands do, so the gaps stay click-through.
    mask: autoHide ? autoHideMask : null

    Region {
        id: autoHideMask
        Region {
            x: 0
            y: bar.height - bar.revealTriggerSize
            width: bar.width
            height: bar.revealTriggerSize
        }
        Region {
            x: barSurface.x + taskbarLeft.x
            y: bar.revealed ? barSurface.y : bar.height
            width: taskbarLeft.width
            height: bar.revealed ? barSurface.height : 0
        }
        Region {
            x: barSurface.x + taskbarCenter.x
            y: bar.revealed ? barSurface.y : bar.height
            width: taskbarCenter.width
            height: bar.revealed ? barSurface.height : 0
        }
        Region {
            x: barSurface.x + taskbarRight.x
            y: bar.revealed ? barSurface.y : bar.height
            width: taskbarRight.width
            height: bar.revealed ? barSurface.height : 0
        }
    }

    HoverHandler {
        enabled: bar.autoHide
        onHoveredChanged: {
            if (hovered) {
                autoHideDelay.stop()
                bar.pointerHeld = true
            } else {
                autoHideDelay.restart()
            }
        }
    }

    Timer {
        id: autoHideDelay
        interval: 650
        onTriggered: bar.pointerHeld = false
    }

    Item {
        id: barSurface
        x: bar.framed ? (position === "right" ? curveSize : 0) : bar.edgeGap
        y: (bar.framed ? (position === "bottom" ? curveSize : 0) : bar.edgeGap) + bar.hideOffset
        width: horizontal ? bar.width - (bar.framed ? 0 : bar.edgeGap * 2) : railSize
        height: horizontal ? railSize : bar.height - (bar.framed ? 0 : bar.edgeGap * 2)
        opacity: Appearance.barVisible ? 1 : 0
        scale: Appearance.barVisible ? 1 : 0.985

        Behavior on y {
            enabled: bar.autoHide
            NumberAnimation {
                duration: bar.revealed ? Motion.springDefault : Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: bar.revealed ? Motion.spatialDefault : Motion.effectsFast
            }
        }

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

        // Rail surface for frame and floating.
        Rectangle {
            anchors.fill: parent
            visible: bar.framed || bar.floating
            radius: bar.floating ? Math.min(width, height) / 2 : 0
            color: Theme.panel
        }

        // Minimal: a scrim fading away from the screen edge.
        Rectangle {
            visible: bar.minimal
            anchors.fill: parent
            anchors.margins: -Metrics.spaceS
            gradient: Gradient {
                orientation: bar.horizontal ? Gradient.Vertical : Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: bar.position === "top" || bar.position === "left"
                        ? Theme.withAlpha(Theme.background, 0.72) : "transparent"
                }
                GradientStop {
                    position: 1
                    color: bar.position === "top" || bar.position === "left"
                        ? "transparent" : Theme.withAlpha(Theme.background, 0.72)
                }
            }
        }

        // Pill drawn behind one group in the islands style.
        component IslandBackground: Rectangle {
            property Item target
            visible: bar.islands && target && target.visible
                && target.width > 0 && target.height > 0
            x: bar.horizontal ? target.x - bar.islandPadding : 0
            y: bar.horizontal ? 0 : target.y - bar.islandPadding
            width: bar.horizontal ? target.width + bar.islandPadding * 2 : parent.width
            height: bar.horizontal ? parent.height : target.height + bar.islandPadding * 2
            radius: Math.min(width, height) / 2
            color: bar.islandColor
        }

        // ---------------- horizontal: three groups ----------------
        Item {
            anchors {
                fill: parent
                leftMargin: bar.framed ? 20 + bar.curveSize : (bar.islands ? bar.islandPadding : 16)
                rightMargin: bar.framed ? 20 + bar.curveSize : (bar.islands ? bar.islandPadding : 16)
            }
            visible: bar.horizontal && !bar.taskbar

            IslandBackground { target: leftGroup }
            IslandBackground { target: centerGroup }
            IslandBackground { target: rightGroup }

            RowLayout {
                id: leftGroup
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

            WorkspaceGroup {
                id: centerGroup
                anchors.centerIn: parent
                shellScreen: bar.screen
            }

            RowLayout {
                id: rightGroup
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

        // ---------------- taskbar ----------------
        Item {
            anchors.fill: parent
            visible: bar.taskbar

            Rectangle {
                id: taskbarLeft
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: taskbarWorkspaces.implicitWidth + bar.islandPadding * 2
                radius: height / 2
                color: bar.islandColor

                WorkspaceIndicator {
                    id: taskbarWorkspaces
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                id: taskbarCenter
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    bottom: parent.bottom
                }
                width: dock.implicitWidth + bar.islandPadding * 2
                radius: height / 2
                color: bar.islandColor

                TaskbarDock {
                    id: dock
                    anchors.centerIn: parent
                    shellScreen: bar.screen
                }
            }

            Rectangle {
                id: taskbarRight
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                width: taskbarStatus.implicitWidth + bar.islandPadding * 2
                radius: height / 2
                color: bar.islandColor

                RowLayout {
                    id: taskbarStatus
                    anchors.centerIn: parent
                    spacing: 7
                    TrayGroup {
                        barWindow: bar
                        barPosition: bar.position
                    }
                    MusicButton {
                        shellScreen: bar.screen
                        visible: Appearance.musicPlacement !== "hidden"
                    }
                    StatusGroup {
                        panelActive: ShellState.isControlCenterScreen(bar.screen)
                        onClicked: ShellState.toggleControlCenter(bar.screen)
                    }
                    ClockGroup { shellScreen: bar.screen }
                }
            }
        }

        // ---------------- vertical: three groups ----------------
        Item {
            anchors {
                fill: parent
                topMargin: bar.islands ? bar.islandPadding : 10
                bottomMargin: bar.islands ? bar.islandPadding : 10
            }
            visible: !bar.horizontal

            IslandBackground { target: topColumn }
            IslandBackground { target: middleColumn }
            IslandBackground { target: bottomColumn }

            ColumnLayout {
                id: topColumn
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

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
            }

            ColumnLayout {
                id: middleColumn
                anchors.centerIn: parent
                spacing: 8

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
            }

            ColumnLayout {
                id: bottomColumn
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

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
    }

    ConcaveJoin {
        id: firstCorner
        visible: bar.framed
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
        visible: bar.framed
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
