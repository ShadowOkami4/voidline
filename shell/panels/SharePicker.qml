import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// "What do you want to share?" Shown when an app asks for the screen (a
// call, a recorder). Pick a whole screen, one window or a part of the
// screen; share-picker.sh passes the choice on to the portal.
Scope {
    id: root

    readonly property var request: Shell.shareRequest
    property bool again: false
    // Hidden while a part of the screen is being drawn.
    property bool drawing: false
    onRequestChanged: { again = false; drawing = false }

    // The script waiting for the answer is gone (the portal restarted, the
    // app gave up): close the dialog instead of leaving it on screen.
    readonly property string waiter: request ? (String(request.answer).match(/-(\d+)$/) || ["", ""])[1] : ""
    Timer {
        interval: 1000
        running: root.waiter.length > 0 && !alive.running
        repeat: true
        onTriggered: alive.running = true
    }
    Process {
        id: alive
        command: ["test", "-d", "/proc/" + root.waiter]
        onExited: code => {
            if (code === 0 || !root.request) return
            if (area.running) area.signal(15)
            root.drawing = false
            Shell.shareRequest = null
        }
    }

    function choose(what) { Shell.shareAnswer(what.length > 0 ? "[SELECTION]" + (again ? "r" : "") + "/" + what : "") }

    Process {
        id: area
        // slurp reads ready-made boxes from its input when that is not a
        // terminal, and would wait there for ever; give it nothing to read.
        // slurp gives desktop coordinates; the portal wants them from the
        // screen's own top-left corner, so its position is taken off.
        command: ["sh", "-c", `
r=$(slurp -f '%o %x %y %w %h' < /dev/null) || exit 1
set -- $r
at=$(hyprctl monitors | awk -v o="$1" '$1 == "Monitor" { on = ($2 == o) } on && / at -?[0-9]+x-?[0-9]+/ { sub(/.* at /, ""); print; exit }')
ox=\${at%x*}; oy=\${at#*x}
echo "$1@$(( $2 - \${ox:-0} )),$(( $3 - \${oy:-0} )),$4,$5"`]
        stdout: StdioCollector { id: drawn }
        onExited: code => {
            root.drawing = false
            const spot = drawn.text.trim()
            if (code === 0 && /^[\w.-]+@\d+,\d+,\d+,\d+$/.test(spot)) root.choose("region:" + spot)
        }
    }

    LazyLoader {
        active: !!root.request && !root.drawing

        PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: Shell.coverZone
            color: Theme.alpha("#000000", 0.5)
            WlrLayershell.namespace: "voidline-share"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property var windows: root.request ? root.request.windows : []
            // Arrives one after the other, like the panels.
            property real enter: 0
            NumberAnimation on enter { from: 0; to: 1; duration: Math.max(1, 700 * Motion.scale) }
            function at(step) {
                const t = Math.max(0, Math.min(1, (enter - step * 0.09) / 0.45))
                return 1 - Math.pow(1 - t, 3)
            }

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: root.choose("") }

            Rectangle {
                anchors.centerIn: parent
                width: 620
                height: body.implicitHeight + 48
                radius: Theme.cornerXXL
                color: Theme.surfaceContainerHigh
                scale: 0.94 + 0.06 * win.at(0)
                opacity: win.at(0)
                focus: true
                Keys.onEscapePressed: root.choose("")
                Component.onCompleted: forceActiveFocus()
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                ColumnLayout {
                    id: body
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            leftPadding: 6
                            text: Lang.t("Share your screen")
                            font.pixelSize: 24
                            font.weight: Font.Black
                        }
                        Label {
                            Layout.fillWidth: true
                            leftPadding: 6
                            wrapMode: Text.Wrap
                            text: Lang.t("An app wants to see your screen. Choose what it gets.")
                            color: Theme.inkMuted
                        }
                    }

                    // ---- whole screens ---------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        opacity: win.at(1)
                        Repeater {
                            model: Quickshell.screens
                            Pressable {
                                id: card
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 170
                                color: Theme.surfaceContainerHighest
                                restRadius: Theme.cornerXL
                                pressedRadius: Theme.cornerL
                                onClicked: root.choose("screen:" + modelData.name)

                                Item {
                                    id: frame
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    anchors.bottomMargin: 44
                                    ScreencopyView {
                                        id: view
                                        anchors.centerIn: parent
                                        captureSource: card.modelData
                                        live: false
                                        constraintSize: Qt.size(frame.width, frame.height)
                                    }
                                    MIcon { anchors.centerIn: parent; visible: !view.hasContent; icon: "desktop_windows"; size: 44; color: Theme.inkMuted }
                                }
                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 8
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: /^(eDP|LVDS|DSI)/.test(card.modelData.name) ? Lang.t("Laptop screen") : card.modelData.name
                                        font.weight: Font.Bold
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Lang.t("The whole screen")
                                        font.pixelSize: Theme.textLabelS
                                        color: Theme.inkMuted
                                    }
                                }
                            }
                        }
                    }

                    // ---- one window ----------------------------------------------------------
                    Label {
                        visible: win.windows.length > 0
                        leftPadding: 6
                        text: Lang.t("Only one window")
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.Bold
                        color: Theme.inkMuted
                        opacity: win.at(2)
                    }
                    ListView {
                        Layout.fillWidth: true
                        visible: count > 0
                        implicitHeight: Math.min(contentHeight, 4 * 52 - 4)
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.windows
                        opacity: win.at(2.6)
                        delegate: Pressable {
                            id: row
                            required property var modelData
                            width: ListView.view.width
                            height: 48
                            color: Theme.surfaceContainerHighest
                            restRadius: Theme.cornerL
                            onClicked: root.choose("window:" + modelData.id)
                            AppIcon {
                                id: face
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                size: 28
                                icon: Apps.iconNameFor(row.modelData.app)
                                name: row.modelData.app
                            }
                            Label {
                                anchors.left: face.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: row.modelData.title || row.modelData.app
                            }
                        }
                    }

                    // ---- a part, and remembering ---------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8
                        opacity: win.at(3.4)
                        Pressable {
                            visible: Capture.canShoot
                            implicitWidth: part.implicitWidth + 36
                            implicitHeight: 46
                            color: Theme.surfaceContainerHighest
                            restRadius: Theme.cornerFull
                            onClicked: { root.drawing = true; area.running = true }
                            Row {
                                id: part
                                anchors.centerIn: parent
                                spacing: 8
                                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "screenshot_region"; size: 20; color: Theme.ink }
                                Label { anchors.verticalCenter: parent.verticalCenter; text: Lang.t("A part of the screen"); font.weight: Font.DemiBold }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Pressable {
                            implicitWidth: stop.implicitWidth + 36
                            implicitHeight: 46
                            color: Theme.surfaceContainerHighest
                            restRadius: Theme.cornerFull
                            onClicked: root.choose("")
                            Label { id: stop; anchors.centerIn: parent; text: Lang.t("Don't share"); font.weight: Font.DemiBold }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        opacity: win.at(4)
                        Label {
                            Layout.fillWidth: true
                            leftPadding: 6
                            wrapMode: Text.Wrap
                            text: Lang.t("Let this app share the same thing again without asking")
                            font.pixelSize: Theme.textLabel
                            color: Theme.inkMuted
                        }
                        Toggle { checked: root.again; onToggled: v => root.again = v }
                    }
                }
            }
        }
    }
}
