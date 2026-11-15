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
    panelWidth: Math.max(360, perRow * (tileW + 8) + 32, strip.implicitWidth + 40)
    panelHeight: rows * (tileH + 8) + 32 + stripH

    // ---- workspaces: name them, and drag windows onto them --------------------------
    readonly property int stripH: 58
    readonly property var spaces: Compositor.workspaces
    // Workspace being renamed (its index), or 0.
    property int naming: 0
    // Window tile being dragged, and where the pointer is (in this panel).
    property var dragging: null
    property point dragAt: Qt.point(0, 0)
    property int dropOn: -1

    function chipUnder(p) {
        for (let i = 0; i < chips.count; ++i) {
            const c = chips.itemAt(i)
            if (!c) continue
            const q = c.mapFromItem(keys, p.x, p.y)
            if (q.x >= 0 && q.y >= 0 && q.x <= c.width && q.y <= c.height) return i
        }
        return -1
    }
    function send(win, ws) {
        if (!win || !ws || win.workspace === ws.id) return
        Compositor.moveToWorkspace(win.id, ws)
        list = list.map(w => w.id === win.id ? Object.assign({}, w, { workspace: ws.id, minimized: false }) : w)
    }

    // Frozen while open so the order does not jump around.
    property var list: []
    property int index: 0
    onOpenChanged: {
        if (!open) return
        const wins = Compositor.windows
        list = wins.filter(w => w.focused).concat(wins.filter(w => !w.focused && !w.minimized), wins.filter(w => w.minimized))
        index = list.length > 1 ? 1 : 0
        naming = 0
        dragging = null
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
            // A number sends the highlighted window to that workspace.
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && root.spaces[event.key - Qt.Key_1])
                root.send(root.list[root.index], root.spaces[event.key - Qt.Key_1])
            else return
            event.accepted = true
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) root.pick()
        }

        Row {
            id: strip
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 6

            Repeater {
                id: chips
                model: root.spaces
                Pressable {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property string given: Config.workspaceName(modelData.index)
                    readonly property bool editing: root.naming === modelData.index
                    readonly property int held: root.list.filter(w => w.workspace === modelData.id && !w.minimized).length
                    readonly property bool target: root.dragging && root.dropOn === index
                    width: editing ? 170 : Math.max(52, face.implicitWidth + 26)
                    height: 38
                    color: target ? Theme.primary : (modelData.active ? Theme.secondaryContainer : Theme.surfaceContainerHighest)
                    restRadius: target || modelData.active ? Theme.cornerM : Theme.cornerFull
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    Behavior on color { Tint {} }
                    Behavior on width { Spring {} }
                    // Click: go there. Right click: give it a name.
                    onClicked: mouse => {
                        if (editing) return
                        if (mouse.button === Qt.RightButton) { root.naming = modelData.index; nameField.text = given; nameField.forceActiveFocus(); nameField.selectAll() }
                        else { Shell.close(); Compositor.focusWorkspace(modelData) }
                    }

                    Label {
                        id: face
                        visible: !chip.editing
                        anchors.centerIn: parent
                        text: modelData.index + (chip.given.length > 0 ? "  " + chip.given : "") + (chip.held > 0 ? "  ·  " + chip.held : "")
                        font.pixelSize: Theme.textLabel + 1
                        font.weight: modelData.active ? Font.Bold : Font.Medium
                        color: chip.target ? Theme.inkOnPrimary : (modelData.active ? Theme.inkOnSecondaryContainer : Theme.ink)
                    }
                    TextInput {
                        id: nameField
                        visible: chip.editing
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        maximumLength: 24
                        color: Theme.ink
                        selectionColor: Theme.primaryContainer
                        font.family: Theme.font
                        font.pixelSize: Theme.textLabel + 1
                        clip: true
                        function done(save) {
                            if (save) Config.setWorkspaceName(chip.modelData.index, text)
                            root.naming = 0
                            keys.forceActiveFocus()
                        }
                        Keys.onReturnPressed: done(true)
                        Keys.onEnterPressed: done(true)
                        Keys.onEscapePressed: done(false)
                        Label {
                            visible: nameField.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lang.t("Name")
                            color: Theme.inkMuted
                        }
                    }
                }
            }
        }

        // What is being dragged, under the pointer.
        Rectangle {
            visible: !!root.dragging
            z: 10
            x: root.dragAt.x - width / 2
            y: root.dragAt.y - height / 2
            width: 56
            height: 56
            radius: Theme.cornerL
            color: Theme.primaryContainer
            AppIcon {
                anchors.centerIn: parent
                size: 34
                icon: root.dragging ? Apps.iconNameFor(root.dragging.appId) : ""
                name: root.dragging ? root.dragging.appId : ""
            }
        }

        Grid {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.stripH / 2
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
                    opacity: root.dragging === modelData ? 0.4 : 1

                    // Drag the window onto a workspace at the top to move it there.
                    DragHandler {
                        target: null
                        onActiveChanged: {
                            if (active) root.dragging = tile.modelData
                            else {
                                if (root.dropOn >= 0) root.send(root.dragging, root.spaces[root.dropOn])
                                root.dragging = null
                                root.dropOn = -1
                            }
                        }
                        onCentroidChanged: {
                            if (!active) return
                            root.dragAt = keys.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y)
                            root.dropOn = root.chipUnder(root.dragAt)
                        }
                    }

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
                            text: (tile.modelData.workspace > 0 && !tile.modelData.minimized ? tile.modelData.workspace + "  ·  " : "") + (tile.modelData.title || tile.modelData.appId)
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
            text: Lang.t("No windows open")
            color: Theme.inkMuted
        }
    }
}
