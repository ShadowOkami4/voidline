import QtQuick
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18

    SettingsSection {
        fullWidth: true
        title: I18n.tr("audio.volume")
        subtitle: I18n.tr("audio.volumeHint")
        icon: "volume_up"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsSlider {
            width: parent.width
            title: I18n.tr("audio.outputVolume")
            subtitle: AudioService.outputName
            icon: AudioService.outputMuted ? "volume_off" : "volume_up"
            from: 0; to: 100; value: AudioService.outputVolume * 100; suffix: "%"
            enabled: AudioService.outputReady
            onChanged: value => AudioService.setOutputVolume(value / 100)
        }
        SettingsToggle {
            width: parent.width
            icon: AudioService.outputMuted ? "volume_off" : "volume_up"
            title: I18n.tr("audio.muteOutput")
            subtitle: I18n.tr("audio.muteOutputHint")
            checked: AudioService.outputMuted
            enabled: AudioService.outputReady
            onToggled: value => {
                if (value !== AudioService.outputMuted)
                    AudioService.toggleOutputMute()
            }
        }
        SettingsSlider {
            width: parent.width
            title: I18n.tr("audio.microphoneLevel")
            subtitle: AudioService.inputName
            icon: AudioService.inputMuted ? "mic_off" : "mic"
            from: 0; to: 100; value: AudioService.inputVolume * 100; suffix: "%"
            enabled: AudioService.inputReady
            onChanged: value => AudioService.setInputVolume(value / 100)
        }
        SettingsToggle {
            width: parent.width
            icon: AudioService.inputMuted ? "mic_off" : "mic"
            title: I18n.tr("audio.muteMicrophone")
            subtitle: I18n.tr("audio.muteMicrophoneHint")
            checked: AudioService.inputMuted
            enabled: AudioService.inputReady
            onToggled: value => {
                if (value !== AudioService.inputMuted)
                    AudioService.toggleInputMute()
            }
        }
    }

    SettingsSection {
        title: I18n.tr("audio.outputDevices")
        subtitle: I18n.tr("audio.outputDevicesHint")
        icon: "speaker"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        Repeater {
            model: AudioService.outputDevices
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: "speaker"
                title: modelData.description || modelData.nickname || modelData.name
                subtitle: modelData.name || I18n.tr("audio.pipewireOutput")
                value: modelData === AudioService.sink
                    ? I18n.tr("audio.default") : ""
                active: modelData === AudioService.sink
                onClicked: AudioService.selectOutput(modelData)
            }
        }
        SettingsAction {
            width: parent.width
            icon: "spatial_audio"
            title: I18n.tr("audio.balance")
            subtitle: I18n.tr("audio.balanceHint")
            value: I18n.tr("audio.centered")
            enabled: false
        }
        Repeater {
            model: AudioService.audioCards
            SettingsChoice {
                required property var modelData
                width: parent.width
                title: modelData.label
                subtitle: I18n.tr("audio.profileHint")
                options: modelData.profiles.map(item => item.name)
                optionLabels: modelData.profiles.map(item => item.label)
                value: modelData.activeProfile
                enabled: !AudioService.profileChanging && modelData.profiles.length > 0
                onSelected: value => AudioService.setCardProfile(modelData.name, value)
            }
        }
        Repeater {
            model: AudioService.audioPorts.filter(item => item.kind === "sink")
            SettingsChoice {
                required property var modelData
                width: parent.width
                title: I18n.tr("audio.port", { device: modelData.label })
                subtitle: I18n.tr("audio.outputPortHint")
                options: modelData.ports.map(item => item.name)
                optionLabels: modelData.ports.map(item => item.label)
                value: modelData.activePort
                enabled: !AudioService.profileChanging
                onSelected: value => AudioService.setPort("sink", modelData.name, value)
            }
        }
    }

    SettingsSection {
        title: I18n.tr("audio.inputDevices")
        subtitle: I18n.tr("audio.inputDevicesHint")
        icon: "mic"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        Repeater {
            model: AudioService.inputDevices
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: "mic"
                title: modelData.description || modelData.nickname || modelData.name
                subtitle: modelData.name || I18n.tr("audio.pipewireInput")
                value: modelData === AudioService.source
                    ? I18n.tr("audio.default") : ""
                active: modelData === AudioService.source
                onClicked: AudioService.selectInput(modelData)
            }
        }
        Repeater {
            model: AudioService.audioPorts.filter(item => item.kind === "source")
            SettingsChoice {
                required property var modelData
                width: parent.width
                title: I18n.tr("audio.port", { device: modelData.label })
                subtitle: I18n.tr("audio.inputPortHint")
                options: modelData.ports.map(item => item.name)
                optionLabels: modelData.ports.map(item => item.label)
                value: modelData.activePort
                enabled: !AudioService.profileChanging
                onSelected: value => AudioService.setPort("source", modelData.name, value)
            }
        }
        SettingsToggle {
            width: parent.width
            icon: "hearing"
            title: I18n.tr("audio.inputMonitoring")
            subtitle: I18n.tr("audio.inputMonitoringHint")
            checked: false
            enabled: false
        }
    }

    SettingsSection {
        fullWidth: true
        title: I18n.tr("audio.applicationVolume")
        subtitle: AudioService.playbackStreams.length > 0
            ? I18n.plural("audio.activeStreams",
                AudioService.playbackStreams.length)
            : I18n.tr("audio.noStreams")
        icon: "apps"
        iconContainerColor: Theme.accentContainer
        iconColor: Theme.accent

        Repeater {
            model: AudioService.playbackStreams
            SettingsSlider {
                required property var modelData
                width: parent.width
                title: AudioService.streamName(modelData)
                subtitle: AudioService.streamDetail(modelData)
                icon: AudioService.streamIcon(modelData)
                from: 0; to: 100
                value: AudioService.streamVolume(modelData) * 100
                suffix: "%"
                onChanged: value => AudioService.setStreamVolume(modelData, value / 100)
            }
        }
    }

    SettingsSection {
        fullWidth: true
        title: I18n.tr("audio.soundBehavior")
        subtitle: I18n.tr("audio.soundBehaviorHint")
        icon: "graphic_eq"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsSlider {
            width: parent.width
            title: I18n.tr("audio.notificationVolume")
            subtitle: I18n.tr("audio.notificationVolumeUnsupported")
            icon: "notifications"
            from: 0; to: 100; value: AudioService.outputVolume * 100; suffix: "%"
            enabled: false
        }
        SettingsAction {
            width: parent.width
            icon: "campaign"
            title: I18n.tr("audio.testSound")
            subtitle: I18n.tr("audio.testSoundHint")
            value: I18n.tr("audio.play")
            enabled: SystemSettingsService.available("pipewire")
            onClicked: SystemSettingsService.testSound()
        }
        SettingsToggle {
            width: parent.width
            icon: "music_note"
            title: I18n.tr("audio.interfaceSounds")
            subtitle: I18n.tr("audio.interfaceSoundsHint")
            checked: false
            enabled: false
        }
        SettingsAction {
            width: parent.width
            icon: "call"
            title: I18n.tr("audio.communicationDevice")
            subtitle: I18n.tr("audio.communicationDeviceHint")
            value: AudioService.outputName
            enabled: false
        }
    }
}
