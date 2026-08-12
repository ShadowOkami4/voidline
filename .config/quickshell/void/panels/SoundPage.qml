import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    property string pickerKind: ""
    readonly property var pickerDevices: pickerKind === "output" ? AudioService.outputDevices : AudioService.inputDevices
    readonly property int applicationCount: AudioService.playbackStreams ? AudioService.playbackStreams.length : 0
    readonly property int applicationAreaHeight: applicationCount === 0 ? 88 : Math.min(246, applicationCount * 82)
    readonly property int requestedBodyHeight: 720
    signal back

    function outputIcon() {
        if (AudioService.outputMuted || AudioService.outputVolume <= 0.001)
            return "volume_off"
        if (AudioService.outputVolume < 0.35)
            return "volume_mute"
        if (AudioService.outputVolume < 0.75)
            return "volume_down"
        return "volume_up"
    }

    function deviceIcon(node) {
        const label = ((node ? (node.description || node.nickname || node.name) : "") || "").toLowerCase()
        if (root.pickerKind === "input")
            return "mic"
        if (label.indexOf("head") >= 0 || label.indexOf("ult wear") >= 0)
            return "headphones"
        if (label.indexOf("hdmi") >= 0 || label.indexOf("display") >= 0)
            return "tv"
        return "speaker"
    }

    onActiveChanged: {
        AudioService.profileMonitoring = active
        if (!active)
            pickerKind = ""
        else
            AudioService.enforceVolumeCaps()
    }

    Component.onDestruction: {
        if (AudioService.profileMonitoring)
            AudioService.profileMonitoring = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        PanelHeader {
            Layout.fillWidth: true
            title: "Sound"
            subtitle: "Playback, applications and input"
            showToggle: true
            toggleChecked: AudioService.outputReady && !AudioService.outputMuted
            toggleEnabled: AudioService.outputReady
            onBack: root.back()
            onToggled: checked => {
                if (checked === AudioService.outputMuted)
                    AudioService.toggleOutputMute()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            Layout.maximumHeight: 150
            radius: Theme.radiusExtraLarge
            color: AudioService.outputMuted ? Theme.surfaceLow : Theme.accentContainer

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            ColumnLayout {
                anchors { fill: parent; margins: 7 }
                spacing: 6

                ExpressiveSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78
                    title: "Media output"
                    subtitle: AudioService.outputName
                    valueText: AudioService.outputLabel
                    containerColor: "transparent"
                    from: 0
                    to: 1
                    value: AudioService.outputVolume
                    muted: AudioService.outputMuted
                    icon: root.outputIcon()
                    activeColor: Theme.accent
                    leadingColor: AudioService.outputMuted ? Theme.surfaceHigh : Theme.accentStrong
                    leadingIconColor: AudioService.outputMuted ? Theme.textMuted : Theme.accentInk
                    enabled: AudioService.outputReady
                    onIconClicked: AudioService.toggleOutputMute()
                    onMoved: value => {
                        if (AudioService.outputMuted && value > 0)
                            AudioService.toggleOutputMute()
                        AudioService.setOutputVolume(value)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: Theme.radiusLarge
                    color: outputRouteHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow

                    RowLayout {
                        anchors { fill: parent; leftMargin: 13; rightMargin: 11 }
                        spacing: 10

                        MaterialIcon {
                            text: root.deviceIcon(AudioService.sink)
                            size: 20
                            color: Theme.accent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: "Playing on"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                text: AudioService.outputName
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                        }

                        MaterialIcon {
                            text: root.pickerKind === "output" ? "expand_less" : "chevron_right"
                            size: 21
                            color: Theme.textMuted
                        }
                    }

                    HoverHandler { id: outputRouteHover }
                    TapHandler { onTapped: root.pickerKind = root.pickerKind === "output" ? "" : "output" }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: normalMixer
                anchors.fill: parent
                visible: root.pickerKind.length === 0
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Layout.leftMargin: 7
                    Layout.rightMargin: 7
                    spacing: 9

                    MaterialIcon {
                        text: "instant_mix"
                        size: 20
                        color: Theme.tertiary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Application volume"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }

                        Text {
                            text: root.applicationCount > 0 ? "Independent playback levels" : "Apps appear when they play audio"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Medium
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 26
                        radius: Theme.pillRadius
                        color: Theme.tertiaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: root.applicationCount + (root.applicationCount === 1 ? " app" : " apps")
                            color: Theme.tertiary
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }

                ListView {
                    id: applicationList
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.applicationCount > 0 ? root.applicationAreaHeight : 0
                    Layout.maximumHeight: root.applicationCount > 0 ? root.applicationAreaHeight : 0
                    visible: root.applicationCount > 0
                    model: AudioService.playbackStreams
                    spacing: 6
                    clip: true
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ExpressiveSlider {
                        id: appRow
                        required property var modelData
                        readonly property bool streamReady: modelData !== null && modelData.audio !== null
                        readonly property real streamVolume: streamReady ? AudioService.streamVolume(modelData) : 0
                        readonly property bool streamMuted: streamReady ? AudioService.streamMuted(modelData) : false

                        width: applicationList.width
                        height: 76
                        title: AudioService.streamName(modelData)
                        subtitle: AudioService.streamDetail(modelData)
                        valueText: streamMuted ? "Muted" : Math.round(streamVolume * 100) + "%"
                        from: 0
                        to: 1
                        value: streamVolume
                        muted: streamMuted
                        icon: streamMuted ? "volume_off" : AudioService.streamIcon(modelData)
                        containerColor: Theme.surfaceLow
                        activeColor: Theme.tertiary
                        leadingColor: Theme.tertiaryContainer
                        leadingIconColor: Theme.tertiary
                        enabled: streamReady
                        onIconClicked: AudioService.toggleStreamMute(modelData)
                        onMoved: value => {
                            if (appRow.streamMuted && value > 0)
                                AudioService.toggleStreamMute(appRow.modelData)
                            AudioService.setStreamVolume(appRow.modelData, value)
                        }

                        Connections {
                            target: appRow.streamReady ? appRow.modelData.audio : null
                            ignoreUnknownSignals: true
                            function onVolumeChanged() {
                                if (appRow.modelData.audio.volume > 1)
                                    AudioService.setStreamVolume(appRow.modelData, 1)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.applicationCount === 0 ? 88 : 0
                    Layout.maximumHeight: root.applicationCount === 0 ? 88 : 0
                    visible: root.applicationCount === 0
                    radius: Theme.radiusLarge
                    color: Theme.surfaceLow

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }
                        spacing: 13

                        Rectangle {
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 54
                            radius: Theme.radiusMedium
                            color: Theme.tertiaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "music_off"
                                size: 25
                                color: Theme.tertiary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "No active playback"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Start audio in an application to mix it here"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142
                    Layout.maximumHeight: 142
                    radius: Theme.radiusExtraLarge
                    color: AudioService.inputMuted ? Theme.surfaceLow : Theme.secondaryContainer

                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    ColumnLayout {
                        anchors { fill: parent; margins: 7 }
                        spacing: 6

                        ExpressiveSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            title: "Microphone"
                            subtitle: AudioService.inputName
                            valueText: AudioService.inputLabel
                            containerColor: "transparent"
                            from: 0
                            to: 1
                            value: AudioService.inputVolume
                            muted: AudioService.inputMuted
                            icon: AudioService.inputMuted ? "mic_off" : "mic"
                            activeColor: Theme.secondary
                            leadingColor: AudioService.inputMuted ? Theme.surfaceHigh : Theme.secondary
                            leadingIconColor: AudioService.inputMuted ? Theme.textMuted : Theme.accentInk
                            enabled: AudioService.inputReady
                            onIconClicked: AudioService.toggleInputMute()
                            onMoved: value => {
                                if (AudioService.inputMuted && value > 0)
                                    AudioService.toggleInputMute()
                                AudioService.setInputVolume(value)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            radius: Theme.radiusMedium
                            color: inputRouteHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow

                            RowLayout {
                                anchors { fill: parent; leftMargin: 13; rightMargin: 10 }
                                spacing: 9

                                MaterialIcon { text: "mic"; size: 19; color: Theme.secondary }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: "Input device"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: AudioService.inputName
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }
                                }

                                MaterialIcon {
                                    text: root.pickerKind === "input" ? "expand_less" : "chevron_right"
                                    size: 20
                                    color: Theme.textMuted
                                }
                            }

                            HoverHandler { id: inputRouteHover }
                            TapHandler { onTapped: root.pickerKind = root.pickerKind === "input" ? "" : "input" }
                        }
                    }
                }
            }

            Rectangle {
                id: pickerSurface
                anchors.fill: parent
                visible: root.pickerKind.length > 0
                radius: Theme.radiusExtraLarge
                color: Theme.surfaceLow
                clip: true

                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.leftMargin: 5
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: Theme.radiusMedium
                            color: root.pickerKind === "output" ? Theme.accentContainer : Theme.secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.pickerKind === "output" ? "speaker" : "mic"
                                size: 21
                                color: root.pickerKind === "output" ? Theme.accent : Theme.secondary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: root.pickerKind === "output" ? "Choose output" : "Choose microphone"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }

                            Text {
                                text: root.pickerDevices.length + " available"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }
                        }

                        IconButton {
                            size: 38
                            icon: "close"
                            accessibleName: "Close device picker"
                            onClicked: root.pickerKind = ""
                        }
                    }

                    ListView {
                        id: audioDeviceList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.pickerDevices
                        spacing: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: ConnectionRow {
                            required property var modelData

                            width: audioDeviceList.width
                            implicitHeight: 68
                            icon: root.deviceIcon(modelData)
                            title: modelData.description || modelData.nickname || modelData.name
                            subtitle: modelData.nickname || modelData.name
                            trailing: active ? "Current" : "Use"
                            active: root.pickerKind === "output"
                                ? modelData === AudioService.sink
                                : modelData === AudioService.source
                            actionIcon: active ? "check" : "arrow_forward"
                            accentColor: root.pickerKind === "output" ? Theme.accent : Theme.secondary
                            containerColor: active
                                ? (root.pickerKind === "output" ? Theme.accentContainer : Theme.secondaryContainer)
                                : Theme.surface
                            onClicked: {
                                if (root.pickerKind === "output")
                                    AudioService.selectOutput(modelData)
                                else
                                    AudioService.selectInput(modelData)
                                root.pickerKind = ""
                            }
                            onActionClicked: clicked()
                        }
                    }
                }
            }
        }
    }
}
