import Quickshell
import QtQuick
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18
    property var shellScreen
    readonly property var selectedNetwork: ConnectivityService.wifiNetworks.find(
        item => item.ssid === ConnectivityService.selectedNetworkSsid)
    readonly property int selectedStrength: selectedNetwork
        ? Number(selectedNetwork.strength) : 0
    readonly property bool detailIsWifi: root.detailValue("type") === "wifi"
    readonly property bool settingsPromptOpen: ConnectivityService.wifiPromptOpen
        && ConnectivityService.wifiPromptContext === "settings"

    Component.onCompleted: ConnectivityService.setWifiSettingsActive(true)
    Component.onDestruction: {
        ConnectivityService.setWifiSettingsActive(false)
        ConnectivityService.closeNetworkDetails()
    }

    function formatBytes(value) {
        const bytes = Number(value) || 0
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(1) + " GiB"
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MiB"
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(1) + " KiB"
        return bytes + " B"
    }

    function detailValue(key) {
        return String(ConnectivityService.networkDetails[key] || "")
    }

    function frequencyBand() {
        const frequency = Number(detailValue("frequency")) || 0
        if (frequency >= 5925)
            return "6 GHz · " + frequency + " MHz"
        if (frequency >= 4900)
            return "5 GHz · " + frequency + " MHz"
        if (frequency > 0)
            return "2.4 GHz · " + frequency + " MHz"
        return I18n.tr("common.unavailable")
    }

    function chooseNetwork(network) {
        if (!network || ConnectivityService.wifiOperationBusy)
            return
        if (Boolean(network.connected)) {
            ConnectivityService.openNetworkDetails(network.ssid,
                network.security, true)
            return
        }
        ConnectivityService.requestWifiConnection(network, "settings")
    }

    function chooseSavedNetwork(network) {
        const current = ConnectivityService.networkBySsid(network.ssid)
        if (current && current.connected) {
            ConnectivityService.openNetworkDetails(current.ssid,
                current.security, true)
            return
        }
        ConnectivityService.requestWifiConnection(current || {
            id: "saved:" + network.ssid,
            ssid: network.ssid,
            security: network.security,
            strength: current ? current.strength : 0,
            connected: false,
            known: true,
            bssid: "",
            frequency: 0,
            interfaceName: ConnectivityService.wifiInterface
        }, "settings")
    }

    SettingsSection {
        visible: ConnectivityService.networkDetailsOpen
        fullWidth: true
        title: ConnectivityService.selectedNetworkSsid
            || ConnectivityService.selectedNetworkInterface
        subtitle: root.detailValue("linkState") || (ConnectivityService.selectedNetworkSsid
            === ConnectivityService.wifiSsid
            ? I18n.tr("common.connected") : I18n.tr("network.savedNetworks"))
        icon: root.detailIsWifi ? "wifi" : "lan"

        SettingsAction {
            width: parent.width
            icon: "arrow_back"
            title: I18n.tr("network.details.back")
            subtitle: I18n.tr("network.details.backHint")
            onClicked: ConnectivityService.closeNetworkDetails()
        }
        SettingsValueRow {
            width: parent.width
            icon: "signal_wifi_statusbar_4_bar"
            title: I18n.tr("network.details.signal")
            value: root.selectedStrength > 0
                ? root.selectedStrength + "%" : I18n.tr("common.unavailable")
            visible: root.detailIsWifi
        }
        SettingsValueRow {
            width: parent.width
            icon: "enhanced_encryption"
            title: I18n.tr("network.details.security")
            value: ConnectivityService.selectedNetworkSecurity.length > 0
                ? ConnectivityService.selectedNetworkSecurity.toUpperCase()
                : I18n.tr("common.unavailable")
            visible: root.detailIsWifi
        }
        SettingsValueRow {
            width: parent.width
            icon: "cell_tower"
            title: I18n.tr("network.details.band")
            value: root.frequencyBand()
            visible: root.detailIsWifi
        }
        SettingsValueRow {
            width: parent.width
            icon: "tag"
            title: I18n.tr("network.details.channel")
            value: root.detailValue("channel") || I18n.tr("common.unavailable")
            visible: root.detailIsWifi
        }
        SettingsValueRow {
            width: parent.width
            icon: "speed"
            title: I18n.tr("network.details.linkSpeed")
            value: root.detailValue("linkSpeed") || I18n.tr("common.unavailable")
        }
    }

    SettingsSection {
        visible: ConnectivityService.networkDetailsOpen
        title: I18n.tr("network.details.addresses")
        subtitle: I18n.tr("network.details.addressesHint")
        icon: "lan"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        Repeater {
            model: [
                { key: "ipv4", label: I18n.tr("network.details.ipv4"), icon: "looks_4" },
                { key: "ipv6", label: I18n.tr("network.details.ipv6"), icon: "looks_6" },
                { key: "gateway", label: I18n.tr("network.details.gateway"), icon: "router" },
                { key: "dns", label: I18n.tr("network.details.dns"), icon: "dns" },
                { key: "mac", label: I18n.tr("network.details.mac"), icon: "fingerprint" },
                { key: "interface", label: I18n.tr("network.details.interface"), icon: "settings_ethernet" }
            ]
            SettingsValueRow {
                required property var modelData
                width: parent.width
                icon: modelData.icon
                title: modelData.label
                value: root.detailValue(modelData.key)
                    || I18n.tr("common.unavailable")
            }
        }
    }

    SettingsSection {
        visible: ConnectivityService.networkDetailsOpen
        title: I18n.tr("network.details.usage")
        subtitle: I18n.tr("network.details.usageHint")
        icon: "data_usage"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsValueRow {
            width: parent.width
            icon: "download"
            title: I18n.tr("network.details.received")
            value: root.formatBytes(root.detailValue("rxBytes"))
        }
        SettingsValueRow {
            width: parent.width
            icon: "upload"
            title: I18n.tr("network.details.sent")
            value: root.formatBytes(root.detailValue("txBytes"))
        }
        SettingsToggle {
            width: parent.width
            icon: "autorenew"
            title: I18n.tr("network.details.autoConnect")
            subtitle: I18n.tr("network.details.iwdManaged")
            checked: true
            enabled: false
            visible: root.detailIsWifi
        }
        SettingsToggle {
            width: parent.width
            icon: "data_saver_on"
            title: I18n.tr("network.details.metered")
            subtitle: I18n.tr("network.details.meteredUnavailable")
            checked: false
            enabled: false
            visible: root.detailIsWifi
        }
    }

    SettingsSection {
        visible: ConnectivityService.networkDetailsOpen && root.detailIsWifi
        title: I18n.tr("network.details.credentials")
        subtitle: I18n.tr("network.details.credentialsHint")
        icon: "password"

        SettingsAction {
            width: parent.width
            icon: ConnectivityService.networkSecretVisible
                ? "visibility_off" : "visibility"
            title: ConnectivityService.networkSecretVisible
                ? I18n.tr("network.details.hidePassphrase")
                : I18n.tr("network.details.revealPassphrase")
            subtitle: ConnectivityService.networkSecretHelperAvailable
                ? I18n.tr("network.details.polkitRequired")
                : I18n.tr("network.details.helperRequired")
            enabled: ConnectivityService.selectedNetworkKnown
                && ConnectivityService.networkSecretHelperAvailable
            onClicked: {
                if (ConnectivityService.networkSecretVisible)
                    ConnectivityService.hideNetworkSecret()
                else
                    ConnectivityService.revealNetworkSecret()
            }
        }
        SettingsValueRow {
            width: parent.width
            visible: ConnectivityService.networkSecretVisible
            icon: "key"
            title: I18n.tr("network.details.passphrase")
            value: ConnectivityService.networkSecret
            iconColor: Theme.accent
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.networkSecretVisible
            icon: "qr_code_2"
            title: I18n.tr("network.details.generateQr")
            subtitle: I18n.tr("network.details.generateQrHint")
            enabled: ConnectivityService.networkQrAvailable
            onClicked: ConnectivityService.generateNetworkQr()
        }

        Image {
            width: Math.min(parent.width - Metrics.spaceXL, 300)
            height: visible ? width : 0
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ConnectivityService.networkQrPath.length > 0
            source: visible ? "file://" + ConnectivityService.networkQrPath : ""
            fillMode: Image.PreserveAspectFit
            cache: false
        }

        SettingsAction {
            width: parent.width
            visible: ConnectivityService.networkQrPath.length > 0
            icon: "content_copy"
            title: I18n.tr("network.details.copyQr")
            subtitle: I18n.tr("network.details.copyQrHint")
            onClicked: ConnectivityService.copyNetworkQrData()
        }
        SettingsAction {
            width: parent.width
            visible: ConnectivityService.networkQrPath.length > 0
            icon: "save"
            title: I18n.tr("network.details.saveQr")
            subtitle: ConnectivityService.networkQrSavedPath.length > 0
                ? ConnectivityService.networkQrSavedPath
                : I18n.tr("network.details.saveQrHint")
            onClicked: ConnectivityService.saveNetworkQr()
        }
    }

    SettingsSection {
        visible: ConnectivityService.networkDetailsOpen
        title: I18n.tr("network.details.actions")
        subtitle: I18n.tr("network.details.actionsHint")
        icon: "build"

        SettingsAction {
            width: parent.width
            icon: "link_off"
            title: I18n.tr("network.disconnect")
            enabled: ConnectivityService.selectedNetworkSsid
                === ConnectivityService.wifiSsid
            onClicked: ConnectivityService.disconnectWifi()
            visible: root.detailIsWifi
        }
        SettingsAction {
            width: parent.width
            icon: "delete_outline"
            title: I18n.tr("network.forget")
            subtitle: ConnectivityService.selectedNetworkSsid
            enabled: ConnectivityService.selectedNetworkKnown
            onClicked: {
                ConnectivityService.forgetWifi(
                    ConnectivityService.selectedNetworkSsid)
                ConnectivityService.closeNetworkDetails()
            }
            visible: root.detailIsWifi
        }
        SettingsAction {
            width: parent.width
            icon: "edit"
            title: I18n.tr("network.details.edit")
            subtitle: I18n.tr("network.details.editUnavailable")
            enabled: false
            visible: root.detailIsWifi
        }
        SettingsAction {
            width: parent.width
            icon: "refresh"
            title: I18n.tr("common.refresh")
            subtitle: I18n.tr("network.details.refreshHint")
            onClicked: ConnectivityService.refreshNetworkDetails()
        }
        Text {
            width: parent.width - Metrics.spaceXL
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ConnectivityService.networkDetailsError.length > 0
            text: ConnectivityService.networkDetailsError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.textSupporting
            wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        visible: !ConnectivityService.networkDetailsOpen
        fullWidth: true
        title: I18n.tr("network.title")
        subtitle: ConnectivityService.activeNetworkLabel
        icon: ConnectivityService.ethernetConnected ? "lan"
            : (ConnectivityService.wifiConnected ? "wifi" : "wifi_off")

        SettingsToggle {
            width: parent.width
            icon: "wifi"
            title: I18n.tr("network.wifi")
            subtitle: ConnectivityService.wifiConnected
                ? ConnectivityService.wifiLabel
                : (ConnectivityService.wifiEnabled
                    ? I18n.tr("network.ready") : I18n.tr("network.wirelessOff"))
            checked: ConnectivityService.wifiEnabled
            enabled: ConnectivityService.wifiAvailable && !ConnectivityService.wifiChanging
            onToggled: value => ConnectivityService.setWifiEnabled(value)
        }
        SettingsAction {
            width: parent.width
            icon: "lan"
            title: I18n.tr("network.ethernet")
            subtitle: ConnectivityService.ethernetAvailable
                ? ConnectivityService.ethernetInterface : I18n.tr("network.noWired")
            value: ConnectivityService.ethernetConnected
                ? I18n.tr("common.connected") : I18n.tr("common.disconnected")
            active: ConnectivityService.ethernetConnected
            enabled: ConnectivityService.ethernetAvailable
            onClicked: ConnectivityService.openNetworkDetails(
                "", "ethernet", true, ConnectivityService.ethernetInterface)
        }
        SettingsAction {
            width: parent.width
            icon: "wifi_tethering"
            title: I18n.tr("actionCenter.hotspot")
            subtitle: SystemActionService.hotspotAvailable
                ? (SystemActionService.hotspotActive
                    ? I18n.tr("network.connectedTo", { network: SystemActionService.hotspotSsid })
                    : I18n.tr("network.shareConnection"))
                : I18n.tr("network.backendUnavailable")
            value: SystemActionService.hotspotActive
                ? I18n.tr("network.active") : I18n.tr("common.off")
            active: SystemActionService.hotspotActive
            enabled: SystemActionService.hotspotAvailable
                && (SystemActionService.hotspotActive
                    || SystemActionService.hotspotProfileReady)
                && !SystemActionService.hotspotChanging
            onClicked: {
                if (SystemActionService.hotspotActive)
                    SystemActionService.stopHotspot()
                else
                    SystemActionService.startHotspot(SystemActionService.hotspotSsid,
                        SystemActionService.hotspotPassword,
                        SystemActionService.hotspotBand)
            }
        }
    }

    SettingsSection {
        visible: !ConnectivityService.networkDetailsOpen
            && root.settingsPromptOpen
        fullWidth: true
        title: ConnectivityService.wifiPromptHidden
            ? I18n.tr("network.hidden")
            : I18n.tr("network.connectTo", {
                network: ConnectivityService.wifiPromptSsid
            })
        subtitle: I18n.tr("network.connectInsideSettings")
        icon: ConnectivityService.wifiPromptHidden ? "visibility_off" : "wifi_lock"
        iconContainerColor: Theme.accentContainer
        iconColor: Theme.accent

        WifiConnectionForm {
            width: parent.width
            context: "settings"
            embedded: true
        }
    }

    SettingsSection {
        visible: !ConnectivityService.networkDetailsOpen
        fullWidth: true
        title: I18n.tr("network.nearby")
        subtitle: I18n.tr("network.subtitle")
        icon: "wifi_find"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsAction {
            width: parent.width
            icon: ConnectivityService.wifiScanning ? "progress_activity" : "refresh"
            title: I18n.tr("network.scan")
            subtitle: ConnectivityService.wifiBackendAvailable
                ? I18n.tr("network.scanHint") : I18n.tr("network.iwdNotReady")
            enabled: ConnectivityService.wifiBackendAvailable
                && !ConnectivityService.wifiOperationBusy
            onClicked: ConnectivityService.scanWifi()
        }
        Repeater {
            model: ConnectivityService.wifiNetworks
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: modelData.connected ? "wifi"
                    : (modelData.security === "open" ? "wifi" : "wifi_lock")
                title: modelData.ssid
                subtitle: modelData.connected ? I18n.tr("common.connected")
                    : (modelData.known ? I18n.tr("network.savedNetworks") : modelData.security)
                value: ConnectivityService.wifiConnecting
                    && ConnectivityService.pendingSsid === modelData.ssid
                    ? I18n.tr("network.connecting")
                    : (ConnectivityService.wifiFailedSsid === modelData.ssid
                        ? I18n.tr("common.retry") : modelData.strength + "%")
                active: modelData.connected
                enabled: !ConnectivityService.wifiOperationBusy
                onClicked: root.chooseNetwork(modelData)
            }
        }
        SettingsAction {
            width: parent.width
            icon: "visibility_off"
            title: I18n.tr("network.hidden")
            subtitle: I18n.tr("network.hiddenHint")
            enabled: ConnectivityService.wifiBackendAvailable
                && ConnectivityService.wifiEnabled
                && !ConnectivityService.wifiOperationBusy
            onClicked: ConnectivityService.requestHiddenWifi("settings")
        }
        Text {
            width: parent.width - Metrics.cardPaddingWide * 2
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: visible ? Metrics.spaceS : 0
            bottomPadding: visible ? Metrics.spaceM : 0
            visible: ConnectivityService.wifiError.length > 0
                && !root.settingsPromptOpen
            text: ConnectivityService.wifiError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.textSupporting
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        visible: !ConnectivityService.networkDetailsOpen
            && ConnectivityService.wifiSavedNetworks.length > 0
        title: I18n.tr("network.savedNetworks")
        subtitle: I18n.tr("network.savedNetworksHint")
        icon: "bookmark"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        Repeater {
            model: ConnectivityService.wifiSavedNetworks
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: "wifi_lock"
                title: modelData.ssid
                subtitle: modelData.security.toUpperCase()
                enabled: !ConnectivityService.wifiOperationBusy
                onClicked: root.chooseSavedNetwork(modelData)
            }
        }
    }

    SettingsSection {
        visible: !ConnectivityService.networkDetailsOpen
        title: I18n.tr("bluetooth.title")
        subtitle: I18n.plural("bluetooth.connectedCount",
            ConnectivityService.connectedBluetoothDevices)
        icon: "bluetooth"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsToggle {
            width: parent.width
            icon: "bluetooth"
            title: I18n.tr("bluetooth.title")
            subtitle: ConnectivityService.bluetoothAvailable
                ? I18n.tr("bluetooth.full.discoverHint")
                : I18n.tr("bluetooth.full.noAdapter")
            checked: ConnectivityService.bluetoothEnabled
            enabled: ConnectivityService.bluetoothAvailable
                && !ConnectivityService.bluetoothChanging
            onToggled: value => {
                if (value !== ConnectivityService.bluetoothEnabled)
                    ConnectivityService.toggleBluetooth()
            }
        }
        SettingsAction {
            width: parent.width
            icon: "devices"
            title: I18n.tr("bluetooth.moreSettings")
            subtitle: I18n.tr("bluetooth.moreSettingsHint")
            enabled: ConnectivityService.bluetoothAvailable
            onClicked: ShellState.openDeviceSettings("bluetooth")
        }
    }

    SettingsSection {
        visible: !ConnectivityService.networkDetailsOpen
        fullWidth: true
        title: I18n.tr("network.advanced")
        subtitle: I18n.tr("network.advancedHint")
        icon: "settings_ethernet"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsAction {
            width: parent.width
            icon: "vpn_key"
            title: I18n.tr("network.vpn")
            subtitle: SystemSettingsService.available("networkmanager")
                || SystemSettingsService.available("wireguard")
                ? I18n.tr("network.vpnHint") : I18n.tr("network.noVpn")
            value: I18n.tr("common.disconnected")
            visible: false
        }
        SettingsAction {
            width: parent.width
            icon: "dns"
            title: I18n.tr("network.dns")
            subtitle: I18n.tr("network.dnsHint")
            value: SystemSettingsService.dnsServers
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "public"
            title: I18n.tr("network.proxy")
            subtitle: I18n.tr("network.proxyNone")
            value: I18n.tr("network.automatic")
            visible: false
        }
        SettingsAction {
            width: parent.width
            icon: "bookmark"
            title: I18n.tr("network.savedNetworks")
            subtitle: I18n.tr("network.knownProfiles")
            value: String(ConnectivityService.wifiSavedNetworks.length)
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "data_usage"
            title: I18n.tr("network.dataUsage")
            subtitle: I18n.tr("network.interface",
                { interfaceName: SettingsService.trafficInterface })
            value: "↓ " + SettingsService.receivedData + "  ↑ " + SettingsService.sentData
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "troubleshoot"
            title: I18n.tr("network.troubleshoot")
            subtitle: I18n.tr("network.troubleshootHint")
            value: ConnectivityService.activeNetworkType
            interactive: false
        }
    }
}
