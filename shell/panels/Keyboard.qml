import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.services
import qs.widgets

// On-screen keyboard for touch screens and for when a real keyboard is out
// of reach. It sits at the bottom edge, never takes the keyboard focus, and
// windows make room for it. Keys are typed through Access (wtype).
Scope {
    id: root

    // Letters follow the shell's language; everything else is the same.
    readonly property var letters: Lang.code === "de" ? [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß"],
        ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
        ["y", "x", "c", "v", "b", "n", "m", ",", ".", "-"]
    ] : [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
        ["z", "x", "c", "v", "b", "n", "m", ",", ".", "-"]
    ]
    readonly property var symbols: [
        ["!", "\"", "#", "$", "%", "&", "/", "(", ")", "=", "?"],
        ["@", "€", "*", "+", "~", "<", ">", "|", "\\", "^", "°"],
        ["{", "}", "[", "]", "'", "`", ";", ":", "_", "§", "´"],
        ["…", "–", "„", "“", "’", "£", "¥", "µ", "×", "÷"]
    ]

    LazyLoader {
        active: Config.onScreenKeyboard

        PanelWindow {
            id: win
            anchors { left: true; right: true; bottom: true }
            implicitHeight: board.height + 20
            exclusiveZone: implicitHeight
            color: Theme.surfaceContainer
            WlrLayershell.namespace: "voidline-keyboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property bool shift: false
            property bool lock: false           // shift twice = caps lock
            property bool ctrl: false
            property bool alt: false
            property bool signs: false
            readonly property var rows: signs ? root.symbols : root.letters
            readonly property real unit: Math.min(86, (Math.min(width, 1180) - 24) / 12)

            function mods() {
                const m = []
                if (ctrl) m.push("ctrl")
                if (alt) m.push("alt")
                return m
            }
            function used() { ctrl = false; alt = false; if (!lock) shift = false }
            function press(ch) {
                Access.type(shift && !signs ? ch.toUpperCase() : ch, mods())
                used()
            }
            function named(name) { Access.key(name, mods().concat(shift ? ["shift"] : [])); used() }

            component Key: Rectangle {
                id: key
                property string label: ""
                property string icon: ""
                property real span: 1
                property bool held: false           // lit modifier
                property bool strong: false         // accent colour
                property bool repeats: false
                signal tapped()

                width: win.unit * span - 6
                height: 54
                radius: touch.pressed ? Theme.cornerS : Theme.cornerM
                color: held || strong ? Theme.primary : (touch.pressed ? Theme.secondaryContainer : Theme.surfaceContainerHighest)
                Behavior on radius { Spring {} }

                Label {
                    visible: key.icon.length === 0
                    anchors.centerIn: parent
                    text: key.label
                    font.pixelSize: key.label.length > 1 ? Theme.textBody : Theme.textTitle + 2
                    font.weight: Font.DemiBold
                    color: key.held || key.strong ? Theme.inkOnPrimary : Theme.ink
                }
                MIcon {
                    visible: key.icon.length > 0
                    anchors.centerIn: parent
                    icon: key.icon
                    size: 24
                    color: key.held || key.strong ? Theme.inkOnPrimary : Theme.ink
                }
                MouseArea {
                    id: touch
                    anchors.fill: parent
                    onPressed: { key.tapped(); if (key.repeats) again.restart() }
                    onReleased: again.stop()
                    onCanceled: again.stop()
                }
                // Holding backspace, space or an arrow repeats it.
                Timer {
                    id: again
                    interval: 420
                    repeat: true
                    onTriggered: { interval = 60; key.tapped() }
                    onRunningChanged: if (!running) interval = 420
                }
            }

            Label {
                visible: !Access.canType
                anchors.horizontalCenter: parent.horizontalCenter
                y: 2
                z: 2
                text: Lang.t("Typing needs the package “wtype”.")
                font.pixelSize: Theme.textLabelS
                color: Theme.error
            }

            Column {
                id: board
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                spacing: 6

                Repeater {
                    model: 3
                    Row {
                        id: line
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Repeater {
                            model: win.rows[line.index]
                            Key {
                                required property string modelData
                                label: win.shift && !win.signs ? modelData.toUpperCase() : modelData
                                onTapped: win.press(modelData)
                            }
                        }
                        Key { visible: line.index === 0; icon: "backspace"; span: 1.5; repeats: true; onTapped: win.named("BackSpace") }
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Key {
                        icon: win.lock ? "keyboard_capslock" : "shift"
                        span: 1.5
                        held: win.shift
                        onTapped: {
                            if (win.lock) { win.lock = false; win.shift = false }
                            else if (win.shift) win.lock = true
                            else win.shift = true
                        }
                    }
                    Repeater {
                        model: win.rows[3]
                        Key {
                            required property string modelData
                            label: win.shift && !win.signs ? modelData.toUpperCase() : modelData
                            onTapped: win.press(modelData)
                        }
                    }
                    Key { icon: "keyboard_return"; span: 1.5; strong: true; onTapped: win.named("Return") }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Key { label: win.signs ? "abc" : "!#1"; span: 1.5; onTapped: win.signs = !win.signs }
                    Key { label: Lang.t("Ctrl"); span: 1.25; held: win.ctrl; onTapped: win.ctrl = !win.ctrl }
                    Key { label: "Alt"; span: 1.25; held: win.alt; onTapped: win.alt = !win.alt }
                    Key { label: "Esc"; onTapped: win.named("Escape") }
                    Key { icon: "keyboard_tab"; onTapped: win.named("Tab") }
                    Key { icon: "space_bar"; span: 4; repeats: true; onTapped: win.press(" ") }
                    Key { icon: "keyboard_arrow_left"; repeats: true; onTapped: win.named("Left") }
                    Key { icon: "keyboard_arrow_up"; repeats: true; onTapped: win.named("Up") }
                    Key { icon: "keyboard_arrow_down"; repeats: true; onTapped: win.named("Down") }
                    Key { icon: "keyboard_arrow_right"; repeats: true; onTapped: win.named("Right") }
                    Key { icon: "keyboard_hide"; onTapped: Config.onScreenKeyboard = false }
                }
            }
        }
    }
}
