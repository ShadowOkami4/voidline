import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../components"
import "../core"

PanelWindow {
    id: root

    property var parentBar
    property bool isOpen: parentBar && ShellState.isControlCenterScreen(parentBar.screen)
    property bool isClosing: false
    property bool contentReady: false
    property bool surfaceExpanded: false
    property string currentPage: "home"
    readonly property bool surfaceActive: isOpen || isClosing

    readonly property int cornerSize: Metrics.concaveRadius
    readonly property int maxPanelWidth: Metrics.panelWide
    readonly property int maxBodyHeight: 780
    readonly property int collapsedWidth: 142
    function normalizedPage(requested) {
        return requested === "wifi" || requested === "bluetooth" || requested === "sound"
            || requested === "power" || requested === "project" || requested === "hotspot"
            ? requested : "home"
    }
    function requestedPanelWidth(page) {
        if (page === "sound" || page === "power")
            return Metrics.panelWide
        if (page === "wifi" || page === "hotspot")
            return Metrics.panelMedium
        if (page === "bluetooth" || page === "project")
            return 480
        return Metrics.panelCompact
    }
    readonly property int targetPanelWidth: Math.min(requestedPanelWidth(currentPage),
        parentBar && parentBar.screen ? Math.max(360, parentBar.screen.width - 48) : maxPanelWidth)
    readonly property int targetBodyHeight: {
        if (currentPage === "power")
            return 720
        if (currentPage === "wifi")
            return 718
        if (currentPage === "hotspot")
            return 780
        if (currentPage === "bluetooth")
            return 690
        if (currentPage === "sound")
            return 720
        if (currentPage === "project")
            return 590
        return 780
    }
    readonly property int targetPanelHeight: targetBodyHeight + cornerSize

    screen: parentBar ? parentBar.screen : null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    focusable: isOpen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-control-center"
    // Keep one transparent layer surface resident per output. Unmapping it
    // after every close makes the first animation after changing monitors pay
    // the Wayland/QSG surface warm-up cost again.
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

    function pageVisible(page) {
        return contentReady && currentPage === page
    }

    onIsOpenChanged: {
        if (isOpen) {
            currentPage = normalizedPage(ShellState.detailPage)
            closeTimer.stop()
            concealTimer.stop()
            isClosing = false
            contentReady = false
            expandTimer.restart()
            revealTimer.restart()
        } else {
            expandTimer.stop()
            revealTimer.stop()
            surfaceExpanded = false
            isClosing = true
            concealTimer.restart()
            closeTimer.restart()
        }
    }

    Connections {
        target: ShellState

        function onDetailPageChanged() {
            if (parentBar && ShellState.detailScreenName === parentBar.screen.name && root.isOpen)
                root.currentPage = root.normalizedPage(ShellState.detailPage)
        }
    }

    Timer {
        id: expandTimer
        interval: 16
        onTriggered: root.surfaceExpanded = true
    }

    Timer {
        id: revealTimer
        interval: Motion.contentDelay
        onTriggered: root.contentReady = true
    }

    // On enter the content finishes just before the surface morph. Start its
    // reverse at the mirrored point instead of deleting it as soon as close is
    // requested.
    Timer {
        id: concealTimer
        interval: Math.max(0, Motion.morphExit - Motion.contentDelay - Motion.pageExit)
        onTriggered: root.contentReady = false
    }

    Timer {
        id: closeTimer
        interval: Motion.morphExit + 16
        onTriggered: {
            root.isClosing = false
            root.surfaceExpanded = false
        }
    }

    HyprlandFocusGrab {
        active: root.isOpen
        windows: [root]
        onCleared: ShellState.closePanels()
    }

    Item {
        id: attachedSurface
        readonly property bool topAttached: Appearance.barPosition === "top"
        readonly property bool bottomAttached: Appearance.barPosition === "bottom"
        readonly property bool leftAttached: Appearance.barPosition === "left"
        readonly property bool rightAttached: Appearance.barPosition === "right"
        x: topAttached || bottomAttached ? root.width - width
            : (Appearance.barPosition === "left"
                ? Theme.sideBarWidth - 1
                : root.width - Theme.sideBarWidth - width + 1)
        y: topAttached ? Theme.barHeight - 1
            : (bottomAttached ? root.height - Theme.barHeight - height + 1
                : root.height - height)
        width: root.surfaceExpanded
            ? root.targetPanelWidth + root.cornerSize
            : (topAttached || bottomAttached ? root.collapsedWidth : 0)
        height: root.surfaceExpanded
            ? root.targetPanelHeight
            : (topAttached || bottomAttached ? 0 : root.collapsedWidth)
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: !root.surfaceExpanded ? Motion.morphExit
                    : (root.contentReady ? Motion.panelResize : Motion.morphEnter)
                easing.type: Motion.morphCurve
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: !root.surfaceExpanded ? Motion.morphExit
                    : (root.contentReady ? Motion.panelResize : Motion.morphEnter)
                easing.type: Motion.morphCurve
            }
        }

        ConcaveJoin {
            x: 0
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "top-left"
            visible: attachedSurface.topAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "top-left"
            visible: attachedSurface.topAttached
        }

        ConcaveJoin {
            x: 0
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-left"
            visible: attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-left"
            visible: attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: 0
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "left-top"
            visible: attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-right"
            visible: attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "right-top"
            visible: attachedSurface.rightAttached
        }
        ConcaveJoin {
            x: 0
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-left"
            visible: attachedSurface.rightAttached
        }

        Rectangle {
            id: panelBody
            x: attachedSurface.leftAttached ? 0 : root.cornerSize
            y: attachedSurface.topAttached ? 0 : root.cornerSize
            width: Math.max(1, attachedSurface.width - root.cornerSize)
            height: Math.max(1, attachedSurface.height - root.cornerSize)
            radius: Theme.panelRadius
            color: Theme.panel
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.topAttached
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Theme.panelRadius
                color: Theme.panel
                visible: !attachedSurface.topAttached
            }
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.leftAttached
            }
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: Theme.panelRadius
                color: Theme.panel
                visible: !attachedSurface.leftAttached
            }

            Item {
                id: contentViewport
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: Theme.panelPadding
                    rightMargin: Theme.panelPadding
                }
                // Keep pages at their settled size while the surrounding
                // surface morphs. The panel clips this item as it grows and
                // shrinks, avoiding a full layout reflow on every frame.
                width: Math.max(1, root.targetPanelWidth - Theme.panelPadding * 2)
                height: Math.max(1, root.targetBodyHeight - Theme.panelPadding * 2)

                Loader {
                    id: controlPageLoader
                    anchors.fill: parent
                    active: root.surfaceActive
                    asynchronous: true
                    visible: opacity > 0
                    opacity: root.contentReady ? 1 : 0
                    sourceComponent: root.currentPage === "wifi" ? wifiComponent
                        : (root.currentPage === "hotspot" ? hotspotComponent
                            : (root.currentPage === "bluetooth" ? bluetoothComponent
                                : (root.currentPage === "sound" ? soundComponent
                                    : (root.currentPage === "project" ? projectComponent
                                        : (root.currentPage === "power" ? resourceComponent
                                            : homeComponent)))))

                    onLoaded: {
                        if (!item)
                            return
                        if ("active" in item)
                            item.active = Qt.binding(() => root.contentReady)
                        if ("screenName" in item)
                            item.screenName = Qt.binding(() => parentBar && parentBar.screen
                                ? parentBar.screen.name : "")
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.isOpen ? Motion.pageEnter : Motion.pageExit
                            easing.type: root.isOpen ? Motion.pageCurve : Motion.pageExitCurve
                        }
                    }
                }

                Connections {
                    target: controlPageLoader.item
                    ignoreUnknownSignals: true
                    function onOpenPage(page) { ShellState.detailPage = page }
                    function onBack() { ShellState.detailPage = "" }
                }

                Component { id: homeComponent; HomePage {} }
                Component { id: wifiComponent; WifiPage {} }
                Component { id: hotspotComponent; HotspotPage {} }
                Component { id: bluetoothComponent; BluetoothPage {} }
                Component { id: soundComponent; SoundPage {} }
                Component { id: projectComponent; ProjectPage {} }
                Component { id: resourceComponent; ResourcePage {} }
            }
        }
    }
}
