import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    property string screenName: ""
    signal openPage(string page)

    function outputIcon() {
        if (AudioService.outputMuted || AudioService.outputVolume <= 0.001)
            return "volume_off"
        if (AudioService.outputVolume < 0.35)
            return "volume_mute"
        if (AudioService.outputVolume < 0.75)
            return "volume_down"
        return "volume_up"
    }

    function brightnessIcon() {
        if (PowerService.brightnessPercent < 34)
            return "brightness_low"
        if (PowerService.brightnessPercent < 68)
            return "brightness_medium"
        return "brightness_high"
    }

    onActiveChanged: {
        PowerService.brightnessMonitoring = active
        SystemActionService.homeActive = active
        if (active)
            LauncherService.refreshToolCapabilities()
    }

    Component.onDestruction: {
        if (PowerService.brightnessMonitoring)
            PowerService.brightnessMonitoring = false
        if (SystemActionService.homeActive)
            SystemActionService.homeActive = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spaceS

        GridLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 142
            Layout.maximumHeight: 142
            columns: 2
            columnSpacing: Theme.gap
            rowSpacing: Theme.gap

            MainMenuTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 67
                icon: SystemActionService.hotspotActive ? "wifi_tethering"
                    : (ConnectivityService.ethernetConnected ? "lan"
                        : (ConnectivityService.wifiConnected ? "wifi"
                            : (ConnectivityService.wifiEnabled ? "wifi_find" : "signal_wifi_off")))
                title: I18n.tr("actionCenter.network")
                subtitle: SystemActionService.hotspotActive ? "Mobile hotspot active"
                    : ConnectivityService.activeNetworkLabel
                active: SystemActionService.hotspotActive
                    || ConnectivityService.ethernetConnected
                    || ConnectivityService.wifiConnected
                available: ConnectivityService.wifiAvailable
                    || ConnectivityService.ethernetAvailable
                onClicked: root.openPage("wifi")
            }

            MainMenuTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 67
                icon: ConnectivityService.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                title: I18n.tr("actionCenter.bluetooth")
                subtitle: ConnectivityService.connectedBluetoothDevices > 0
                    ? ConnectivityService.connectedBluetoothDevices + " connected"
                    : (ConnectivityService.bluetoothEnabled ? "Ready" : "Off")
                active: ConnectivityService.bluetoothEnabled
                available: ConnectivityService.bluetoothAvailable
                activeContainer: Theme.secondaryContainer
                activeContent: Theme.secondary
                onClicked: root.openPage("bluetooth")
            }

            MainMenuTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 67
                icon: AudioService.outputMuted ? "volume_off" : "volume_up"
                title: I18n.tr("actionCenter.sound")
                subtitle: AudioService.outputName
                active: AudioService.outputReady && !AudioService.outputMuted
                available: AudioService.outputReady
                activeContainer: Theme.tertiaryContainer
                activeContent: Theme.tertiary
                onClicked: root.openPage("sound")
            }

            MainMenuTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 67
                icon: PowerService.icon
                title: I18n.tr("actionCenter.resources")
                subtitle: PowerService.available
                    ? PowerService.percentage + "% · " + PowerService.profileMode
                    : PowerService.profileMode
                active: PowerService.charging
                activeContainer: Theme.secondaryContainer
                activeContent: Theme.secondary
                onClicked: root.openPage("power")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Layout.maximumHeight: 18

            Text {
                id: quickActionsHeading
                text: I18n.tr("actionCenter.quickActions")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Text {
                // Recorder completion messages contain the absolute output
                // path. Keep that text inside the remaining header width;
                // allowing its implicit width into RowLayout used to push the
                // complete Action Center content to the right after a save.
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: PowerService.profileError.length > 0
                    || SystemActionService.error.length > 0
                    || SystemActionService.message.length > 0
                text: PowerService.profileError.length > 0 ? PowerService.profileError
                    : (SystemActionService.error.length > 0
                        ? SystemActionService.error : SystemActionService.message)
                color: PowerService.profileError.length > 0
                    || SystemActionService.error.length > 0 ? Theme.danger : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 9
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.tileHeight * 3 + Metrics.spaceXS * 2
            Layout.maximumHeight: Metrics.tileHeight * 3 + Metrics.spaceXS * 2
            spacing: Metrics.spaceXS

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.tileHeight
                spacing: Metrics.spaceXS

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: SystemActionService.recordingStopping
                        ? I18n.tr("actionCenter.saving")
                        : (SystemActionService.recording
                            ? I18n.tr("actionCenter.stop") : I18n.tr("actionCenter.record"))
                    icon: SystemActionService.recordingStopping
                        ? "progress_activity" : (SystemActionService.recording ? "stop_circle" : "screen_record")
                    active: SystemActionService.recording
                    available: SystemActionService.recorderAvailable
                        && !SystemActionService.recordingStopping
                    onClicked: SystemActionService.toggleRecording(root.screenName)
                }

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: I18n.tr("actionCenter.screenshot")
                    icon: "screenshot_region"
                    available: LauncherService.screenshotAvailable
                    onClicked: LauncherService.takeScreenshot("region", root.screenName)
                }

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: I18n.tr("actionCenter.pickColor")
                    icon: "colorize"
                    available: LauncherService.colorPickerAvailable
                    onClicked: LauncherService.pickColor()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.tileHeight
                spacing: Metrics.spaceXS

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: I18n.tr("actionCenter.hotspot")
                    icon: "router"
                    active: SystemActionService.hotspotActive
                    available: SystemActionService.hotspotAvailable
                    activeContainer: Theme.secondaryContainer
                    activeContent: Theme.secondary
                    onClicked: root.openPage("hotspot")
                }

                PowerModeSwitch {
                    Layout.preferredWidth: 146
                    Layout.fillHeight: true
                    compact: true
                }

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: I18n.tr("actionCenter.project")
                    icon: "cast"
                    active: SystemActionService.monitorCount > 1
                    onClicked: root.openPage("project")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.tileHeight
                spacing: Metrics.spaceXS

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: I18n.tr("actionCenter.dnd")
                    icon: NotificationService.doNotDisturb
                        ? "do_not_disturb_on" : "notifications_active"
                    active: NotificationService.doNotDisturb
                    activeContainer: Theme.accentContainer
                    activeContent: Theme.accent
                    onClicked: NotificationService.setDoNotDisturb(
                        !NotificationService.doNotDisturb)
                }

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: SystemActionService.keepAwakeActive
                        ? I18n.tr("actionCenter.awake") : I18n.tr("actionCenter.keepAwake")
                    icon: SystemActionService.keepAwakeActive
                        ? "coffee" : "bedtime_off"
                    active: SystemActionService.keepAwakeActive
                    available: !SystemActionService.keepAwakeStopping
                    activeContainer: Theme.secondaryContainer
                    activeContent: Theme.secondary
                    onClicked: SystemActionService.toggleKeepAwake()
                }

                ActionChip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: I18n.tr("common.settings")
                    icon: "settings"
                    activeContainer: Theme.tertiaryContainer
                    activeContent: Theme.tertiary
                    onClicked: {
                        ShellState.closePanels()
                        ShellState.openSettings()
                    }
                }
            }
        }

        ExpressiveSlider {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.sliderHeight
            Layout.maximumHeight: Metrics.sliderHeight
            title: I18n.tr("actionCenter.masterVolume")
            subtitle: AudioService.outputName
            valueText: AudioService.outputLabel
            from: 0
            to: 1
            value: AudioService.outputVolume
            muted: AudioService.outputMuted
            icon: root.outputIcon()
            activeColor: Theme.tertiary
            leadingColor: Theme.tertiaryContainer
            leadingIconColor: Theme.tertiary
            enabled: AudioService.outputReady
            onIconClicked: AudioService.toggleOutputMute()
            onMoved: value => {
                if (AudioService.outputMuted && value > 0)
                    AudioService.toggleOutputMute()
                AudioService.setOutputVolume(value)
            }
        }

        ExpressiveSlider {
            Layout.fillWidth: true
            Layout.preferredHeight: PowerService.backlightAvailable ? Metrics.sliderHeight : 0
            Layout.maximumHeight: PowerService.backlightAvailable ? Metrics.sliderHeight : 0
            visible: PowerService.backlightAvailable
            title: I18n.tr("actionCenter.brightness")
            subtitle: I18n.tr("actionCenter.builtinDisplay")
            valueText: PowerService.brightnessPercent + "%"
            from: 0
            to: 1
            value: PowerService.brightnessPercent / 100
            muted: false
            icon: root.brightnessIcon()
            activeColor: Theme.secondary
            leadingColor: Theme.secondaryContainer
            leadingIconColor: Theme.secondary
            enabled: PowerService.backlightAvailable
            iconInteractive: false
            onMoved: value => PowerService.setBrightness(value * 100)

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Motion.panelResize; easing.type: Motion.morphCurve }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            Layout.maximumHeight: 20

            Text {
                text: I18n.tr("actionCenter.notifications")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Text {
                visible: NotificationService.count > 0
                text: NotificationService.count
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: NotificationService.count > 0
                text: I18n.tr("actionCenter.clearAll")
                color: clearHover.hovered ? Theme.accent : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold

                HoverHandler { id: clearHover }
                TapHandler { onTapped: NotificationService.clearAll() }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 112

            ColumnLayout {
                anchors.centerIn: parent
                visible: NotificationService.count === 0
                spacing: 2

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 7

                    MaterialIcon {
                        text: "notifications"
                        size: 19
                        color: Theme.secondary
                    }

                    Text {
                        text: I18n.tr("actionCenter.allQuiet")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.tr("actionCenter.caughtUp")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }
            }

            ListView {
                id: notificationList
                anchors.fill: parent
                visible: NotificationService.count > 0
                model: NotificationService.notifications
                spacing: 7
                clip: true

                delegate: DeviceRow {
                    required property var modelData

                    width: notificationList.width
                    icon: "notifications"
                    title: modelData.summary || modelData.appName
                        || I18n.tr("notifications.notification")
                    subtitle: modelData.body || modelData.appName || ""
                    trailing: I18n.tr("notifications.dismiss")
                    onClicked: NotificationService.dismiss(modelData)
                }
            }
        }
    }
}
