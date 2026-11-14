import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.services
import qs.widgets

// On-screen indicator for volume and brightness. It appears whenever either
// value changes, whoever changed it (keyboard keys, another app, the shell).
Scope {
    id: root

    property string kind: "volume"
    property bool showing: false
    property bool armed: false      // ignore the values settling at startup

    function flash(what) {
        if (!armed || Shell.panel === "quick" || Shell.locked) return
        kind = what
        showing = true
        hide.restart()
    }

    Timer { interval: 2500; running: true; onTriggered: root.armed = true }
    Timer { id: hide; interval: 1600; onTriggered: { root.showing = false; linger.restart() } }
    // Keeps the window alive while it fades out.
    Timer { id: linger; interval: 400 }

    Connections {
        target: Audio
        function onVolumeChanged() { root.flash("volume") }
        function onMutedChanged() { root.flash("volume") }
    }
    Connections {
        target: Brightness
        function onCurrentChanged() { root.flash("brightness") }
    }

    readonly property real level: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value
    readonly property string icon: kind === "volume" ? Audio.icon : "brightness_medium"

    LazyLoader {
        active: root.showing || linger.running

        PanelWindow {
            anchors { bottom: true }
            margins { bottom: 90 }
            implicitWidth: 300
            implicitHeight: 64
            exclusiveZone: Shell.coverZone
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "voidline-osd"
            WlrLayershell.layer: WlrLayer.Overlay

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
                opacity: root.showing ? 1 : 0
                scale: root.showing ? 1 : 0.9
                Behavior on opacity { Fade {} }
                Behavior on scale { Spring {} }

                MIcon {
                    id: glyph
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.icon
                    filled: true
                    size: 24
                    color: Theme.ink
                }
                Rectangle {
                    id: track
                    anchors.left: glyph.right
                    anchors.leftMargin: 14
                    anchors.right: number.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    radius: 7
                    color: Theme.surfaceContainerHighest
                    Rectangle {
                        width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.level)))
                        height: parent.height
                        radius: parent.radius
                        color: root.kind === "volume" ? Theme.primary : Theme.tertiary
                        Behavior on width { Spring { duration: Motion.effects } }
                    }
                }
                Label {
                    id: number
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.level * 100)
                    font.weight: Font.Black
                    font.pixelSize: Theme.textTitle
                }
            }
        }
    }
}
