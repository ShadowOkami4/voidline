import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// The password dialog (polkit agent). When an app or a setting needs
// administrator rights, the system asks here. The password goes straight to
// the system's own check and is never stored. If another agent is already
// running in the session, this one stays out of the way.
Scope {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: agent.flow

    LazyLoader {
        active: agent.isActive && !!root.flow

        PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.alpha("#000000", 0.5)
            WlrLayershell.namespace: "voidline-auth"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            function cancel() { if (root.flow) root.flow.cancelAuthenticationRequest() }
            function send() {
                if (!root.flow || !root.flow.isResponseRequired) return
                root.flow.submit(secret.text)
                secret.text = ""
            }

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Rectangle {
                anchors.centerIn: parent
                width: 440
                height: body.implicitHeight + 56
                radius: Theme.cornerXXL
                color: Theme.surfaceContainerHigh

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
                        MIcon { anchors.centerIn: parent; icon: "lock"; filled: true; size: 30; color: Theme.inkOnPrimaryContainer }
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "Password needed"
                        font.pixelSize: 24
                        font.weight: Font.Black
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: root.flow ? root.flow.message : ""
                        color: Theme.inkMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 54
                        radius: Theme.cornerL
                        color: Theme.surfaceContainerHighest
                        border.width: 2
                        border.color: root.flow && root.flow.failed ? Theme.error : Theme.primary
                        TextInput {
                            id: secret
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                            color: Theme.ink
                            selectionColor: Theme.primaryContainer
                            font.family: Theme.font
                            font.pixelSize: Theme.textTitle
                            clip: true
                            Component.onCompleted: forceActiveFocus()
                            Keys.onReturnPressed: win.send()
                            Keys.onEnterPressed: win.send()
                            Keys.onEscapePressed: win.cancel()
                            Label {
                                visible: secret.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                                color: Theme.inkMuted
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: !root.flow ? "" : (root.flow.supplementaryMessage || (root.flow.failed ? "That did not work. Try again." : ""))
                        color: root.flow && (root.flow.failed || root.flow.supplementaryIsError) ? Theme.error : Theme.inkMuted
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Pressable {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 50
                            color: Theme.surfaceContainerHighest
                            onClicked: win.cancel()
                            Label { anchors.centerIn: parent; text: "Cancel"; font.weight: Font.DemiBold }
                        }
                        Pressable {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 50
                            color: Theme.primary
                            tint: Theme.inkOnPrimary
                            onClicked: win.send()
                            Label { anchors.centerIn: parent; text: "Continue"; font.weight: Font.Bold; color: Theme.inkOnPrimary }
                        }
                    }
                }
            }
        }
    }
}
