import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// Volume slider with a mute button for one PipeWire node.
SegItem {
    id: root

    property PwNode node: null
    readonly property bool ok: !!node && !!node.audio
    readonly property real volume: ok ? node.audio.volume : 0
    readonly property bool muted: ok ? node.audio.muted : false
    property string onIcon: "volume_up"
    property string offIcon: "volume_off"

    icon: muted ? offIcon : onIcon

    Row {
        spacing: 10
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.volume * 100) + "%"
            font.pixelSize: Theme.textTitle + 2
            font.weight: Font.Black
            color: root.muted ? Theme.inkMuted : Theme.primary
        }
        IconBtn {
            icon: root.muted ? root.offIcon : root.onIcon
            size: 40
            tonal: true
            selected: root.muted
            onClicked: if (root.ok) root.node.audio.muted = !root.muted
        }
    }

    extra: ExpSlider {
        Layout.fillWidth: true
        implicitHeight: 36
        opacity: root.muted ? 0.5 : 1
        value: root.volume
        onMoved: v => { if (root.ok) { root.node.audio.muted = false; root.node.audio.volume = v } }
    }
}
