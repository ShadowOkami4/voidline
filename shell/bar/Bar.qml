import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.widgets

// One bar window per screen. The arrangement inside depends on the style.
PanelWindow {
    id: bar

    readonly property bool bottom: Style.barEdge === "bottom"
    readonly property int joins: Style.framed ? Style.frameRadius : 0

    anchors {
        top: !bottom
        bottom: bottom
        left: true
        right: true
    }
    implicitHeight: Style.barHeight + joins
    exclusiveZone: Style.barHeight
    color: "transparent"
    WlrLayershell.namespace: "voidline-bar"
    WlrLayershell.layer: WlrLayer.Top
    // Only the bar itself takes input; the join area below is click-through.
    mask: Region { item: surface }

    Rectangle {
        id: surface
        y: bar.bottom ? bar.joins : 0
        width: parent.width
        height: Style.barHeight
        color: Style.barColor

        Loader {
            anchors.fill: parent
            sourceComponent: Style.windows ? windowsLayout : (Style.macos ? macLayout : voidlineLayout)
        }
    }

    // Voidline: the bar curves into the screen frame at both ends.
    ConcaveJoin {
        visible: Style.framed
        x: Style.frameWidth
        y: Style.barHeight
        corner: "tl"
        fill: Style.barColor
    }
    ConcaveJoin {
        visible: Style.framed
        x: parent.width - width - Style.frameWidth
        y: Style.barHeight
        corner: "tr"
        fill: Style.barColor
    }

    // ---- Voidline: clock | launcher + workspaces | tray + status ----------
    Component {
        id: voidlineLayout
        Item {
            Clock {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                layout: "split"
            }
            Row {
                anchors.centerIn: parent
                spacing: 8
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "apps"
                    size: 30
                    selected: Shell.panel === "launcher"
                    onClicked: Shell.toggle("launcher", bar.screen)
                }
                Workspaces { anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Tray { window: bar; anchors.verticalCenter: parent.verticalCenter }
                Status { screen: bar.screen; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ---- Windows: centred start + tasks | tray, status, clock -------------
    Component {
        id: windowsLayout
        Item {
            Row {
                anchors.centerIn: parent
                spacing: 4
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "grid_view"
                    size: 44
                    iconSize: 26
                    restRadius: Theme.cornerM
                    selected: Shell.panel === "launcher"
                    onClicked: Shell.toggle("launcher", bar.screen)
                }
                TaskList { anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Tray { window: bar; anchors.verticalCenter: parent.verticalCenter }
                Status { screen: bar.screen; contained: false; anchors.verticalCenter: parent.verticalCenter }
                Clock { layout: "stacked"; anchors.verticalCenter: parent.verticalCenter }
            }
            Workspaces {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- macOS: logo, focused app | workspaces | tray, status, clock ------
    Component {
        id: macLayout
        Item {
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "blur_on"
                    size: 26
                    selected: Shell.panel === "launcher"
                    onClicked: Shell.toggle("launcher", bar.screen)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 420)
                    text: Compositor.focusedWindow ? (Compositor.focusedWindow.title || Compositor.focusedWindow.appId) : "Desktop"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }
            Workspaces {
                anchors.centerIn: parent
                implicitHeight: 22
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Tray { window: bar; anchors.verticalCenter: parent.verticalCenter }
                Status { screen: bar.screen; contained: false; implicitHeight: 26; anchors.verticalCenter: parent.verticalCenter }
                Clock { layout: "inline"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
