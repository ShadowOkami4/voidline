import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../components"
import "../core"

PanelWindow {
    id: root

    property var parentBar
    property bool isOpen: parentBar && ShellState.isClockScreen(parentBar.screen)
    property bool isClosing: false
    property bool expanded: false
    property bool contentReady: false
    readonly property bool surfaceActive: isOpen || isClosing
    readonly property int cornerSize: Metrics.concaveRadius
    readonly property int targetWidth: Math.min(Metrics.panelMedium,
        parentBar && parentBar.screen ? Math.max(390, parentBar.screen.width - 48) : Metrics.panelMedium)
    readonly property int targetBodyHeight: Math.min(Math.round(680 * Metrics.scale),
        parentBar && parentBar.screen ? Math.max(520, parentBar.screen.height - Theme.barHeight - 32) : 680)
    readonly property int targetHeight: targetBodyHeight + cornerSize

    screen: parentBar ? parentBar.screen : null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: isOpen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-clock"
    visible: true
    color: "transparent"
    mask: Region {
        x: root.surfaceActive ? attachedSurface.x : 0
        y: root.surfaceActive ? attachedSurface.y : 0
        width: root.surfaceActive ? attachedSurface.width : 0
        height: root.surfaceActive ? attachedSurface.height : 0
    }
    HyprlandWindow.visibleMask: Region {
        x: root.surfaceActive ? attachedSurface.x : 0
        y: root.surfaceActive ? attachedSurface.y : 0
        width: root.surfaceActive ? attachedSurface.width : 0
        height: root.surfaceActive ? attachedSurface.height : 0
    }

    onIsOpenChanged: {
        if (isOpen) {
            const interruptedClose = isClosing
            closeTimer.stop()
            concealTimer.stop()
            isClosing = false
            if (!interruptedClose) {
                expanded = false
                contentReady = false
                expandTimer.restart()
            } else {
                expanded = true
            }
            revealTimer.restart()
        } else if (surfaceActive) {
            expandTimer.stop()
            revealTimer.stop()
            // Start the connected surface morph immediately. Previously the
            // calendar stayed fully expanded until closeTimer fired and then
            // vanished in one frame, so only its content appeared to animate.
            expanded = false
            isClosing = true
            concealTimer.restart()
            closeTimer.restart()
        }
    }

    Timer { id: expandTimer; interval: 16; onTriggered: root.expanded = true }
    Timer { id: revealTimer; interval: Motion.contentDelay; onTriggered: root.contentReady = true }
    Timer {
        id: concealTimer
        // Mirror the entry staging used by the other connected panels: begin
        // the content exit shortly after the surface starts retracting, and
        // let both finish together instead of clipping the calendar late.
        interval: Math.max(0,
            Motion.morphExit - Motion.contentDelay - Motion.pageExit)
        onTriggered: root.contentReady = false
    }
    Timer {
        id: closeTimer
        interval: Motion.morphExit + 16
        onTriggered: {
            root.isClosing = false
        }
    }

    HyprlandFocusGrab {
        active: root.isOpen
        windows: [root]
        onCleared: ShellState.closePanels()
    }

    Item {
        id: attachedSurface
        readonly property bool attached: Theme.panelsAttached
        readonly property bool topAttached: Appearance.barPosition === "top"
        readonly property bool bottomAttached: Appearance.barPosition === "bottom"
        readonly property bool leftAttached: Appearance.barPosition === "left"
        readonly property bool rightAttached: Appearance.barPosition === "right"

        x: topAttached || bottomAttached ? Theme.panelSideGap
            : (leftAttached ? Theme.panelInset
                : root.width - Theme.panelInset - width)
        y: topAttached ? Theme.panelInset
            : (bottomAttached ? root.height - Theme.panelInset - height : Theme.panelSideGap)
        width: root.expanded ? root.targetWidth + root.cornerSize
            : (topAttached || bottomAttached ? Math.round(142 * Metrics.scale) : 0)
        height: root.expanded ? root.targetHeight
            : (topAttached || bottomAttached ? 0 : Math.round(142 * Metrics.scale))
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: root.expanded ? Motion.morphEnter : Motion.morphExit
                easing.type: Motion.morphCurve
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.expanded ? Motion.morphEnter : Motion.morphExit
                easing.type: Motion.morphCurve
            }
        }

        ConcaveJoin {
            x: root.targetWidth; y: 0
            width: root.cornerSize; height: root.cornerSize
            orientation: "top-right"
            visible: attachedSurface.attached && attachedSurface.topAttached
        }
        ConcaveJoin {
            x: 0; y: root.targetBodyHeight
            width: root.cornerSize; height: root.cornerSize
            orientation: "top-right"
            visible: attachedSurface.attached && attachedSurface.topAttached
        }
        ConcaveJoin {
            x: root.targetWidth; y: root.targetBodyHeight
            width: root.cornerSize; height: root.cornerSize
            orientation: "bottom-right"
            visible: attachedSurface.attached && attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: 0; y: 0
            width: root.cornerSize; height: root.cornerSize
            orientation: "bottom-right"
            visible: attachedSurface.attached && attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: 0; y: root.targetBodyHeight
            width: root.cornerSize; height: root.cornerSize
            orientation: "left-bottom"
            visible: attachedSurface.attached && attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: root.targetWidth; y: 0
            width: root.cornerSize; height: root.cornerSize
            orientation: "top-right"
            visible: attachedSurface.attached && attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: root.targetWidth; y: root.targetBodyHeight
            width: root.cornerSize; height: root.cornerSize
            orientation: "top-left"
            visible: attachedSurface.attached && attachedSurface.rightAttached
        }
        ConcaveJoin {
            x: 0; y: 0
            width: root.cornerSize; height: root.cornerSize
            orientation: "top-left"
            visible: attachedSurface.attached && attachedSurface.rightAttached
        }

        Rectangle {
            id: body
            x: attachedSurface.rightAttached ? root.cornerSize : 0
            y: attachedSurface.bottomAttached ? root.cornerSize : 0
            width: Math.max(1, attachedSurface.width - root.cornerSize)
            height: Math.max(1, attachedSurface.height - root.cornerSize)
            radius: Theme.panelRadius
            color: Theme.panel
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && attachedSurface.topAttached || attachedSurface.leftAttached
                    || attachedSurface.rightAttached
            }
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && attachedSurface.bottomAttached
            }
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && !attachedSurface.rightAttached
            }
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && attachedSurface.rightAttached
            }

            ClockPage {
                id: clockPage
                anchors.fill: parent
                anchors.margins: Theme.panelPadding
                active: root.contentReady
                opacity: root.contentReady ? 1 : 0
                transform: Translate {
                    x: root.contentReady ? 0
                        : (attachedSurface.leftAttached ? -8
                            : (attachedSurface.rightAttached ? 8 : 0))
                    y: root.contentReady ? 0
                        : (attachedSurface.bottomAttached ? 8
                            : (attachedSurface.topAttached ? -8 : 0))
                    Behavior on x {
                        NumberAnimation {
                            duration: root.isOpen ? Motion.pageEnter : Motion.pageExit
                            easing.type: root.isOpen ? Motion.pageCurve : Motion.pageExitCurve
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: root.isOpen ? Motion.pageEnter : Motion.pageExit
                            easing.type: root.isOpen ? Motion.pageCurve : Motion.pageExitCurve
                        }
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.isOpen ? Motion.pageEnter : Motion.pageExit
                        easing.type: root.isOpen ? Motion.pageCurve : Motion.pageExitCurve
                    }
                }
            }
        }
    }
}
