import QtQuick
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18

    property var selectedDevice: null
    property string pairingAnswer: ""

    function deviceName(device) {
        return device ? (device.name || device.deviceName || device.address)
            : I18n.tr("bluetooth.device")
    }

    function deviceIcon(device) {
        const name = device ? String(device.icon || "").toLowerCase() : ""
        if (name.indexOf("head") >= 0 || name.indexOf("audio") >= 0)
            return "headphones"
        if (name.indexOf("keyboard") >= 0)
            return "keyboard"
        if (name.indexOf("mouse") >= 0 || name.indexOf("input") >= 0)
            return "mouse"
        if (name.indexOf("phone") >= 0)
            return "smartphone"
        if (name.indexOf("display") >= 0)
            return "tv"
        return "devices_other"
    }

    function subtitle(device) {
        if (device.connected)
            return device.batteryAvailable
                ? I18n.tr("bluetooth.connectedBattery", {
                    value: Math.round(device.battery * 100)
                }) : I18n.tr("common.connected")
        if (device.pairing)
            return I18n.tr("bluetooth.pairing")
        if (device.paired)
            return device.trusted ? I18n.tr("bluetooth.pairedTrusted")
                : I18n.tr("bluetooth.paired")
        return I18n.tr("bluetooth.available")
    }

    SettingsSection {
        fullWidth: true
        title: I18n.tr("bluetooth.title")
        subtitle: ConnectivityService.bluetoothAvailable
            ? I18n.tr("bluetooth.full.accessories")
            : I18n.tr("bluetooth.full.noAdapter")
        icon: "bluetooth"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsToggle {
            width: parent.width
            icon: ConnectivityService.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
            title: I18n.tr("bluetooth.full.useBluetooth")
            subtitle: ConnectivityService.bluetoothBlocked
                ? I18n.tr("bluetooth.full.rfkillBlocked")
                : (ConnectivityService.connectedBluetoothDevices > 0
                    ? I18n.plural("bluetooth.connectedCount",
                        ConnectivityService.connectedBluetoothDevices)
                    : I18n.tr("bluetooth.full.discoverHint"))
            checked: ConnectivityService.bluetoothEnabled
            enabled: ConnectivityService.bluetoothAvailable
                && !ConnectivityService.bluetoothChanging
            onToggled: ConnectivityService.toggleBluetooth()
        }
        SettingsAction {
            width: parent.width
            icon: ConnectivityService.bluetoothScanning ? "progress_activity" : "refresh"
            title: ConnectivityService.bluetoothScanning
                ? I18n.tr("bluetooth.full.findingNearby")
                : I18n.tr("bluetooth.full.scan")
            subtitle: ConnectivityService.bluetoothScanning
                ? I18n.tr("bluetooth.full.discoveryStops", {
                    seconds: ConnectivityService.bluetoothDiscoverySeconds
                }) : I18n.tr("bluetooth.full.scanHint")
            value: ConnectivityService.bluetoothScanning
                ? I18n.tr("bluetooth.scanning") : I18n.tr("common.refresh")
            enabled: ConnectivityService.bluetoothEnabled
            onClicked: ConnectivityService.refreshBluetoothDiscovery()
        }
    }

    SettingsSection {
        title: I18n.tr("bluetooth.full.connectedSection")
        subtitle: I18n.tr("bluetooth.full.connectedHint")
        icon: "link"
        iconContainerColor: Theme.accentContainer
        iconColor: Theme.accent

        Repeater {
            model: ConnectivityService.bluetoothDeviceList.filter(item => item.connected)
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: root.deviceIcon(modelData)
                title: root.deviceName(modelData)
                subtitle: root.subtitle(modelData)
                value: modelData.batteryAvailable
                    ? Math.round(modelData.battery * 100) + "%"
                    : I18n.tr("common.connected")
                active: root.selectedDevice === modelData
                onClicked: root.selectedDevice = modelData
            }
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.bluetoothDeviceList.filter(item => item.connected).length === 0
            icon: "bluetooth_searching"
            title: I18n.tr("bluetooth.full.noConnected")
            subtitle: I18n.tr("bluetooth.full.pairedBelow")
            enabled: false
        }
    }

    SettingsSection {
        title: I18n.tr("bluetooth.full.pairedSection")
        subtitle: I18n.tr("bluetooth.full.pairedHint")
        icon: "bookmark"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        Repeater {
            model: ConnectivityService.bluetoothDeviceList.filter(item => item.paired && !item.connected)
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: root.deviceIcon(modelData)
                title: root.deviceName(modelData)
                subtitle: root.subtitle(modelData)
                value: I18n.tr("bluetooth.saved")
                active: root.selectedDevice === modelData
                onClicked: root.selectedDevice = modelData
            }
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.bluetoothDeviceList.filter(item => item.paired && !item.connected).length === 0
            icon: "bookmark_border"
            title: I18n.tr("bluetooth.full.noPaired")
            subtitle: I18n.tr("bluetooth.full.savedAfterPairing")
            enabled: false
        }
    }

    SettingsSection {
        title: I18n.tr("bluetooth.full.availableSection")
        subtitle: ConnectivityService.bluetoothScanning
            ? I18n.tr("bluetooth.full.selectToPair")
            : I18n.tr("bluetooth.full.refreshToFind")
        icon: "bluetooth_searching"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        Repeater {
            model: ConnectivityService.bluetoothDeviceList.filter(item => !item.paired)
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: root.deviceIcon(modelData)
                title: root.deviceName(modelData)
                subtitle: root.subtitle(modelData)
                value: modelData.blocked ? I18n.tr("bluetooth.full.blocked")
                    : I18n.tr("bluetooth.pair")
                active: root.selectedDevice === modelData
                onClicked: root.selectedDevice = modelData
            }
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.bluetoothDeviceList.filter(item => !item.paired).length === 0
            icon: "search_off"
            title: ConnectivityService.bluetoothScanning
                ? I18n.tr("bluetooth.full.stillSearching")
                : I18n.tr("bluetooth.full.noNearby")
            subtitle: I18n.tr("bluetooth.full.pairingModeHint")
            enabled: false
        }
    }

    SettingsSection {
        fullWidth: true
        visible: root.selectedDevice !== null
            || ConnectivityService.bluetoothPairPromptVisible
        title: ConnectivityService.bluetoothPairPromptVisible
            ? I18n.tr("bluetooth.full.pairingConfirmation")
            : root.deviceName(root.selectedDevice)
        subtitle: ConnectivityService.bluetoothPairPromptVisible
            ? I18n.tr("bluetooth.full.confirmCode")
            : I18n.tr("bluetooth.full.properties")
        icon: root.deviceIcon(root.selectedDevice)

        SettingsAction {
            width: parent.width
            icon: "info"
            title: I18n.tr("bluetooth.full.details")
            subtitle: root.selectedDevice
                ? (root.selectedDevice.deviceName + " · " + root.selectedDevice.address)
                : ConnectivityService.bluetoothPairDeviceName
            value: root.selectedDevice ? root.subtitle(root.selectedDevice)
                : I18n.tr("bluetooth.pairing")
            interactive: false
        }
        SettingsField {
            width: parent.width
            visible: root.selectedDevice && root.selectedDevice.paired
            icon: "edit"
            title: I18n.tr("bluetooth.full.localName")
            subtitle: I18n.tr("bluetooth.full.localNameHint")
            value: root.selectedDevice ? root.deviceName(root.selectedDevice) : ""
            placeholder: I18n.tr("bluetooth.full.deviceName")
            onAccepted: value => ConnectivityService.renameBluetoothDevice(root.selectedDevice, value)
        }
        SettingsToggle {
            width: parent.width
            visible: root.selectedDevice && root.selectedDevice.paired
            icon: "verified_user"
            title: I18n.tr("bluetooth.full.trusted")
            subtitle: I18n.tr("bluetooth.full.trustedHint")
            checked: root.selectedDevice ? root.selectedDevice.trusted : false
            onToggled: value => ConnectivityService.setBluetoothTrusted(root.selectedDevice, value)
        }
        SettingsToggle {
            width: parent.width
            visible: root.selectedDevice !== null
            icon: "block"
            title: I18n.tr("bluetooth.full.blockDevice")
            subtitle: I18n.tr("bluetooth.full.blockHint")
            checked: root.selectedDevice ? root.selectedDevice.blocked : false
            onToggled: value => ConnectivityService.setBluetoothBlocked(root.selectedDevice, value)
        }
        SettingsField {
            width: parent.width
            visible: ConnectivityService.bluetoothPairPromptType === "pin"
            icon: "password"
            title: I18n.tr("bluetooth.full.pin")
            subtitle: I18n.tr("bluetooth.full.pinHint")
            value: root.pairingAnswer
            onAccepted: value => {
                root.pairingAnswer = value
                ConnectivityService.respondBluetoothPairing(true, value)
            }
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.bluetoothPairPromptType === "confirm"
            icon: "pin"
            title: ConnectivityService.bluetoothPairPasskey
            subtitle: I18n.tr("bluetooth.full.codeMatches")
            value: I18n.tr("common.confirm")
            onClicked: ConnectivityService.respondBluetoothPairing(true, "")
        }
        SettingsAction {
            width: parent.width
            icon: root.selectedDevice && root.selectedDevice.connected ? "link_off" : "link"
            title: root.selectedDevice && root.selectedDevice.connected
                ? I18n.tr("bluetooth.disconnect")
                : (root.selectedDevice && root.selectedDevice.paired
                    ? I18n.tr("bluetooth.connect") : I18n.tr("bluetooth.pair"))
            subtitle: I18n.tr("bluetooth.full.primaryActionHint")
            value: I18n.tr("bluetooth.full.run")
            onClicked: {
                if (root.selectedDevice)
                    ConnectivityService.toggleBluetoothDevice(root.selectedDevice)
            }
        }
        SettingsAction {
            width: parent.width
            visible: root.selectedDevice && root.selectedDevice.paired
            icon: "headphones"
            title: I18n.tr("bluetooth.full.audioProfiles")
            subtitle: I18n.tr("bluetooth.full.audioProfilesHint")
            value: I18n.tr("bluetooth.full.openAudio")
            onClicked: ShellState.openSettings("audio")
        }
        SettingsAction {
            width: parent.width
            visible: root.selectedDevice && root.selectedDevice.paired
            icon: "delete"
            title: I18n.tr("bluetooth.full.forgetDevice")
            subtitle: I18n.tr("bluetooth.full.forgetHint")
            value: I18n.tr("common.remove")
            onClicked: {
                ConnectivityService.forgetBluetoothDevice(root.selectedDevice)
                root.selectedDevice = null
            }
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.bluetoothPairPromptVisible
            icon: "close"
            title: I18n.tr("bluetooth.full.cancelPairing")
            subtitle: I18n.tr("bluetooth.full.cancelPairingHint")
            value: I18n.tr("common.cancel")
            onClicked: ConnectivityService.respondBluetoothPairing(false, "")
        }
    }

    SettingsSection {
        fullWidth: true
        visible: ConnectivityService.bluetoothError.length > 0
        title: I18n.tr("bluetooth.full.connectionProblem")
        subtitle: ConnectivityService.bluetoothError
        icon: "error"
        iconContainerColor: Theme.dangerContainer
        iconColor: Theme.danger

        SettingsAction {
            width: parent.width
            icon: "refresh"
            title: I18n.tr("bluetooth.full.retryDiscovery")
            subtitle: I18n.tr("bluetooth.full.retryHint")
            value: I18n.tr("common.retry")
            onClicked: ConnectivityService.refreshBluetoothDiscovery()
        }
    }
}
