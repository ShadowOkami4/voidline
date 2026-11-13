import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

ColumnLayout {
    id: page
    spacing: 24

    readonly property var nodes: Pipewire.nodes.values.filter(n => !!n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink)
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    function label(n) { return n.description || n.nickname || n.name || "Unknown device" }
    function appName(n) {
        const p = n.properties || {}
        return p["application.name"] || n.description || n.name || "Application"
    }

    PwObjectTracker { objects: page.nodes }

    // ---- output ------------------------------------------------------------------
    SegGroup {
        title: "Output"

        Label {
            Layout.margins: 18
            visible: !page.sink
            text: "No output device found."
            color: Theme.inkMuted
        }

        VolumeItem {
            visible: !!page.sink
            node: page.sink
            hue: 0
            lobes: 8
            title: "Volume"
            description: page.sink ? page.label(page.sink) : ""
        }

        Repeater {
            model: page.outputs.length > 1 ? page.outputs : []
            SegItem {
                id: out
                required property PwNode modelData
                readonly property bool current: modelData === page.sink
                icon: "speaker"
                hue: 1
                lobes: 4
                title: page.label(modelData)
                description: current ? "In use" : ""
                clickable: !current
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                MIcon { visible: out.current; icon: "check_circle"; filled: true; size: 24; color: Theme.primary }
            }
        }
    }

    // ---- input -------------------------------------------------------------------
    SegGroup {
        title: "Input"

        Label {
            Layout.margins: 18
            visible: !page.source
            text: "No microphone found."
            color: Theme.inkMuted
        }

        VolumeItem {
            visible: !!page.source
            node: page.source
            hue: 2
            lobes: 0
            onIcon: "mic"
            offIcon: "mic_off"
            title: "Microphone"
            description: page.source ? page.label(page.source) : ""
        }

        Repeater {
            model: page.inputs.length > 1 ? page.inputs : []
            SegItem {
                id: inp
                required property PwNode modelData
                readonly property bool current: modelData === page.source
                icon: "mic"
                hue: 3
                lobes: 5
                title: page.label(modelData)
                description: current ? "In use" : ""
                clickable: !current
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
                MIcon { visible: inp.current; icon: "check_circle"; filled: true; size: 24; color: Theme.primary }
            }
        }
    }

    // ---- applications ------------------------------------------------------------
    SegGroup {
        title: "Apps"
        visible: page.streams.length > 0

        Repeater {
            model: page.streams
            VolumeItem {
                required property PwNode modelData
                required property int index
                node: modelData
                hue: 4 + index
                lobes: [4, 8, 0, 5][index % 4]
                onIcon: "music_note"
                offIcon: "music_off"
                title: page.appName(modelData)
            }
        }
    }
}
