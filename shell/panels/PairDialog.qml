import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Bluetooth pairing questions: compare a number, type a code, or allow a
// device to connect. Bt (services) talks to the system; this only shows it.
Scope {
    id: root

    readonly property var ask: Bt.ask
    readonly property string kind: ask ? ask.kind : ""
    readonly property bool typing: kind === "pin" || kind === "passkey"
    readonly property string who: Bt.asking ? Bt.asking.name : Lang.t("this device")

    LazyLoader {
        active: !!root.ask

        PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: Shell.coverZone
            color: Theme.alpha("#000000", 0.5)
            WlrLayershell.namespace: "voidline-pair"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            function yes() {
                if (root.kind === "show") return
                if (root.typing) { if (code.text.trim().length > 0) Bt.answer(code.text.trim()) }
                else Bt.answer("yes")
            }

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Rectangle {
                anchors.centerIn: parent
                width: 440
                height: body.implicitHeight + 56
                radius: Theme.cornerXXL
                color: Theme.surfaceContainerHigh
                focus: true
                Keys.onEscapePressed: Bt.refuse()
                Keys.onReturnPressed: win.yes()
                Keys.onEnterPressed: win.yes()
                Component.onCompleted: if (!root.typing) forceActiveFocus()

                ColumnLayout {
                    id: body
                    x: 28
                    y: 28
                    width: parent.width - 56
                    spacing: 16

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 64
                        implicitHeight: 64
                        Blob { anchors.fill: parent; lobes: 8; fill: Theme.primaryContainer }
                        MIcon { anchors.centerIn: parent; icon: "bluetooth"; size: 30; color: Theme.inkOnPrimaryContainer }
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.kind === "service" ? Lang.t("Allow %1 to connect?", root.who)
                            : (root.kind === "show" ? Lang.t("Type this on %1", root.who)
                                : (root.typing ? Lang.t("Code for %1", root.who) : Lang.t("Pair with %1?", root.who)))
                        font.pixelSize: 24
                        font.weight: Font.Black
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.kind === "confirm" ? Lang.t("Check that the device shows the same number.")
                            : (root.kind === "show" ? Lang.t("Type the number on the device, then press Enter there.")
                                : (root.typing ? Lang.t("The code is shown on the device or printed in its manual. Often it is 0000 or 1234.")
                                    : (root.kind === "service" ? Lang.t("It is asking to use this computer.") : Lang.t("The device is asking to pair with this computer."))))
                        color: Theme.inkMuted
                    }

                    // The number to compare or to type on the device.
                    Rectangle {
                        visible: root.kind === "confirm" || root.kind === "show"
                        Layout.fillWidth: true
                        implicitHeight: 84
                        radius: Theme.cornerXL
                        color: Theme.secondaryContainer
                        Label {
                            anchors.centerIn: parent
                            text: root.ask ? root.ask.code : ""
                            font.pixelSize: 40
                            font.weight: Font.Black
                            font.letterSpacing: 6
                            color: Theme.inkOnSecondaryContainer
                        }
                    }

                    Rectangle {
                        visible: root.typing
                        Layout.fillWidth: true
                        implicitHeight: 54
                        radius: Theme.cornerL
                        color: Theme.surfaceContainerHighest
                        border.width: 2
                        border.color: Theme.primary
                        TextInput {
                            id: code
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            // A passkey is digits only; a PIN may hold letters.
                            inputMethodHints: root.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                            validator: RegularExpressionValidator { regularExpression: root.kind === "passkey" ? /[0-9]{0,6}/ : /[\x20-\x7e]{0,16}/ }
                            color: Theme.ink
                            selectionColor: Theme.primaryContainer
                            font.family: Theme.font
                            font.pixelSize: Theme.textTitle + 4
                            font.letterSpacing: 3
                            clip: true
                            Component.onCompleted: if (root.typing) forceActiveFocus()
                            Keys.onReturnPressed: win.yes()
                            Keys.onEnterPressed: win.yes()
                            Keys.onEscapePressed: Bt.refuse()
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
                            onClicked: Bt.refuse()
                            Label { anchors.centerIn: parent; text: Lang.t("Cancel"); font.weight: Font.DemiBold }
                        }
                        Pressable {
                            visible: root.kind !== "show"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 50
                            color: Theme.primary
                            tint: Theme.inkOnPrimary
                            onClicked: win.yes()
                            Label {
                                anchors.centerIn: parent
                                text: root.kind === "service" ? Lang.t("Allow") : Lang.t("Pair")
                                font.weight: Font.Bold
                                color: Theme.inkOnPrimary
                            }
                        }
                    }
                }
            }
        }
    }
}
