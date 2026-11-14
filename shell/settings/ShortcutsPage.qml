import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Voidline's own keyboard shortcuts. Click one, then press the new keys.
ColumnLayout {
    id: page
    spacing: 24

    // Id of the action waiting for a key press.
    property string recording: ""
    function record(id) { recording = recording === id ? "" : id; if (recording) catcher.forceActiveFocus() }

    // Qt key -> XKB key name.
    readonly property var named: ({
        [Qt.Key_Space]: "space", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab",
        [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next",
        [Qt.Key_Insert]: "Insert", [Qt.Key_Delete]: "Delete", [Qt.Key_Print]: "Print",
        [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal",
        [Qt.Key_Slash]: "slash", [Qt.Key_Backslash]: "backslash", [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe",
        [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_QuoteLeft]: "grave"
    })
    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (key - Qt.Key_F1 + 1)
        return named[key] ?? ""
    }

    Item {
        id: catcher
        Keys.onPressed: event => {
            if (page.recording.length === 0) return
            event.accepted = true
            const m = event.modifiers
            const mods = []
            if (m & Qt.MetaModifier) mods.push("SUPER")
            if (m & Qt.ControlModifier) mods.push("CTRL")
            if (m & Qt.AltModifier) mods.push("ALT")
            if (m & Qt.ShiftModifier) mods.push("SHIFT")
            if (event.key === Qt.Key_Escape && mods.length === 0) { page.recording = ""; return }
            if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && mods.length === 0) {
                Keybinds.assign(page.recording, "")
                page.recording = ""
                return
            }
            const key = page.keyName(event.key)
            if (key.length === 0) return        // a modifier on its own, or a key we cannot name
            // A plain letter would swallow typing: ask for a modifier, except on F-keys.
            const bare = mods.length === 0 || (mods.length === 1 && mods[0] === "SHIFT")
            if (bare && !/^(F\d+|Print)$/.test(key)) return
            Keybinds.assign(page.recording, mods.concat([key]).join("+"))
            page.recording = ""
        }
        onActiveFocusChanged: if (!activeFocus) page.recording = ""
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hint.implicitHeight + 32
        radius: Theme.cornerXL
        color: page.recording ? Theme.primaryContainer : Theme.surfaceContainerHigh
        Behavior on color { Tint {} }
        RowLayout {
            id: hint
            x: 20
            y: 16
            width: parent.width - 40
            spacing: 16
            MIcon { icon: page.recording ? "keyboard" : "info"; filled: true; size: 24; color: page.recording ? Theme.inkOnPrimaryContainer : Theme.inkMuted }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: page.recording ? Theme.inkOnPrimaryContainer : Theme.inkMuted
                text: page.recording ? "Press the new shortcut now. Esc cancels, Backspace switches the shortcut off."
                    : "Click a shortcut, then press the keys you want. Keys that " + (Compositor.name === "niri" ? "Niri" : "Hyprland")
                        + " already uses for something else in your own config cannot be picked up here."
            }
        }
    }

    SegGroup {
        title: "Voidline"
        Repeater {
            model: Keybinds.actions
            SegItem {
                id: row
                required property var modelData
                required property int index
                readonly property bool hot: page.recording === modelData.id
                readonly property string combo: Keybinds.combo(modelData.id)
                icon: modelData.icon
                hue: index
                lobes: [8, 0, 4, 5][index % 4]
                title: modelData.label
                description: hot ? "Waiting for keys…" : (Keybinds.isDefault(modelData.id) ? "" : "Changed")
                clickable: true
                color: hot ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                Behavior on color { Tint {} }
                onClicked: page.record(modelData.id)

                Row {
                    spacing: 6
                    Repeater {
                        model: Keybinds.parts(row.combo)
                        Rectangle {
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(38, cap.implicitWidth + 22)
                            height: 38
                            radius: Theme.cornerS
                            color: Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: Theme.outlineVariant
                            Label { id: cap; anchors.centerIn: parent; text: parent.modelData; font.weight: Font.Bold; font.pixelSize: Theme.textLabel + 1 }
                        }
                    }
                    Label {
                        visible: row.combo.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Off"
                        color: Theme.inkMuted
                        font.weight: Font.DemiBold
                    }
                    IconBtn {
                        visible: !Keybinds.isDefault(row.modelData.id)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "undo"
                        size: 38
                        onClicked: Keybinds.reset(row.modelData.id)
                    }
                }
            }
        }
    }

    Pressable {
        visible: !Keybinds.allDefault
        Layout.alignment: Qt.AlignLeft
        implicitWidth: resetLabel.implicitWidth + 44
        implicitHeight: 46
        color: Theme.secondaryContainer
        tint: Theme.inkOnSecondaryContainer
        onClicked: Keybinds.resetAll()
        Label { id: resetLabel; anchors.centerIn: parent; text: "Reset all shortcuts"; font.weight: Font.DemiBold; color: Theme.inkOnSecondaryContainer }
    }
}
