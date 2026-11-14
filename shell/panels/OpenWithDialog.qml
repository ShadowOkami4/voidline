import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// "Open with": pick the app for a file, once or from now on. Opened from a
// desktop icon, from Files (Scripts > Open with…) or with
//   qs -c voidline ipc call shell openWith /path/to/file
Scope {
    id: root

    readonly property string path: Shell.openWithPath
    readonly property string fileName: path.split("/").pop()
    // Kind of file ("image/png") and the apps the system suggests for it.
    property string kind: ""
    property string current: ""
    property var suggested: []
    property bool everything: false
    property bool always: false

    onPathChanged: {
        kind = ""; current = ""; suggested = []; everything = false; always = false
        if (path.length > 0) probe.running = true
    }

    function entry(file) {
        const id = file.replace(/\.desktop$/, "")
        return DesktopEntries.applications.values.find(e => e.id === id) ?? null
    }
    function open(app) {
        if (always && kind.length > 0 && /^[\w.@+-]+$/.test(app.id))
            Quickshell.execDetached(["xdg-mime", "default", app.id + ".desktop", kind])
        let cmd = app.command.slice()
        if (cmd.length === 0) Apps.openUrl("file://" + path)
        else {
            cmd.push(path)
            if (app.runInTerminal) cmd = [Config.terminal, "-e"].concat(cmd)
            Quickshell.execDetached(["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF"].concat(cmd))
        }
        Shell.openWithPath = ""
    }

    Process {
        id: probe
        command: ["sh", "-c", "t=$(xdg-mime query filetype \"$1\" 2>/dev/null); echo \"@@$t\"; LC_ALL=C gio mime \"$t\" 2>/dev/null", "sh", root.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const apps = []
                for (const line of text.split("\n")) {
                    if (line.startsWith("@@")) { root.kind = line.slice(2).trim(); continue }
                    const def = line.match(/^Default application for .*: (\S+\.desktop)\s*$/)
                    if (def) root.current = def[1]
                    else if (/^\s+\S+\.desktop\s*$/.test(line) && !apps.includes(line.trim())) apps.push(line.trim())
                }
                const found = apps.map(a => root.entry(a)).filter(e => e && !e.noDisplay)
                root.suggested = found
                // Nothing suggested: go straight to the full list.
                if (found.length === 0) root.everything = true
            }
        }
    }

    LazyLoader {
        active: root.path.length > 0

        PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: Shell.coverZone
            color: Theme.alpha("#000000", 0.5)
            WlrLayershell.namespace: "voidline-openwith"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property var shown: root.everything ? Apps.search(filter.text) : root.suggested

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Shell.openWithPath = "" }

            Rectangle {
                anchors.centerIn: parent
                width: 460
                height: body.implicitHeight + 48
                radius: Theme.cornerXXL
                color: Theme.surfaceContainerHigh
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                ColumnLayout {
                    id: body
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            leftPadding: 6
                            text: Lang.t("Open with")
                            font.pixelSize: 24
                            font.weight: Font.Black
                        }
                        Label {
                            Layout.fillWidth: true
                            leftPadding: 6
                            elide: Text.ElideMiddle
                            text: root.fileName
                            color: Theme.inkMuted
                        }
                    }

                    Rectangle {
                        visible: root.everything
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: filter.activeFocus ? Theme.cornerM : height / 2
                        color: Theme.surfaceContainerHighest
                        Behavior on radius { Spring {} }
                        MIcon { id: glass; x: 16; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 20; color: Theme.inkMuted }
                        TextInput {
                            id: filter
                            anchors.left: glass.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.ink
                            selectionColor: Theme.primaryContainer
                            font.family: Theme.font
                            font.pixelSize: Theme.textBody
                            clip: true
                            focus: true
                            onVisibleChanged: if (visible) forceActiveFocus()
                            Component.onCompleted: forceActiveFocus()
                            Keys.onEscapePressed: Shell.openWithPath = ""
                            Keys.onReturnPressed: if (win.shown.length > 0) root.open(win.shown[0])
                            Label {
                                visible: filter.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: Lang.t("Search apps")
                                color: Theme.inkMuted
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(330, contentHeight)
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.shown
                        delegate: Pressable {
                            id: row
                            required property var modelData
                            readonly property bool current: modelData.id + ".desktop" === root.current
                            width: ListView.view.width
                            height: 52
                            wheelEnabled: false
                            color: current ? Theme.secondaryContainer : Theme.surfaceContainerHighest
                            restRadius: current ? Theme.cornerFull : Theme.cornerM
                            pressedRadius: Theme.cornerS
                            onClicked: root.open(modelData)
                            AppIcon { id: appIcon; x: 14; anchors.verticalCenter: parent.verticalCenter; size: 28; icon: row.modelData.icon; name: row.modelData.name }
                            Label {
                                anchors.left: appIcon.right
                                anchors.leftMargin: 14
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: row.modelData.name + (row.current ? "  ·  " + Lang.t("default") : "")
                                font.weight: row.current ? Font.Bold : Font.Normal
                                color: row.current ? Theme.inkOnSecondaryContainer : Theme.ink
                            }
                        }
                    }
                    Label {
                        visible: win.shown.length === 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Lang.t("No apps found")
                        color: Theme.inkMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12
                        Toggle { checked: root.always; onToggled: v => root.always = v }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: Lang.t("Always use for this kind of file")
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Pressable {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 50
                            color: Theme.surfaceContainerHighest
                            onClicked: Shell.openWithPath = ""
                            Label { anchors.centerIn: parent; text: Lang.t("Cancel"); font.weight: Font.DemiBold }
                        }
                        Pressable {
                            visible: !root.everything
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 50
                            color: Theme.surfaceContainerHighest
                            onClicked: root.everything = true
                            Label { anchors.centerIn: parent; text: Lang.t("Other apps"); font.weight: Font.DemiBold }
                        }
                    }
                }
            }
        }
    }
}
