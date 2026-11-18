import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// The cheat sheet (Super + H): every Voidline shortcut at a glance.
PanelSurface {
    id: root

    open: Shell.panel === "keys"
    anchor: "center"
    panelWidth: 1000
    panelHeight: body.implicitHeight + 48

    // Only actions that have a shortcut right now.
    readonly property var rows: Keybinds.actions.filter(a => Keybinds.combo(a.id).length > 0 && (!a.hyprOnly || Compositor.name === "hyprland"))

    ColumnLayout {
        id: body
        x: 24
        y: 24
        width: parent.width - 48
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            opacity: root.shown(0)
            Label {
                Layout.fillWidth: true
                leftPadding: 4
                text: Lang.t("Keyboard shortcuts")
                font.pixelSize: Theme.textHeadline
                font.weight: Font.Black
            }
            Pressable {
                implicitWidth: change.implicitWidth + 32
                implicitHeight: 40
                color: Theme.surfaceContainerHighest
                restRadius: Theme.cornerFull
                onClicked: Shell.openSettings("shortcuts")
                Label { id: change; anchors.centerIn: parent; text: Lang.t("Change"); font.weight: Font.DemiBold }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 6

            Repeater {
                model: root.rows
                Rectangle {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property real arrived: root.shown(1 + Math.floor(index / 2) * 0.55)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 48
                    radius: Theme.cornerL
                    color: Theme.surfaceContainerHigh
                    opacity: arrived
                    transform: Translate { y: (1 - line.arrived) * 16 }

                    MIcon { id: sign; x: 14; anchors.verticalCenter: parent.verticalCenter; icon: line.modelData.icon; size: 20; color: Theme.primary }
                    Label {
                        anchors.left: sign.right
                        anchors.leftMargin: 12
                        anchors.right: keys.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: line.modelData.label
                        font.pixelSize: Theme.textLabel + 1
                    }
                    Row {
                        id: keys
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: Keybinds.parts(Keybinds.combo(line.modelData.id))
                            Rectangle {
                                required property string modelData
                                width: Math.max(28, cap.implicitWidth + 16)
                                height: 28
                                radius: Theme.cornerS
                                color: Theme.surfaceContainerHighest
                                border.width: 1
                                border.color: Theme.alpha(Theme.outlineVariant, 0.8)
                                Label { id: cap; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: Theme.textLabelS; font.weight: Font.Bold }
                            }
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            leftPadding: 4
            wrapMode: Text.Wrap
            text: Lang.t("Shortcuts from your own window manager config are not listed here.")
            font.pixelSize: Theme.textLabelS
            color: Theme.inkMuted
            opacity: root.shown(7)
        }
    }
}
