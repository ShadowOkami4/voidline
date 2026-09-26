import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

// Android 16 style Quick Settings shade. On wide screens it is a split
// shade: notifications on the left, Quick Settings on the right. Otherwise
// one scrolling column shows Quick Settings above notifications.
Item {
    id: root

    property bool active: false
    property string screenName: ""
    property bool split: false
    signal openPage(string page)

    readonly property int qsWidth: Math.round(460 * Metrics.scale)

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

    function networkIcon() {
        if (SystemActionService.hotspotActive)
            return "wifi_tethering"
        if (ConnectivityService.ethernetConnected)
            return "lan"
        if (ConnectivityService.wifiConnected)
            return "wifi"
        return ConnectivityService.wifiEnabled ? "wifi_find" : "signal_wifi_off"
    }

    function powerModeLabel(mode) {
        if (mode === "saver")
            return I18n.tr("power.saver")
        if (mode === "performance")
            return I18n.tr("power.performance")
        return I18n.tr("power.balanced")
    }

    function cyclePowerMode() {
        const order = PowerService.performanceAvailable
            ? ["saver", "balanced", "performance"] : ["saver", "balanced"]
        const index = order.indexOf(PowerService.profileMode)
        PowerService.setProfile(order[(index + 1) % order.length])
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

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---------------- layouts ----------------
    RowLayout {
        anchors.fill: parent
        visible: root.split
        spacing: Metrics.spaceXL

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.split
            sourceComponent: notificationsComponent
        }
        Loader {
            Layout.preferredWidth: root.qsWidth
            Layout.fillHeight: true
            active: root.split
            sourceComponent: quickSettingsComponent
        }
    }

    Flickable {
        anchors.fill: parent
        visible: !root.split
        contentWidth: width
        contentHeight: stackedColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: stackedColumn
            width: parent.width
            spacing: Metrics.spaceXL

            Loader {
                width: parent.width
                active: !root.split
                sourceComponent: quickSettingsComponent
            }
            Loader {
                width: parent.width
                height: item ? item.implicitHeight : 0
                active: !root.split
                sourceComponent: notificationsComponent
            }
        }
    }

    // ---------------- Quick Settings ----------------
    Component {
        id: quickSettingsComponent

        ColumnLayout {
            spacing: Metrics.spaceM

            // Header: large clock and date, then Settings / Lock / Power.
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Metrics.spaceXS
                spacing: Metrics.spaceS

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -4

                    Text {
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        color: Theme.text
                        font.family: Appearance.clockFont
                        font.pixelSize: Math.round(46 * Metrics.scale)
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: clock.date.toLocaleDateString(I18n.locale, "dddd, d MMMM")
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(14 * Metrics.scale)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                QsIconTile {
                    implicitWidth: Math.round(48 * Metrics.scale)
                    implicitHeight: implicitWidth
                    icon: "settings"
                    accessibleName: I18n.tr("common.settings")
                    onClicked: {
                        ShellState.closePanels()
                        ShellState.openSettings()
                    }
                }
                QsIconTile {
                    implicitWidth: Math.round(48 * Metrics.scale)
                    implicitHeight: implicitWidth
                    icon: "lock"
                    accessibleName: I18n.tr("actionCenter.lock")
                    onClicked: {
                        ShellState.closePanels()
                        LockService.lock()
                    }
                }
                QsIconTile {
                    implicitWidth: Math.round(48 * Metrics.scale)
                    implicitHeight: implicitWidth
                    icon: "power_settings_new"
                    accessibleName: I18n.tr("actionCenter.power")
                    active: true
                    onClicked: {
                        const screen = Quickshell.screens.find(item => item.name === root.screenName)
                        ShellState.openPowerMenu(screen)
                    }
                }
            }

            QsSlider {
                Layout.fillWidth: true
                visible: PowerService.backlightAvailable
                icon: root.brightnessIcon()
                value: PowerService.brightnessPercent / 100
                Accessible.name: I18n.tr("actionCenter.brightness")
                onMoved: value => PowerService.setBrightness(value * 100)
            }

            QsSlider {
                Layout.fillWidth: true
                icon: root.outputIcon()
                value: AudioService.outputVolume
                muted: AudioService.outputMuted
                available: AudioService.outputReady
                iconInteractive: true
                Accessible.name: I18n.tr("actionCenter.masterVolume")
                onIconClicked: AudioService.toggleOutputMute()
                onMoved: value => {
                    if (AudioService.outputMuted && value > 0)
                        AudioService.toggleOutputMute()
                    AudioService.setOutputVolume(value)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: PowerService.profileError.length > 0 ? PowerService.profileError
                    : (SystemActionService.error.length > 0
                        ? SystemActionService.error : SystemActionService.message)
                color: PowerService.profileError.length > 0
                    || SystemActionService.error.length > 0 ? Theme.danger : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(12 * Metrics.scale)
                elide: Text.ElideMiddle
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceXS
                columns: 2
                columnSpacing: Metrics.spaceS
                rowSpacing: Metrics.spaceS

                QsTile {
                    Layout.fillWidth: true
                    icon: root.networkIcon()
                    title: I18n.tr("actionCenter.internet")
                    subtitle: SystemActionService.hotspotActive
                        ? I18n.tr("actionCenter.hotspotActive")
                        : (ConnectivityService.activeNetworkLabel
                            || (ConnectivityService.wifiEnabled ? I18n.tr("common.on") : I18n.tr("common.off")))
                    active: SystemActionService.hotspotActive
                        || ConnectivityService.ethernetConnected
                        || ConnectivityService.wifiConnected
                    available: ConnectivityService.wifiAvailable
                        || ConnectivityService.ethernetAvailable
                    hasDetails: true
                    onToggled: ConnectivityService.setWifiEnabled(!ConnectivityService.wifiEnabled)
                    onOpened: root.openPage("wifi")
                }

                QsTile {
                    Layout.fillWidth: true
                    icon: ConnectivityService.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                    title: I18n.tr("actionCenter.bluetooth")
                    subtitle: ConnectivityService.connectedBluetoothDevices > 0
                        ? I18n.tr("actionCenter.devicesConnected",
                            { count: ConnectivityService.connectedBluetoothDevices })
                        : (ConnectivityService.bluetoothEnabled
                            ? I18n.tr("actionCenter.ready") : I18n.tr("common.off"))
                    active: ConnectivityService.bluetoothEnabled
                    available: ConnectivityService.bluetoothAvailable
                    hasDetails: true
                    onToggled: ConnectivityService.toggleBluetooth()
                    onOpened: root.openPage("bluetooth")
                }

                QsTile {
                    Layout.fillWidth: true
                    icon: AudioService.outputMuted ? "volume_off" : "volume_up"
                    title: I18n.tr("actionCenter.sound")
                    subtitle: AudioService.outputName
                    active: AudioService.outputReady && !AudioService.outputMuted
                    available: AudioService.outputReady
                    hasDetails: true
                    onToggled: AudioService.toggleOutputMute()
                    onOpened: root.openPage("sound")
                }

                QsTile {
                    Layout.fillWidth: true
                    icon: NotificationService.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                    title: I18n.tr("actionCenter.dnd")
                    subtitle: NotificationService.doNotDisturb ? I18n.tr("common.on") : I18n.tr("common.off")
                    active: NotificationService.doNotDisturb
                    onToggled: NotificationService.setDoNotDisturb(!NotificationService.doNotDisturb)
                }

                QsTile {
                    Layout.fillWidth: true
                    icon: Theme.darkMode ? "dark_mode" : "light_mode"
                    title: I18n.tr("actionCenter.darkTheme")
                    subtitle: Theme.darkMode ? I18n.tr("common.on") : I18n.tr("common.off")
                    active: Theme.darkMode
                    onToggled: Appearance.setColorMode(Theme.darkMode ? "light" : "dark")
                }

                QsTile {
                    Layout.fillWidth: true
                    icon: PowerService.profileMode === "performance" ? "bolt"
                        : (PowerService.profileMode === "saver" ? "eco" : "balance")
                    title: I18n.tr("actionCenter.powerMode")
                    subtitle: PowerService.available
                        ? PowerService.percentage + "% · " + root.powerModeLabel(PowerService.profileMode)
                        : root.powerModeLabel(PowerService.profileMode)
                    active: PowerService.profileMode !== "balanced"
                    available: !PowerService.profileChanging
                    hasDetails: true
                    onToggled: root.cyclePowerMode()
                    onOpened: root.openPage("power")
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 5
                columnSpacing: Metrics.spaceS
                rowSpacing: Metrics.spaceS

                QsIconTile {
                    Layout.fillWidth: true
                    icon: "screenshot_region"
                    accessibleName: I18n.tr("actionCenter.screenshot")
                    available: LauncherService.screenshotAvailable
                    onClicked: LauncherService.takeScreenshot("region", root.screenName)
                }
                QsIconTile {
                    Layout.fillWidth: true
                    icon: SystemActionService.recordingStopping ? "progress_activity"
                        : (SystemActionService.recording ? "stop_circle" : "screen_record")
                    accessibleName: SystemActionService.recording
                        ? I18n.tr("actionCenter.stop") : I18n.tr("actionCenter.record")
                    active: SystemActionService.recording
                    available: SystemActionService.recorderAvailable
                        && !SystemActionService.recordingStopping
                    onClicked: SystemActionService.toggleRecording(root.screenName)
                }
                QsIconTile {
                    Layout.fillWidth: true
                    icon: "colorize"
                    accessibleName: I18n.tr("actionCenter.pickColor")
                    available: LauncherService.colorPickerAvailable
                    onClicked: LauncherService.pickColor()
                }
                QsIconTile {
                    Layout.fillWidth: true
                    icon: "wifi_tethering"
                    accessibleName: I18n.tr("actionCenter.hotspot")
                    active: SystemActionService.hotspotActive
                    available: SystemActionService.hotspotAvailable
                    onClicked: root.openPage("hotspot")
                }
                QsIconTile {
                    Layout.fillWidth: true
                    icon: "cast"
                    accessibleName: I18n.tr("actionCenter.project")
                    active: SystemActionService.monitorCount > 1
                    onClicked: root.openPage("project")
                }
                QsIconTile {
                    Layout.fillWidth: true
                    icon: "coffee"
                    accessibleName: I18n.tr("actionCenter.keepAwake")
                    active: SystemActionService.keepAwakeActive
                    available: !SystemActionService.keepAwakeStopping
                    onClicked: SystemActionService.toggleKeepAwake()
                }
                QsIconTile {
                    Layout.fillWidth: true
                    icon: "nightlight"
                    accessibleName: I18n.tr("actionCenter.nightLight")
                    active: SystemSettingsService.nightLightEnabled
                    available: SystemSettingsService.available("nightlight")
                    onClicked: SystemSettingsService.setNightLight(!SystemSettingsService.nightLightEnabled)
                }
            }

            QsMediaCard {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceXS
                visible: MediaService.available
            }

            Item {
                Layout.fillHeight: true
                visible: root.split
            }
        }
    }

    // ---------------- Notifications ----------------
    Component {
        id: notificationsComponent

        ColumnLayout {
            spacing: Metrics.segmentGap

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Metrics.spaceS
                spacing: Metrics.spaceS

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("actionCenter.notifications")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(22 * Metrics.scale)
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                QsIconTile {
                    implicitWidth: Math.round(40 * Metrics.scale)
                    implicitHeight: implicitWidth
                    icon: NotificationService.doNotDisturb ? "notifications_paused" : "notifications"
                    accessibleName: I18n.tr("actionCenter.dnd")
                    active: NotificationService.doNotDisturb
                    onClicked: NotificationService.setDoNotDisturb(!NotificationService.doNotDisturb)
                }
            }

            // Empty state
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceXL
                visible: NotificationService.count === 0
                spacing: Metrics.spaceXS

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: Math.round(64 * Metrics.scale)
                    height: width
                    radius: width / 2
                    color: Theme.surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "notifications"
                        size: Math.round(30 * Metrics.scale)
                        color: Theme.textMuted
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Metrics.spaceS
                    text: I18n.tr("actionCenter.allQuiet")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(16 * Metrics.scale)
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.tr("actionCenter.caughtUp")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(13 * Metrics.scale)
                }
            }

            Repeater {
                model: NotificationService.notifications

                QsNotificationCard {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    notification: modelData
                    first: index === 0
                    last: index === NotificationService.count - 1
                    onDismissed: NotificationService.dismiss(modelData)
                    onActionInvoked: action => {
                        if (action)
                            action.invoke()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceM
                visible: NotificationService.count > 0

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: clearLabel.implicitWidth + Math.round(40 * Metrics.scale)
                    implicitHeight: Math.round(40 * Metrics.scale)
                    radius: clearTap.pressed ? Metrics.pressedRadius : height / 2
                    color: clearHover.hovered ? Theme.surfaceBright : Theme.surfaceContainerHighest

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: I18n.tr("actionCenter.clearAll")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(13 * Metrics.scale)
                        font.weight: Font.DemiBold
                    }
                    HoverHandler {
                        id: clearHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: clearTap
                        onTapped: NotificationService.clearAll()
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                visible: root.split
            }
        }
    }
}
