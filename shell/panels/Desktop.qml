import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// The desktop itself, drawn on top of the wallpaper: the files of your
// Desktop folder as icons (double-click opens them) and a right-click menu.
Item {
    id: root
    anchors.fill: parent

    property string folder: ""
    readonly property string icons: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/icons/Voidline/scalable/"

    Process {
        running: true
        command: ["sh", "-c", "xdg-user-dir DESKTOP 2>/dev/null || echo \"$HOME/Desktop\""]
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

    FolderListModel {
        id: files
        folder: root.folder.length > 0 && Config.desktopIcons ? "file://" + root.folder : ""
        showDirsFirst: true
        showHidden: false
        sortField: FolderListModel.Name
    }

    // Click on empty desktop: close the menu. Right click: open it there.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            grid.currentIndex = -1
            if (mouse.button === Qt.RightButton) {
                menu.x = Math.min(mouse.x, root.width - menu.width - 12)
                menu.y = Math.min(mouse.y, root.height - menu.height - 12)
                menu.visible = true
            } else menu.visible = false
        }
    }

    GridView {
        id: grid
        // Stay clear of the bar and the frame.
        x: 28
        y: Style.barEdge === "top" ? Style.barHeight + 24 : 24
        width: parent.width - 56
        height: parent.height - Style.barHeight - 48 - (Style.dock ? Style.dockHeight : 0)
        visible: Config.desktopIcons && files.count > 0
        interactive: false
        flow: GridView.FlowTopToBottom
        cellWidth: 112
        cellHeight: 116
        currentIndex: -1
        model: files

        delegate: Item {
            id: cell
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property int index
            readonly property bool current: grid.currentIndex === index
            width: grid.cellWidth
            height: grid.cellHeight

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
                source: "file://" + root.iconFor(cell.fileName, cell.fileIsDir)
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
                text: cell.fileName.replace(/\.desktop$/, "")
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
                onClicked: { grid.currentIndex = cell.index; menu.visible = false }
                onDoubleClicked: Apps.openUrl("file://" + cell.filePath)
            }
        }
    }

    // ---- right-click menu ----------------------------------------------------------------
    Rectangle {
        id: menu
        visible: false
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
                    { icon: "wallpaper", label: "Change wallpaper", run: () => Shell.openSettings("colours") },
                    { icon: "monitor", label: "Display settings", run: () => Shell.openSettings("display") },
                    { icon: "settings", label: "Settings", run: () => Shell.openSettings() },
                    { line: true },
                    { icon: "create_new_folder", label: "New folder", run: () => Quickshell.execDetached(["sh", "-c", "n='New folder'; i=1; while [ -e \"$1/$n\" ]; do i=$((i+1)); n=\"New folder $i\"; done; mkdir -p \"$1/$n\"", "sh", root.folder]) },
                    { icon: "folder_open", label: "Open the Desktop folder", run: () => Apps.openUrl("file://" + root.folder) },
                    { icon: "terminal", label: "Open terminal", run: () => Quickshell.execDetached({ command: ["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", Config.terminal], workingDirectory: root.folder }) },
                    { line: true },
                    { icon: Config.desktopIcons ? "visibility_off" : "visibility", label: Config.desktopIcons ? "Hide desktop icons" : "Show desktop icons", run: () => Config.desktopIcons = !Config.desktopIcons },
                    { icon: "lock", label: "Lock", run: () => Shell.lock() }
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
