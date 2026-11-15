import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.widgets

// Snap layouts (Super + Z): put the active window into a half, a third or a
// corner of the screen. The window leaves the tiling for that and floats in
// the chosen place; "Back into the tiling" undoes it.
PanelSurface {
    id: root

    open: Shell.panel === "snap"
    anchor: "center"
    panelWidth: 3 * 168 + 2 * 12 + 48
    panelHeight: body.implicitHeight + 48

    // Each layout is a list of zones as shares of the screen: x, y, w, h.
    readonly property var layouts: [
        [{ x: 0, y: 0, w: 0.5, h: 1 }, { x: 0.5, y: 0, w: 0.5, h: 1 }],
        [{ x: 0, y: 0, w: 2 / 3, h: 1 }, { x: 2 / 3, y: 0, w: 1 / 3, h: 1 }],
        [{ x: 0, y: 0, w: 1 / 3, h: 1 }, { x: 1 / 3, y: 0, w: 1 / 3, h: 1 }, { x: 2 / 3, y: 0, w: 1 / 3, h: 1 }],
        [{ x: 0, y: 0, w: 0.5, h: 1 }, { x: 0.5, y: 0, w: 0.5, h: 0.5 }, { x: 0.5, y: 0.5, w: 0.5, h: 0.5 }],
        [{ x: 0, y: 0, w: 0.5, h: 0.5 }, { x: 0.5, y: 0, w: 0.5, h: 0.5 }, { x: 0, y: 0.5, w: 0.5, h: 0.5 }, { x: 0.5, y: 0.5, w: 0.5, h: 0.5 }],
        [{ x: 0.15, y: 0.1, w: 0.7, h: 0.8 }]
    ]

    // The window that was active when the panel opened.
    property var target: null
    onOpenChanged: if (open) target = Compositor.focusedWindow

    function place(zone) {
        const win = target
        Shell.close()
        if (win) Compositor.snap(win.id, zone)
    }

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
                leftPadding: 4
                text: Lang.t("Arrange window")
                font.pixelSize: 24
                font.weight: Font.Black
            }
            Label {
                Layout.fillWidth: true
                leftPadding: 4
                elide: Text.ElideRight
                text: root.target ? (root.target.title || root.target.appId) : Lang.t("No window is active.")
                color: Theme.inkMuted
            }
        }

        Grid {
            columns: 3
            spacing: 12
            opacity: root.target ? 1 : 0.4
            enabled: !!root.target

            Repeater {
                model: root.layouts
                // A small picture of the screen with its zones.
                Rectangle {
                    id: mini
                    required property var modelData
                    width: 168
                    height: 104
                    radius: Theme.cornerL
                    color: Theme.surfaceContainerHighest

                    Repeater {
                        model: mini.modelData
                        Pressable {
                            required property var modelData
                            x: 6 + modelData.x * (mini.width - 12) + 2
                            y: 6 + modelData.y * (mini.height - 12) + 2
                            width: modelData.w * (mini.width - 12) - 4
                            height: modelData.h * (mini.height - 12) - 4
                            color: hovered ? Theme.primary : Theme.alpha(Theme.primary, 0.28)
                            restRadius: Theme.cornerS
                            pressedRadius: Theme.cornerS - 2
                            Behavior on color { Tint {} }
                            onClicked: root.place(modelData)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            enabled: !!root.target
            opacity: enabled ? 1 : 0.4
            Pressable {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 48
                color: Theme.surfaceContainerHighest
                onClicked: { const w = root.target; Shell.close(); if (w) Compositor.tile(w.id) }
                Label { anchors.centerIn: parent; text: Lang.t("Back into the tiling"); font.weight: Font.DemiBold }
            }
            Pressable {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 48
                color: Theme.surfaceContainerHighest
                onClicked: { const w = root.target; Shell.close(); if (w) Compositor.toggleMaximize(w.id) }
                Label { anchors.centerIn: parent; text: Lang.t("Fill the screen"); font.weight: Font.DemiBold }
            }
        }
    }
}
