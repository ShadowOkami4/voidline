pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool available: !!sink && !!sink.audio
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property string icon: muted || volume <= 0 ? "volume_off"
        : (volume < 0.34 ? "volume_mute" : (volume < 0.67 ? "volume_down" : "volume_up"))

    function setVolume(v) {
        if (!available) return
        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, v))
    }
    function toggleMute() { if (available) sink.audio.muted = !sink.audio.muted }

    PwObjectTracker { objects: [root.sink] }
}
