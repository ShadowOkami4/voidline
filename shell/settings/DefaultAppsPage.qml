import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Which app opens what. Reads and writes the standard desktop defaults
// (mimeapps.list) through gio and xdg-mime, so every app honours them.
ColumnLayout {
    id: page
    spacing: 24

    // `probe` is the file type asked about; `types` are all set together.
    readonly property var kinds: [
        { id: "browser", icon: "language", lobes: 8, label: "Web browser", probe: "x-scheme-handler/https",
          types: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] },
        { id: "mail", icon: "mail", lobes: 0, label: "Email", probe: "x-scheme-handler/mailto", types: ["x-scheme-handler/mailto"] },
        { id: "files", icon: "folder", lobes: 4, label: "File manager", probe: "inode/directory", types: ["inode/directory"] },
        { id: "text", icon: "edit_note", lobes: 5, label: "Text editor", probe: "text/plain", types: ["text/plain"] },
        { id: "images", icon: "image", lobes: 8, label: "Image viewer", probe: "image/png",
          types: ["image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/svg+xml"] },
        { id: "video", icon: "movie", lobes: 0, label: "Video player", probe: "video/mp4",
          types: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"] },
        { id: "music", icon: "music_note", lobes: 4, label: "Music player", probe: "audio/mpeg",
          types: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"] },
        { id: "pdf", icon: "picture_as_pdf", lobes: 5, label: "PDF documents", probe: "application/pdf", types: ["application/pdf"] }
    ]

    // { kindId: { current: "app.desktop", apps: ["app.desktop", ...] } }
    property var found: ({})
    property string open: ""

    function entry(file) {
        const id = file.replace(/\.desktop$/, "")
        return DesktopEntries.applications.values.find(e => e.id === id) ?? null
    }
    function nameOf(file) {
        if (!file) return "Not set"
        const e = entry(file)
        return e ? e.name : file.replace(/\.desktop$/, "")
    }
    function refresh() { probe.running = true }
    function choose(kind, file) {
        if (!/^[\w.@+-]+\.desktop$/.test(file)) return
        setter.command = ["xdg-mime", "default", file].concat(kind.types)
        setter.running = true
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "for t in \"$@\"; do echo \"@@$t\"; LC_ALL=C gio mime \"$t\" 2>/dev/null; done", "sh"]
            .concat(page.kinds.map(k => k.probe))
        stdout: StdioCollector {
            onStreamFinished: {
                const byType = {}
                let cur = null
                for (const line of text.split("\n")) {
                    if (line.startsWith("@@")) { cur = byType[line.slice(2)] = { current: "", apps: [] }; continue }
                    if (!cur) continue
                    const def = line.match(/^Default application for .*: (\S+\.desktop)\s*$/)
                    if (def) cur.current = def[1]
                    else if (/^\s+\S+\.desktop\s*$/.test(line) && !cur.apps.includes(line.trim())) cur.apps.push(line.trim())
                }
                const out = {}
                for (const k of page.kinds) out[k.id] = byType[k.probe] ?? { current: "", apps: [] }
                page.found = out
            }
        }
    }
    Process { id: setter; onExited: page.refresh() }

    // Terminals come from the app list, the choice is Voidline's own setting.
    readonly property var terminals: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && (e.categories || []).includes("TerminalEmulator") && e.command.length > 0)
    function base(cmd) { return String(cmd).split("/").pop() }
    readonly property var terminalEntry: terminals.find(e => base(e.command[0]) === base(Config.terminal)) ?? null

    component AppRow: Pressable {
        id: appRow
        property string name: ""
        property string iconName: ""
        property bool current: false
        Layout.fillWidth: true
        implicitHeight: 52
        color: current ? Theme.secondaryContainer : Theme.surfaceContainerHighest
        restRadius: current ? Theme.cornerFull : Theme.cornerM
        pressedRadius: Theme.cornerS
        Behavior on color { Tint {} }
        AppIcon { id: appIcon; x: 14; anchors.verticalCenter: parent.verticalCenter; size: 28; icon: appRow.iconName; name: appRow.name }
        Label {
            anchors.left: appIcon.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: appRow.name
            font.weight: appRow.current ? Font.Bold : Font.Normal
            color: appRow.current ? Theme.inkOnSecondaryContainer : Theme.ink
        }
        MIcon {
            visible: appRow.current
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            icon: "check"
            size: 20
            color: Theme.inkOnSecondaryContainer
        }
    }

    SegGroup {
        title: "Open with"
        Repeater {
            model: page.kinds
            SegItem {
                id: item
                required property var modelData
                required property int index
                readonly property var info: page.found[modelData.id] ?? { current: "", apps: [] }
                readonly property bool expanded: page.open === modelData.id
                icon: modelData.icon
                hue: index
                lobes: modelData.lobes
                title: modelData.label
                description: info.apps.length === 0 ? "No app installed for this" : page.nameOf(info.current)
                clickable: info.apps.length > 0
                onClicked: page.open = expanded ? "" : modelData.id
                MIcon { visible: item.info.apps.length > 0; icon: item.expanded ? "expand_less" : "expand_more"; size: 24; color: Theme.inkMuted }

                extra: ColumnLayout {
                    visible: item.expanded
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: item.expanded ? item.info.apps : []
                        AppRow {
                            required property string modelData
                            readonly property var app: page.entry(modelData)
                            name: page.nameOf(modelData)
                            iconName: app ? app.icon : ""
                            current: modelData === item.info.current
                            onClicked: page.choose(item.modelData, modelData)
                        }
                    }
                }
            }
        }
    }

    SegGroup {
        title: "Voidline"
        SegItem {
            id: term
            readonly property bool expanded: page.open === "terminal"
            icon: "terminal"
            hue: 2
            lobes: 8
            title: "Terminal"
            description: (page.terminalEntry ? page.terminalEntry.name : Config.terminal) + ". Used for apps that run in a terminal."
            clickable: true
            onClicked: page.open = expanded ? "" : "terminal"
            MIcon { icon: term.expanded ? "expand_less" : "expand_more"; size: 24; color: Theme.inkMuted }

            extra: ColumnLayout {
                visible: term.expanded
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: term.expanded ? page.terminals : []
                    AppRow {
                        required property var modelData
                        name: modelData.name
                        iconName: modelData.icon
                        current: modelData === page.terminalEntry
                        onClicked: Config.terminal = page.base(modelData.command[0])
                    }
                }
                // Anything not in the list can be typed in.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: custom.activeFocus ? Theme.cornerM : height / 2
                    color: Theme.surfaceContainerHighest
                    border.width: custom.activeFocus ? 2 : 0
                    border.color: Theme.primary
                    Behavior on radius { Spring {} }
                    MIcon { id: pen; x: 16; anchors.verticalCenter: parent.verticalCenter; icon: "edit"; size: 20; color: Theme.inkMuted }
                    TextInput {
                        id: custom
                        anchors.left: pen.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: Config.terminal
                        color: Theme.ink
                        selectionColor: Theme.primaryContainer
                        font.family: Theme.font
                        font.pixelSize: Theme.textBody
                        clip: true
                        onEditingFinished: if (text.trim().length > 0) Config.terminal = text.trim()
                    }
                }
            }
        }
    }
}
