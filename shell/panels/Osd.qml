import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.services
import qs.widgets

// On-screen indicator. A level for volume and brightness; a short "on/off"
// for the microphone, caps lock and num lock. It appears whenever one of
// them changes, whoever changed it (keyboard keys, another app, the shell).
Scope {
    id: root

    // "volume" | "brightness" | "mic" | "caps" | "num"
    property string kind: "volume"
    property bool showing: false
    property bool armed: false      // ignore the values settling at startup

    function flash(what) {
        if (!armed || Shell.locked) return
        if ((what === "volume" || what === "brightness") && Shell.panel === "quick") return
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
        function onMicMutedChanged() { root.flash("mic") }
    }
    Connections {
        target: Brightness
        function onCurrentChanged() { root.flash("brightness") }
    }
    Connections {
        target: LockKeys
        function onCapsChanged() { root.flash("caps") }
        function onNumChanged() { root.flash("num") }
    }

    readonly property bool isLevel: kind === "volume" || kind === "brightness"
    readonly property real level: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value
    // For the on/off kinds.
    readonly property bool on: kind === "mic" ? !Audio.micMuted : (kind === "caps" ? LockKeys.caps : LockKeys.num)
    readonly property string icon: kind === "volume" ? Audio.icon
        : kind === "brightness" ? "brightness_medium"
        : kind === "mic" ? (on ? "mic" : "mic_off")
        : kind === "caps" ? "keyboard_capslock" : "pin"
    readonly property string words: kind === "mic" ? (on ? Lang.t("Microphone on") : Lang.t("Microphone muted"))
        : kind === "caps" ? (on ? Lang.t("Caps lock on") : Lang.t("Caps lock off"))
        : (on ? Lang.t("Num lock on") : Lang.t("Num lock off"))

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
                anchors.centerIn: parent
                height: parent.height
                width: root.isLevel ? parent.width : Math.min(parent.width, state.implicitWidth + 96)
                radius: height / 2
                color: !root.isLevel && root.on ? Theme.primaryContainer : Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
                opacity: root.showing ? 1 : 0
                scale: root.showing ? 1 : 0.9
                Behavior on opacity { Fade {} }
                Behavior on scale { Spring {} }
                Behavior on width { Spring {} }
                Behavior on color { Tint {} }

                MIcon {
                    id: glyph
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.icon
                    filled: true
                    size: 24
                    color: !root.isLevel && root.on ? Theme.inkOnPrimaryContainer : Theme.ink
                    // A little bounce for the on/off kinds.
                    scale: root.showing ? 1 : 0.6
                    Behavior on scale { Spring { duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }
                }
                Rectangle {
                    id: track
                    visible: root.isLevel
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
                    visible: root.isLevel
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.level * 100)
                    font.weight: Font.Black
                    font.pixelSize: Theme.textTitle
                }
                Label {
                    id: state
                    visible: !root.isLevel
                    anchors.left: glyph.right
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.words
                    font.weight: Font.Bold
                    color: root.on ? Theme.inkOnPrimaryContainer : Theme.ink
                }
            }
        }
    }
}
