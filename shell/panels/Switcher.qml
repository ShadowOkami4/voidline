import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Window switcher (Super + Tab): every window on every workspace, minimised
// ones included. Tab or the arrows move, Enter or letting go of Super picks,
// Esc cancels.
PanelSurface {
    id: root

    open: Shell.panel === "switcher"
    anchor: "center"
    panelWidth: Math.min(1100, Math.max(360, list.length * 150 + 40))
    panelHeight: 210

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
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) root.step(1)
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) root.step(-1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.pick()
            else if (event.key === Qt.Key_Escape) Shell.close()
            else return
            event.accepted = true
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) root.pick()
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.list
                Pressable {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: root.index === index
                    width: 144
                    height: 170
                    color: current ? Theme.secondaryContainer : "transparent"
                    restRadius: current ? Theme.cornerXL : Theme.cornerL
                    pressedRadius: Theme.cornerM
                    Behavior on color { Tint {} }
                    onHoveredChanged: if (hovered) root.index = index
                    onClicked: { root.index = index; root.pick() }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        AppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 64
                            icon: Apps.iconNameFor(tile.modelData.appId)
                            name: tile.modelData.appId
                            opacity: tile.modelData.minimized ? 0.5 : 1
                            scale: tile.current ? 1.08 : 1
                            Behavior on scale { Spring {} }
                        }
                        Label {
                            width: tile.width - 20
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            text: tile.modelData.title || tile.modelData.appId
                            font.pixelSize: Theme.textLabel
                            font.weight: tile.current ? Font.Bold : Font.Medium
                            color: tile.current ? Theme.inkOnSecondaryContainer : Theme.ink
                        }
                    }
                }
            }
            Label {
                visible: root.list.length === 0
                text: "No windows open"
                color: Theme.inkMuted
            }
        }
    }
}
