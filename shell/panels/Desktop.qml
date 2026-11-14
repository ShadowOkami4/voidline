import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// The desktop itself, drawn on top of the wallpaper: the files of your
// Desktop folder as icons and a right-click menu.
//
// Icons sit on an invisible grid. Drag one to another place and it stays
// there: the grid cell of every moved icon is remembered in
// ~/.local/state/voidline/desktop.json. Dropping on an occupied cell swaps
// the two. Icons that were never moved fill the free cells from the top left.
Item {
    id: root
    anchors.fill: parent

    property string folder: ""
    readonly property string icons: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/icons/Voidline/scalable/"
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/voidline/desktop.json"

    Process {
        running: true
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\"; xdg-user-dir DESKTOP 2>/dev/null || echo \"$HOME/Desktop\"", "sh", root.statePath]
        stdout: StdioCollector { onStreamFinished: root.folder = text.trim() }
    }

    // Picks one of Voidline's own icons from the kind of file.
    function iconFor(name, isDir) {
        if (isDir) return icons + "places/folder.svg"
        const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : ""
        const kind = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"].includes(ext) ? "image-x-generic"
            : ["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(ext) ? "audio-x-generic"
            : ["mp4", "mkv", "webm", "mov", "avi"].includes(ext) ? "video-x-generic"
            : ["zip", "tar", "gz", "xz", "7z", "rar", "zst"].includes(ext) ? "package-x-generic"
            : ext === "pdf" ? "application-pdf"
            : ["sh", "py", "js", "ts", "c", "cpp", "rs", "go", "html", "css", "json", "lua", "qml", "desktop"].includes(ext) ? "text-x-script"
            : "text-x-generic"
        return icons + "mimetypes/" + kind + ".svg"
    }

    // ---- what is on the desktop ----------------------------------------------------------
    FolderListModel {
        id: files
        folder: root.folder.length > 0 && Config.desktopIcons ? "file://" + root.folder : ""
        showDirsFirst: true
        showHidden: false
        sortField: FolderListModel.Name
        onCountChanged: root.reread()
        onStatusChanged: root.reread()
    }
    // [{ name, path, dir }], rebuilt when the folder changes.
    property var items: []
    function reread() {
        const out = []
        for (let i = 0; i < files.count; ++i)
            out.push({ name: files.get(i, "fileName"), path: files.get(i, "filePath"), dir: files.get(i, "fileIsDir") })
        items = out
    }

    // ---- the grid and the remembered places ------------------------------------------------
    readonly property int cellW: 112
    readonly property int cellH: 116
    readonly property real areaX: 28
    readonly property real areaY: Style.barEdge === "top" ? Style.barHeight + 24 : 24
    readonly property int cols: Math.max(1, Math.floor((width - 56) / cellW))
    readonly property int rows: Math.max(1, Math.floor((height - Style.barHeight - 48 - (Style.dock ? Style.dockHeight : 0)) / cellH))

    // Saved as "col,row,file name".
    FileView {
        path: root.statePath
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: store
            property list<string> places: []
        }
    }
    readonly property var saved: {
        const out = {}
        for (const e of store.places) {
            const m = e.match(/^(\d+),(\d+),(.+)$/)
            if (m) out[m[3]] = { c: parseInt(m[1]), r: parseInt(m[2]) }
        }
        return out
    }
    // { name: { c, r } } for every icon: saved places first, the rest fill the
    // free cells column by column.
    readonly property var layout: {
        const out = {}, taken = {}
        const key = (c, r) => c + "," + r
        for (const it of items) {
            const s = saved[it.name]
            if (s && s.c < cols && s.r < rows && !taken[key(s.c, s.r)]) { out[it.name] = s; taken[key(s.c, s.r)] = true }
        }
        let c = 0, r = 0
        for (const it of items) {
            if (out[it.name]) continue
            while (taken[key(c, r)] && c < cols * 4) { r += 1; if (r >= rows) { r = 0; c += 1 } }
            out[it.name] = { c: c, r: r }
            taken[key(c, r)] = true
        }
        return out
    }

    // Moves `name` to a cell; whatever sits there takes the old place.
    function moveTo(name, c, r) {
        c = Math.max(0, Math.min(cols - 1, c))
        r = Math.max(0, Math.min(rows - 1, r))
        const from = layout[name]
        if (!from || (from.c === c && from.r === r)) return
        const next = {}
        for (const it of items) if (saved[it.name]) next[it.name] = saved[it.name]      // drops files that are gone
        const other = items.find(it => it.name !== name && layout[it.name].c === c && layout[it.name].r === r)
        if (other) next[other.name] = { c: from.c, r: from.r }
        next[name] = { c: c, r: r }
        store.places = Object.keys(next).map(n => next[n].c + "," + next[n].r + "," + n)
    }
    function tidy() { store.places = [] }

    property string selected: ""

    // Click on empty desktop: close the menu. Right click: open it there.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            root.selected = ""
            if (mouse.button === Qt.RightButton) {
                menu.x = Math.min(mouse.x, root.width - menu.width - 12)
                menu.y = Math.min(mouse.y, root.height - menu.height - 12)
                menu.visible = true
            } else menu.visible = false
        }
    }

    // Shows where a dragged icon will land.
    Rectangle {
        id: target
        visible: false
        width: root.cellW - 8
        height: root.cellH - 8
        radius: Theme.cornerL
        color: Theme.alpha(Theme.primary, 0.18)
        border.width: 2
        border.color: Theme.alpha(Theme.primary, 0.7)
    }

    Repeater {
        model: Config.desktopIcons ? root.items : []

        Item {
            id: cell
            required property var modelData
            readonly property var place: root.layout[modelData.name] ?? ({ c: 0, r: 0 })
            readonly property bool current: root.selected === modelData.name
            readonly property real homeX: root.areaX + place.c * root.cellW
            readonly property real homeY: root.areaY + place.r * root.cellH

            width: root.cellW
            height: root.cellH
            x: homeX
            y: homeY
            z: touch.drag.active ? 50 : 1
            scale: touch.drag.active ? 1.08 : 1
            opacity: touch.drag.active ? 0.9 : 1
            Behavior on scale { Spring {} }
            // Glide back (or to the new cell) when let go; follow the mouse while held.
            Behavior on x { enabled: !touch.drag.active; Spring {} }
            Behavior on y { enabled: !touch.drag.active; Spring {} }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.cornerL
                color: cell.current ? Theme.alpha(Theme.primary, 0.32) : (touch.containsMouse ? Theme.alpha(Theme.ink, 0.10) : "transparent")
                Behavior on color { Tint {} }
            }
            Image {
                id: picture
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                width: 56
                height: 56
                sourceSize.width: 112
                sourceSize.height: 112
                source: "file://" + root.iconFor(cell.modelData.name, cell.modelData.dir)
                asynchronous: true
            }
            Label {
                anchors.top: picture.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: cell.modelData.name.replace(/\.desktop$/, "")
                font.pixelSize: Theme.textLabel
                font.weight: Font.DemiBold
                color: "#FFFFFF"
                style: Text.Raised
                styleColor: "#80000000"
            }

            MouseArea {
                id: touch
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                drag.target: cell
                drag.threshold: 8
                drag.minimumX: 0
                drag.maximumX: root.width - cell.width
                drag.minimumY: 0
                drag.maximumY: root.height - cell.height
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                function cellAt() {
                    return {
                        c: Math.max(0, Math.min(root.cols - 1, Math.round((cell.x - root.areaX) / root.cellW))),
                        r: Math.max(0, Math.min(root.rows - 1, Math.round((cell.y - root.areaY) / root.cellH)))
                    }
                }
                onPressed: { root.selected = cell.modelData.name; menu.visible = false }
                onPositionChanged: {
                    if (!drag.active) return
                    const at = cellAt()
                    target.x = root.areaX + at.c * root.cellW + 4
                    target.y = root.areaY + at.r * root.cellH + 4
                    target.visible = true
                }
                onReleased: {
                    target.visible = false
                    if (!drag.active && Math.abs(cell.x - cell.homeX) + Math.abs(cell.y - cell.homeY) < 2) return
                    const at = cellAt()
                    root.moveTo(cell.modelData.name, at.c, at.r)
                    // Back under the control of the grid (also when nothing changed).
                    cell.x = Qt.binding(() => cell.homeX)
                    cell.y = Qt.binding(() => cell.homeY)
                }
                onDoubleClicked: Apps.openUrl("file://" + cell.modelData.path)
            }
        }
    }

    // ---- right-click menu ----------------------------------------------------------------
    Rectangle {
        id: menu
        visible: false
        z: 100
        width: 270
        height: list.implicitHeight + 16
        radius: Theme.cornerXL
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.6)
        scale: visible ? 1 : 0.9
        transformOrigin: Item.TopLeft
        Behavior on scale { Spring {} }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: list
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 2

            Repeater {
                model: [
                    { icon: "wallpaper", label: Lang.t("Change wallpaper"), run: () => Shell.openSettings("colours") },
                    { icon: "monitor", label: Lang.t("Display settings"), run: () => Shell.openSettings("display") },
                    { icon: "settings", label: Lang.t("Settings"), run: () => Shell.openSettings() },
                    { line: true },
                    { icon: "create_new_folder", label: Lang.t("New folder"), run: () => Quickshell.execDetached(["sh", "-c", "n='New folder'; i=1; while [ -e \"$1/$n\" ]; do i=$((i+1)); n=\"New folder $i\"; done; mkdir -p \"$1/$n\"", "sh", root.folder]) },
                    { icon: "folder_open", label: Lang.t("Open the Desktop folder"), run: () => Apps.openUrl("file://" + root.folder) },
                    { icon: "terminal", label: Lang.t("Open terminal"), run: () => Quickshell.execDetached({ command: ["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", Config.terminal], workingDirectory: root.folder }) },
                    { line: true },
                    { icon: "grid_view", label: Lang.t("Tidy up icons"), run: () => root.tidy() },
                    { icon: Config.desktopIcons ? "visibility_off" : "visibility", label: Config.desktopIcons ? Lang.t("Hide desktop icons") : Lang.t("Show desktop icons"), run: () => Config.desktopIcons = !Config.desktopIcons },
                    { icon: "lock", label: Lang.t("Lock"), run: () => Shell.lock() }
                ]
                Item {
                    id: entry
                    required property var modelData
                    width: list.width
                    height: modelData.line ? 9 : 42
                    Rectangle {
                        visible: !!entry.modelData.line
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: 1
                        color: Theme.outlineVariant
                    }
                    Pressable {
                        visible: !entry.modelData.line
                        anchors.fill: parent
                        restRadius: Theme.cornerM
                        pressedRadius: Theme.cornerS
                        onClicked: { menu.visible = false; entry.modelData.run() }
                        MIcon { id: glyph; x: 14; anchors.verticalCenter: parent.verticalCenter; icon: entry.modelData.icon ?? ""; size: 20; color: Theme.inkMuted }
                        Label { anchors.left: glyph.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: entry.modelData.label ?? "" }
                    }
                }
            }
        }
    }
}
