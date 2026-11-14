import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Window overview (Super + Tab): every window on every workspace with a live
// picture of it, minimised ones included. Tab or the arrows move, Enter or
// letting go of Super picks, Esc cancels.
PanelSurface {
    id: root

    open: Shell.panel === "switcher"
    anchor: "center"

    readonly property int tileW: 260
    readonly property int tileH: 214
    readonly property int perRow: Math.max(1, Math.min(list.length, Math.floor((parent.width - 120) / (tileW + 8))))
    readonly property int rows: Math.max(1, Math.ceil(list.length / perRow))
    panelWidth: Math.max(360, perRow * (tileW + 8) + 32)
    panelHeight: rows * (tileH + 8) + 32

    // Frozen while open so the order does not jump around.
    property var list: []
    property int index: 0
    onOpenChanged: {
        if (!open) return
        const wins = Compositor.windows
        list = wins.filter(w => w.focused).concat(wins.filter(w => !w.focused && !w.minimized), wins.filter(w => w.minimized))
        index = list.length > 1 ? 1 : 0
        keys.forceActiveFocus()
    }
    // Pressing the shortcut again while open moves on.
    Connections {
        target: Shell
        function onSwitcherStep() { if (root.open) root.step(1) }
    }

    function step(by) { if (list.length > 0) index = (index + by + list.length) % list.length }
    function pick() {
        const win = list[index]
        Shell.close()
        if (!win) return
        if (win.minimized) Compositor.restore(win.id)
        else Compositor.focusWindow(win.id)
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) root.step(1)
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) root.step(-1)
            else if (event.key === Qt.Key_Down) root.step(root.perRow)
            else if (event.key === Qt.Key_Up) root.step(-root.perRow)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.pick()
            else if (event.key === Qt.Key_Escape) Shell.close()
            else return
            event.accepted = true
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) root.pick()
        }

        Grid {
            anchors.centerIn: parent
            columns: root.perRow
            spacing: 8

            Repeater {
                model: root.list
                Pressable {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: root.index === index
                    width: root.tileW
                    height: root.tileH
                    color: current ? Theme.secondaryContainer : "transparent"
                    restRadius: current ? Theme.cornerXL : Theme.cornerL
                    pressedRadius: Theme.cornerM
                    Behavior on color { Tint {} }
                    onHoveredChanged: if (hovered) root.index = index
                    onClicked: { root.index = index; root.pick() }

                    // Live picture of the window (or its icon when the window
                    // manager cannot provide one, e.g. for minimised windows).
                    ClippingRectangle {
                        id: frame
                        x: 10
                        y: 10
                        width: parent.width - 20
                        height: 148
                        radius: Theme.cornerL
                        color: Theme.surfaceContainerHighest
                        opacity: tile.modelData.minimized ? 0.6 : 1

                        ScreencopyView {
                            id: view
                            anchors.centerIn: parent
                            captureSource: root.open ? (tile.modelData.handle ?? null) : null
                            live: true
                            constraintSize: Qt.size(frame.width, frame.height)
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            visible: !view.hasContent
                            size: 64
                            icon: Apps.iconNameFor(tile.modelData.appId)
                            name: tile.modelData.appId
                        }
                    }
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        spacing: 8
                        AppIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 24
                            icon: Apps.iconNameFor(tile.modelData.appId)
                            name: tile.modelData.appId
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 32
                            elide: Text.ElideRight
                            text: tile.modelData.title || tile.modelData.appId
                            font.pixelSize: Theme.textLabel + 1
                            font.weight: tile.current ? Font.Bold : Font.Medium
                            color: tile.current ? Theme.inkOnSecondaryContainer : Theme.ink
                        }
                    }
                }
            }
        }
        Label {
            anchors.centerIn: parent
            visible: root.list.length === 0
            text: "No windows open"
            color: Theme.inkMuted
        }
    }
}
