pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "../core"

QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputDevices: {
        const nodes = Pipewire.nodes.values
        const devices = []
        for (let index = 0; index < nodes.length; ++index) {
            const node = nodes[index]
            if (!node.isStream && node.properties["media.class"] === "Audio/Sink")
                devices.push(node)
        }
        return devices
    }
    readonly property var inputDevices: {
        const nodes = Pipewire.nodes.values
        const devices = []
        for (let index = 0; index < nodes.length; ++index) {
            const node = nodes[index]
            if (!node.isStream && node.properties["media.class"] === "Audio/Source")
                devices.push(node)
        }
        return devices
    }
    readonly property var playbackStreams: {
        const nodes = Pipewire.nodes.values
        const streams = []
        for (let index = 0; index < nodes.length; ++index) {
            const node = nodes[index]
            if (node.isStream && node.isSink)
                streams.push(node)
        }
        streams.sort((left, right) => root.streamName(left).localeCompare(root.streamName(right)))
        return streams
    }
    readonly property bool outputReady: sink !== null && sink.audio !== null
    readonly property bool inputReady: source !== null && source.audio !== null

    readonly property real outputVolume: outputReady ? sink.audio.volume : 0
    readonly property bool outputMuted: outputReady ? sink.audio.muted : false
    readonly property real inputVolume: inputReady ? source.audio.volume : 0
    readonly property bool inputMuted: inputReady ? source.audio.muted : false

    readonly property string outputLabel: outputMuted ? "Muted" : Math.round(outputVolume * 100) + "%"
    readonly property string inputLabel: inputMuted ? "Muted" : Math.round(inputVolume * 100) + "%"
    readonly property string outputName: outputReady ? (sink.description || sink.nickname || sink.name || "Audio output") : "No output device"
    readonly property string inputName: inputReady ? (source.description || source.nickname || source.name || "Microphone") : "No input device"
    property var audioCards: []
    property var audioPorts: []
    property bool profileChanging: false
    property string profileError: ""
    property string profileMessage: ""
    property var pendingAudioCommand: []
    property bool profileMonitoring: false
    // Safety net for profile switches: if the new profile leaves no usable
    // output, the previous profile is restored automatically.
    property var profileRevert: null

    property var tracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
            .concat(root.outputDevices, root.inputDevices, root.playbackStreams)
    }

    function clamp(value) {
        return Math.max(0, Math.min(1, value))
    }

    function enforceVolumeCaps() {
        if (outputReady && sink.audio.volume > 1)
            sink.audio.volume = 1
        if (inputReady && source.audio.volume > 1)
            source.audio.volume = 1
        for (let index = 0; index < outputDevices.length; ++index) {
            const output = outputDevices[index]
            if (output.audio && output.audio.volume > 1)
                output.audio.volume = 1
        }
        for (let index = 0; index < inputDevices.length; ++index) {
            const input = inputDevices[index]
            if (input.audio && input.audio.volume > 1)
                input.audio.volume = 1
        }
        for (let index = 0; index < playbackStreams.length; ++index) {
            const stream = playbackStreams[index]
            if (stream.audio && stream.audio.volume > 1)
                stream.audio.volume = 1
        }
    }

    function streamName(node) {
        if (!node)
            return "Application"
        const properties = node.properties || ({})
        return properties["application.name"]
            || properties["media.name"]
            || node.description
            || node.nickname
            || node.name
            || "Application"
    }

    function streamDetail(node) {
        if (!node)
            return "Playback stream"
        const properties = node.properties || ({})
        const role = properties["media.role"] || ""
        const mediaName = properties["media.name"] || ""
        if (mediaName.length > 0 && mediaName !== streamName(node))
            return mediaName
        if (role.length > 0)
            return role.charAt(0).toUpperCase() + role.slice(1) + " playback"
        return "Application audio"
    }

    function streamIcon(node) {
        const label = streamName(node).toLowerCase()
        const properties = node ? (node.properties || ({})) : ({})
        const role = (properties["media.role"] || "").toLowerCase()
        if (label.indexOf("spotify") >= 0 || role === "music")
            return "music_note"
        if (label.indexOf("firefox") >= 0 || label.indexOf("chrom") >= 0 || label.indexOf("browser") >= 0)
            return "language"
        if (label.indexOf("discord") >= 0 || label.indexOf("signal") >= 0)
            return "forum"
        if (role === "game")
            return "sports_esports"
        return "apps"
    }

    function streamVolume(node) {
        return node && node.audio ? clamp(node.audio.volume) : 0
    }

    function streamMuted(node) {
        return node && node.audio ? node.audio.muted : false
    }

    function setStreamVolume(node, value) {
        if (node && node.audio)
            node.audio.volume = clamp(value)
    }

    function toggleStreamMute(node) {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted
    }

    function setOutputVolume(value) {
        if (outputReady)
            sink.audio.volume = clamp(value)
    }

    function setInputVolume(value) {
        if (inputReady)
            source.audio.volume = clamp(value)
    }

    function toggleOutputMute() {
        if (outputReady)
            sink.audio.muted = !sink.audio.muted
    }

    function toggleInputMute() {
        if (inputReady)
            source.audio.muted = !source.audio.muted
    }

    function selectOutput(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node
    }

    function selectInput(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node
    }

    function normalizeNamedValues(values) {
        if (!values)
            return []
        if (Array.isArray(values))
            return values
        const next = []
        const keys = Object.keys(values)
        for (let index = 0; index < keys.length; ++index)
            next.push(Object.assign({ name: keys[index] }, values[keys[index]]))
        return next
    }

    function parseProfileSnapshot(contents) {
        try {
            const payload = JSON.parse(contents)
            const cards = []
            const rawCards = payload.cards || []
            for (let index = 0; index < rawCards.length; ++index) {
                const card = rawCards[index]
                const profiles = normalizeNamedValues(card.profiles).map(profile => ({
                    name: profile.name,
                    label: profile.description || profile.name,
                    available: String(profile.available || "yes") !== "no",
                    priority: Number(profile.priority) || 0
                })).filter(profile => profile.available
                    // "Off" disables the card and pro-audio hides the normal
                    // outputs; both silence a desktop. Keep them only when
                    // they are already active so the state is visible.
                    && ((profile.name !== "off" && !profile.name.startsWith("pro-audio"))
                        || profile.name === (typeof card.active_profile === "string"
                            ? card.active_profile : ((card.active_profile || {}).name || ""))))
                profiles.sort((left, right) => right.priority - left.priority)
                const active = typeof card.active_profile === "string"
                    ? card.active_profile
                    : ((card.active_profile || {}).name || "")
                cards.push({
                    name: card.name,
                    label: ((card.properties || {})["device.description"]
                        || ((card.properties || {})["device.product.name"])
                        || card.name),
                    activeProfile: active,
                    profiles: profiles
                })
            }

            const ports = []
            const collectPorts = (nodes, kind) => {
                for (let index = 0; index < nodes.length; ++index) {
                    const node = nodes[index]
                    const nodePorts = normalizeNamedValues(node.ports).map(port => ({
                        name: port.name,
                        label: port.description || port.name,
                        available: String(port.availability || port.available || "yes")
                            !== "not available"
                            && String(port.availability || port.available || "yes") !== "no"
                    })).filter(port => port.available)
                    if (nodePorts.length > 0) {
                        ports.push({
                            kind: kind,
                            name: node.name,
                            label: node.description || node.name,
                            activePort: typeof node.active_port === "string"
                                ? node.active_port : ((node.active_port || {}).name || ""),
                            ports: nodePorts
                        })
                    }
                }
            }
            collectPorts(payload.sinks || [], "sink")
            collectPorts(payload.sources || [], "source")
            audioCards = cards
            audioPorts = ports
            profileError = ""
        } catch (error) {
            profileError = "Audio profiles could not be read"
        }
    }

    function refreshProfiles() {
        if (!profileSnapshot.running && !audioApply.running)
            profileSnapshot.running = true
    }

    function setCardProfile(cardName, profileName) {
        const card = audioCards.find(item => item.name === cardName)
        if (!card || !card.profiles.some(item => item.name === profileName)
                || audioApply.running)
            return
        profileRevert = card.activeProfile && card.activeProfile !== profileName
            ? { card: cardName, profile: card.activeProfile } : null
        audioCards = audioCards.map(item => item.name === cardName
            ? Object.assign({}, item, { activeProfile: profileName }) : item)
        profileChanging = true
        profileError = ""
        profileMessage = "Applying audio profile…"
        pendingAudioCommand = ["sh", Paths.shellRoot + "/scripts/audio-service.sh",
            "set-profile", cardName, profileName]
        audioApply.running = true
    }

    function resetRouting() {
        if (audioApply.running)
            return
        profileRevert = null
        profileChanging = true
        profileError = ""
        profileMessage = I18n.tr("audio.resetting")
        pendingAudioCommand = ["sh", Paths.shellRoot + "/scripts/audio-service.sh", "reset"]
        audioApply.running = true
    }

    function verifyProfile() {
        const revert = profileRevert
        profileRevert = null
        if (!revert || outputReady)
            return
        profileError = I18n.tr("audio.profileReverted")
        profileChanging = true
        pendingAudioCommand = ["sh", Paths.shellRoot + "/scripts/audio-service.sh",
            "set-profile", revert.card, revert.profile]
        audioApply.running = true
    }

    function setPort(kind, nodeName, portName) {
        const node = audioPorts.find(item => item.kind === kind && item.name === nodeName)
        if (!node || !node.ports.some(item => item.name === portName)
                || audioApply.running)
            return
        audioPorts = audioPorts.map(item => item.kind === kind && item.name === nodeName
            ? Object.assign({}, item, { activePort: portName }) : item)
        profileChanging = true
        profileError = ""
        profileMessage = "Switching audio port…"
        pendingAudioCommand = ["sh", Paths.shellRoot + "/scripts/audio-service.sh",
            "set-port", kind, nodeName, portName]
        audioApply.running = true
    }

    property var outputCapWatcher: Connections {
        target: root.outputReady ? root.sink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() { root.enforceVolumeCaps() }
    }

    property var inputCapWatcher: Connections {
        target: root.inputReady ? root.source.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() { root.enforceVolumeCaps() }
    }

    property var initialCapTimer: Timer {
        interval: 300
        running: true
        onTriggered: root.enforceVolumeCaps()
    }

    onOutputReadyChanged: enforceVolumeCaps()
    onInputReadyChanged: enforceVolumeCaps()
    onPlaybackStreamsChanged: enforceVolumeCaps()

    property var profileSnapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/audio-service.sh", "snapshot"]
        stdout: StdioCollector {
            onStreamFinished: root.parseProfileSnapshot(text)
        }
    }

    property var audioApply: Process {
        command: root.pendingAudioCommand
        stderr: StdioCollector { id: audioApplyError }
        onExited: (exitCode, exitStatus) => {
            root.profileChanging = false
            if (exitCode === 0) {
                root.profileMessage = "Audio routing updated"
                profileRefresh.restart()
                if (root.profileRevert)
                    profileVerify.restart()
            } else {
                const detail = audioApplyError.text.trim()
                root.profileError = detail.length > 0
                    ? detail.split("\n").slice(-1)[0]
                    : "The selected audio configuration is unavailable"
                root.profileMessage = ""
                profileRefresh.restart()
            }
        }
    }

    property var profileVerify: Timer {
        interval: 2500
        onTriggered: root.verifyProfile()
    }

    property var profileRefresh: Timer {
        interval: 180
        onTriggered: root.refreshProfiles()
    }

    property var profilePoll: Timer {
        interval: 8000
        repeat: true
        running: root.profileMonitoring
        triggeredOnStart: true
        onTriggered: root.refreshProfiles()
    }
}
