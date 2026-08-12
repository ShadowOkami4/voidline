pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    // NetworkManager is preferred when it owns the adapter. The same adapter
    // transparently falls back to iwd/systemd-networkd on lightweight installs.
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiInterface: ""
    property string wifiSsid: ""
    readonly property string wifiLabel: wifiConnected ? (wifiSsid.length > 0 ? wifiSsid : wifiInterface)
        : (wifiEnabled ? I18n.tr("network.available") : I18n.tr("common.off"))
    property bool ethernetAvailable: false
    property bool ethernetConnected: false
    property string ethernetInterface: ""
    readonly property string activeNetworkType: ethernetConnected ? "ethernet"
        : (wifiConnected ? "wifi" : "disconnected")
    readonly property string activeNetworkLabel: ethernetConnected
        ? I18n.tr("network.ethernetInterface", { interfaceName: ethernetInterface })
        : (wifiConnected ? wifiLabel : I18n.tr("common.disconnected"))
    property bool wifiPageActive: false
    property bool wifiSettingsActive: false
    property string wifiBackendState: "checking"
    property string wifiBackendName: ""
    readonly property bool wifiBackendAvailable: wifiBackendState === "ready"
    property bool wifiScanning: false
    property bool wifiConnecting: false
    property bool wifiRefreshPending: false
    property string wifiOperationState: "idle"
    readonly property bool wifiChanging: wifiToggle.running
    property string wifiError: ""
    property var queuedWifiEnabled: null
    property string pendingSsid: ""
    property string pendingPassphrase: ""
    property string pendingSecurity: ""
    property string pendingNetworkId: ""
    property string pendingBssid: ""
    property int pendingFrequency: 0
    property string pendingInterface: ""
    property bool pendingKnownNetwork: false
    property bool pendingHiddenNetwork: false
    property bool wifiCancelRequested: false
    property bool wifiTimeoutRequested: false
    property string wifiBackendErrorCode: ""
    property string wifiFailedSsid: ""
    property string wifiPromptContext: ""
    property string wifiPromptSsid: ""
    property string wifiPromptSecurity: ""
    property int wifiPromptStrength: 0
    property bool wifiPromptKnown: false
    property bool wifiPromptHidden: false
    property string wifiPromptNetworkId: ""
    property string wifiPromptBssid: ""
    property int wifiPromptFrequency: 0
    property string wifiPromptInterface: ""
    property int wifiPromptRevision: 0
    readonly property bool wifiPromptOpen: wifiPromptContext.length > 0
    readonly property bool wifiOperationBusy: wifiScanning || wifiConnecting
        || wifiDisconnect.running || wifiForget.running
        || wifiOperationState === "forgetting"
    property var wifiNetworks: []
    property var wifiSavedNetworks: []
    property bool networkDetailsOpen: false
    property bool networkDetailsLoading: false
    property string networkDetailsError: ""
    property string selectedNetworkSsid: ""
    property string selectedNetworkSecurity: ""
    property bool selectedNetworkKnown: false
    property string selectedNetworkInterface: ""
    property var networkDetails: ({})
    property bool networkSecretHelperAvailable: false
    property bool networkQrAvailable: false
    property bool networkSecretVisible: false
    property string networkSecret: ""
    property string networkQrPath: ""
    property string networkQrData: ""
    property string networkQrSavedPath: ""

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothEnabled: bluetoothAvailable && bluetoothAdapter.enabled
    readonly property bool bluetoothBlocked: bluetoothAvailable && bluetoothAdapter.state === BluetoothAdapterState.Blocked
    readonly property var bluetoothDevices: bluetoothAvailable ? bluetoothAdapter.devices : null
    readonly property var bluetoothDeviceList: {
        const devices = Bluetooth.devices.values.slice()
        devices.sort((left, right) => {
            const leftRank = left.connected ? 0 : (left.paired ? 1 : 2)
            const rightRank = right.connected ? 0 : (right.paired ? 1 : 2)
            if (leftRank !== rightRank)
                return leftRank - rightRank
            return String(left.name || left.deviceName || left.address)
                .localeCompare(String(right.name || right.deviceName || right.address))
        })
        return devices
    }
    readonly property bool bluetoothScanning: bluetoothAvailable && bluetoothAdapter.discovering
    property int bluetoothDiscoverySeconds: 0
    property bool bluetoothPageActive: false
    property bool bluetoothDiscoveryOwned: false
    property string bluetoothError: ""
    property var pendingBluetoothDevice: null
    property string bluetoothPairPromptType: ""
    property string bluetoothPairPasskey: ""
    property bool bluetoothAgentReady: false
    property int bluetoothPairWaitAttempts: 0
    property int bluetoothAgentObservedLength: 0
    property string bluetoothAgentTail: ""
    readonly property bool bluetoothPairPromptVisible: bluetoothPairPromptType.length > 0
    readonly property string bluetoothPairDeviceName: pendingBluetoothDevice
        ? (pendingBluetoothDevice.name || pendingBluetoothDevice.deviceName || pendingBluetoothDevice.address)
        : "Bluetooth device"
    readonly property bool bluetoothChanging: bluetoothUnblock.running || bluetoothEnableDelay.running
    readonly property int connectedBluetoothDevices: {
        const devices = Bluetooth.devices.values
        let count = 0
        for (let index = 0; index < devices.length; ++index) {
            if (devices[index].connected)
                ++count
        }
        return count
    }

    function refreshWifi() {
        if (!rfkillQuery.running)
            rfkillQuery.running = true
        if (!networkQuery.running)
            networkQuery.running = true
    }

    function toggleWifi() {
        return setWifiEnabled(!wifiEnabled)
    }

    function setWifiEnabled(enabled) {
        const requested = Boolean(enabled)
        if (!wifiAvailable)
            return false
        if (wifiToggle.running) {
            queuedWifiEnabled = requested
            return true
        }

        queuedWifiEnabled = null
        wifiError = ""
        // Update the shared state immediately; rfkillQuery confirms the actual
        // hardware state after the operation completes.
        wifiEnabled = requested
        wifiToggle.shouldBlock = !requested
        wifiToggle.running = true
        return true
    }

    function setWifiPageActive(active) {
        wifiPageActive = active
        if (active) {
            refreshWifi()
            refreshWifiNetworks()
        }
    }

    function setWifiSettingsActive(active) {
        wifiSettingsActive = active
        if (active) {
            refreshWifi()
            refreshWifiNetworks()
        }
    }

    function refreshWifiNetworks() {
        if (wifiSnapshot.running) {
            wifiRefreshPending = true
            return
        }
        wifiRefreshPending = false
        wifiSnapshot.running = true
    }

    function scanWifi() {
        if (!wifiBackendAvailable || !wifiEnabled || wifiInterface.length === 0
                || wifiOperationBusy || wifiScan.running)
            return
        wifiError = ""
        wifiScanning = true
        wifiScan.running = true
    }

    function networkBySsid(ssid) {
        const wanted = String(ssid || "")
        for (let index = 0; index < wifiNetworks.length; ++index) {
            if (String(wifiNetworks[index].ssid) === wanted)
                return wifiNetworks[index]
        }
        return null
    }

    function networkById(networkId) {
        const wanted = String(networkId || "")
        for (let index = 0; index < wifiNetworks.length; ++index) {
            if (String(wifiNetworks[index].id) === wanted)
                return wifiNetworks[index]
        }
        return null
    }

    function requestWifiConnection(network, context) {
        if (!network || wifiOperationBusy)
            return "busy"
        const ssid = String(network.ssid || "")
        const security = String(network.security || "open")
        const known = Boolean(network.known)
        if (ssid.length === 0)
            return "invalid"
        wifiError = ""
        wifiFailedSsid = ""
        if (Boolean(network.connected))
            return "details"
        if ((security === "enterprise" && !known) || security === "wep") {
            wifiFailedSsid = ssid
            wifiOperationState = "failed"
            wifiError = security === "enterprise"
                ? I18n.tr("network.errors.enterprise")
                : I18n.tr("network.errors.unsupportedSecurity")
            return "failed"
        }
        if (known || security === "open" || security === "owe") {
            connectNetwork(network, "", context)
            return "connecting"
        }
        wifiPromptContext = String(context || "action")
        wifiPromptSsid = ssid
        wifiPromptSecurity = security
        wifiPromptStrength = Number(network.strength) || 0
        wifiPromptKnown = known
        wifiPromptHidden = false
        wifiPromptNetworkId = String(network.id || "")
        wifiPromptBssid = String(network.bssid || "")
        wifiPromptFrequency = Number(network.frequency) || 0
        wifiPromptInterface = String(network.interfaceName || wifiInterface)
        wifiOperationState = "credentials-required"
        ++wifiPromptRevision
        return "credentials"
    }

    function requestHiddenWifi(context) {
        if (wifiOperationBusy)
            return
        wifiError = ""
        wifiFailedSsid = ""
        wifiPromptContext = String(context || "action")
        wifiPromptSsid = ""
        wifiPromptSecurity = "psk"
        wifiPromptStrength = 0
        wifiPromptKnown = false
        wifiPromptHidden = true
        wifiPromptNetworkId = "hidden:" + wifiInterface
        wifiPromptBssid = ""
        wifiPromptFrequency = 0
        wifiPromptInterface = wifiInterface
        wifiOperationState = "credentials-required"
        ++wifiPromptRevision
    }

    function cancelWifiPrompt(context) {
        if (context && wifiPromptContext !== context)
            return
        if (wifiConnecting) {
            cancelWifiConnection()
            return
        }
        wifiPromptContext = ""
        wifiPromptSsid = ""
        wifiPromptSecurity = ""
        wifiPromptStrength = 0
        wifiPromptKnown = false
        wifiPromptHidden = false
        wifiPromptNetworkId = ""
        wifiPromptBssid = ""
        wifiPromptFrequency = 0
        wifiPromptInterface = ""
        if (wifiOperationState === "credentials-required"
                || wifiOperationState === "failed")
            wifiOperationState = wifiConnected ? "connected" : "idle"
        wifiError = ""
    }

    function submitWifiCredentials(ssid, security, passphrase, context) {
        if (!wifiPromptOpen || wifiPromptContext !== context || wifiOperationBusy)
            return false
        const targetSsid = String(ssid || wifiPromptSsid).trim()
        const targetSecurity = String(security || wifiPromptSecurity || "psk")
        if (targetSsid.length === 0)
            return false
        if (targetSecurity !== "open" && String(passphrase || "").length < 8)
            return false
        const network = wifiPromptHidden ? {
            id: wifiPromptNetworkId,
            ssid: targetSsid,
            security: targetSecurity,
            strength: 0,
            connected: false,
            known: false,
            bssid: "",
            frequency: 0,
            interfaceName: wifiPromptInterface || wifiInterface,
            hidden: true
        } : (networkById(wifiPromptNetworkId) || {
            id: wifiPromptNetworkId,
            ssid: targetSsid,
            security: targetSecurity,
            strength: wifiPromptStrength,
            connected: false,
            known: wifiPromptKnown,
            bssid: wifiPromptBssid,
            frequency: wifiPromptFrequency,
            interfaceName: wifiPromptInterface || wifiInterface,
            hidden: false
        })
        return connectNetwork(network, passphrase, context)
    }

    function connectNetwork(network, passphrase, context) {
        if (!network || !wifiBackendAvailable || !wifiEnabled
                || wifiInterface.length === 0 || wifiOperationBusy
                || wifiConnect.running)
            return false
        pendingNetworkId = String(network.id || "")
        pendingSsid = String(network.ssid || "")
        pendingPassphrase = String(passphrase || "")
        pendingSecurity = String(network.security || "open")
        pendingBssid = String(network.bssid || "")
        pendingFrequency = Number(network.frequency) || 0
        pendingInterface = String(network.interfaceName || wifiInterface)
        pendingKnownNetwork = Boolean(network.known)
        pendingHiddenNetwork = Boolean(network.hidden)
        wifiError = ""
        wifiBackendErrorCode = ""
        wifiFailedSsid = ""
        wifiCancelRequested = false
        wifiTimeoutRequested = false
        wifiConnecting = true
        wifiOperationState = pendingKnownNetwork ? "connecting" : "creating-profile"
        wifiConnect.running = true
        return true
    }

    function connectWifi(ssid, passphrase, security, known) {
        const network = networkBySsid(ssid) || {
            id: "saved:" + String(ssid || ""), ssid: ssid,
            security: security, known: known, hidden: false,
            bssid: "", frequency: 0, interfaceName: wifiInterface
        }
        return connectNetwork(network, passphrase, wifiPromptContext)
    }

    function connectHiddenWifi(ssid, passphrase, security) {
        return connectNetwork({
            id: "hidden:" + wifiInterface, ssid: String(ssid || "").trim(),
            security: security, known: false, hidden: true,
            bssid: "", frequency: 0, interfaceName: wifiInterface
        }, passphrase, wifiPromptContext)
    }

    function cancelWifiConnection() {
        if (!wifiConnect.running)
            return false
        wifiCancelRequested = true
        wifiTimeoutRequested = false
        pendingPassphrase = ""
        wifiConnect.signal(15)
        return true
    }

    function disconnectWifi() {
        if (!wifiBackendAvailable || wifiInterface.length === 0
                || wifiOperationBusy || wifiDisconnect.running)
            return
        wifiError = ""
        wifiConnecting = true
        pendingSsid = wifiSsid
        wifiOperationState = "disconnecting"
        wifiDisconnect.running = true
    }

    function forgetWifi(ssid) {
        if (!wifiBackendAvailable || wifiOperationBusy || wifiForget.running
                || !ssid || ssid.length === 0)
            return
        pendingForgetSsid = ssid
        wifiError = ""
        wifiOperationState = "forgetting"
        wifiForget.running = true
    }

    function openNetworkDetails(ssid, security, known, interfaceName) {
        selectedNetworkSsid = String(ssid || wifiSsid || "")
        selectedNetworkSecurity = String(security || "")
        selectedNetworkKnown = Boolean(known) || selectedNetworkSsid === wifiSsid
        selectedNetworkInterface = String(interfaceName || wifiInterface || "")
        networkDetailsOpen = true
        networkSecretVisible = false
        networkSecret = ""
        networkQrPath = ""
        networkQrData = ""
        networkQrSavedPath = ""
        refreshNetworkDetails()
    }

    function closeNetworkDetails() {
        hideNetworkSecret()
        networkDetailsOpen = false
        selectedNetworkSsid = ""
        selectedNetworkSecurity = ""
        selectedNetworkKnown = false
        selectedNetworkInterface = ""
        networkDetails = ({})
        networkDetailsError = ""
    }

    function refreshNetworkDetails() {
        if (!networkDetailsOpen || selectedNetworkInterface.length === 0
                || networkDetailsProcess.running)
            return
        networkDetailsLoading = true
        networkDetailsError = ""
        networkDetailsProcess.running = true
    }

    function revealNetworkSecret() {
        if (!networkSecretHelperAvailable || !selectedNetworkKnown
                || selectedNetworkSsid.length === 0 || networkSecretProcess.running)
            return
        networkDetailsError = ""
        networkSecretProcess.running = true
    }

    function hideNetworkSecret() {
        networkSecretVisible = false
        networkSecret = ""
        networkQrData = ""
        if (networkQrPath.length > 0) {
            Quickshell.execDetached({
                command: ["sh", Paths.shellRoot + "/scripts/wifi-qr.sh",
                    "clear", networkQrPath]
            })
        }
        networkQrPath = ""
        networkQrSavedPath = ""
    }

    function generateNetworkQr() {
        if (!networkQrAvailable || !networkSecretVisible
                || networkSecret.length === 0 || networkQrProcess.running)
            return
        networkDetailsError = ""
        networkQrProcess.running = true
    }

    function copyNetworkQrData() {
        if (networkQrData.length === 0 || qrCopyProcess.running)
            return
        qrCopyProcess.running = true
    }

    function saveNetworkQr() {
        if (networkQrPath.length === 0 || qrSaveProcess.running)
            return
        qrSaveProcess.running = true
    }

    function toggleBluetooth() {
        if (!bluetoothAvailable || bluetoothUnblock.running)
            return

        bluetoothError = ""
        if (bluetoothEnabled) {
            bluetoothAdapter.enabled = false
        } else {
            bluetoothUnblock.running = true
        }
    }

    function setBluetoothPageActive(active) {
        bluetoothPageActive = active
        if (!bluetoothAvailable)
            return
        if (!active) {
            bluetoothDiscoveryDelay.stop()
            bluetoothDiscoveryTimeout.stop()
            bluetoothDiscoverySeconds = 0
            if (bluetoothDiscoveryOwned && bluetoothAdapter.discovering)
                bluetoothAdapter.discovering = false
            bluetoothDiscoveryOwned = false
        } else if (bluetoothAdapter.enabled) {
            refreshBluetoothDiscovery()
        }
    }

    function refreshBluetoothDiscovery() {
        if (!bluetoothAvailable || !bluetoothAdapter.enabled)
            return
        bluetoothError = ""
        bluetoothDiscoverySeconds = 30
        if (!bluetoothAdapter.discovering)
            bluetoothDiscoveryDelay.restart()
        bluetoothDiscoveryTimeout.restart()
        bluetoothDiscoveryTick.restart()
    }

    function renameBluetoothDevice(device, alias) {
        if (!device || !device.paired)
            return
        device.name = String(alias || "").trim()
    }

    function setBluetoothTrusted(device, trusted) {
        if (device && device.paired)
            device.trusted = Boolean(trusted)
    }

    function setBluetoothBlocked(device, blocked) {
        if (device)
            device.blocked = Boolean(blocked)
    }

    function toggleBluetoothDevice(device) {
        if (!device)
            return

        bluetoothError = ""
        if (device.pairing) {
            device.cancelPair()
            clearBluetoothPairPrompt()
        } else if (device.connected) {
            device.disconnect()
        } else if (device.paired) {
            device.connect()
        } else {
            pairBluetoothDevice(device)
        }
    }

    function pairBluetoothDevice(device) {
        if (!device || device.pairing)
            return

        pendingBluetoothDevice = device
        bluetoothPairWaitAttempts = 0
        bluetoothError = ""
        clearBluetoothPairPrompt(false)
        if (bluetoothAgentReady) {
            device.pair()
        } else {
            bluetoothPairStartDelay.restart()
        }
    }

    function forgetBluetoothDevice(device) {
        if (!device || !device.paired)
            return
        bluetoothError = ""
        if (device.connected)
            device.disconnect()
        device.forget()
        if (pendingBluetoothDevice === device)
            pendingBluetoothDevice = null
    }

    function clearBluetoothPairPrompt(clearDevice) {
        bluetoothPairPromptType = ""
        bluetoothPairPasskey = ""
        bluetoothAgentTail = ""
        if (clearDevice === undefined || clearDevice)
            pendingBluetoothDevice = null
    }

    function respondBluetoothPairing(accepted, value) {
        if (!bluetoothAgent.running || !bluetoothPairPromptVisible)
            return

        if (!accepted) {
            bluetoothAgent.write("no\n")
        } else if (bluetoothPairPromptType === "pin") {
            const answer = (value || "").trim()
            if (answer.length === 0)
                return
            bluetoothAgent.write(answer + "\n")
        } else {
            bluetoothAgent.write("yes\n")
        }
        bluetoothPairPromptType = ""
        bluetoothPairPasskey = ""
        bluetoothAgentTail = ""
    }

    function handleBluetoothAgentOutput(output) {
        if (output.length < bluetoothAgentObservedLength)
            bluetoothAgentObservedLength = 0
        const fresh = output.substring(bluetoothAgentObservedLength)
        bluetoothAgentObservedLength = output.length
        if (fresh.length === 0)
            return

        const clean = fresh
            .replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "")
            .replace(/[\u0008\u000d]/g, "")
        bluetoothAgentTail = (bluetoothAgentTail + clean).slice(-768)

        if (bluetoothAgentTail.indexOf("Agent registered") >= 0) {
            bluetoothAgentReady = true
            bluetoothAgentTail = ""
        }

        const confirmation = bluetoothAgentTail.match(/Confirm passkey\s+([0-9]+)/i)
        if (confirmation) {
            bluetoothPairPromptType = "confirm"
            bluetoothPairPasskey = confirmation[1]
            return
        }

        if (/Authorize service/i.test(bluetoothAgentTail)) {
            bluetoothPairPromptType = "authorize"
            bluetoothPairPasskey = ""
            return
        }

        if (/Enter (PIN code|passkey)/i.test(bluetoothAgentTail)) {
            bluetoothPairPromptType = "pin"
            bluetoothPairPasskey = ""
            return
        }

        const failure = bluetoothAgentTail.match(/Failed to pair:\s*([^\n]+)/i)
        if (failure) {
            bluetoothError = failure[1].trim()
            clearBluetoothPairPrompt()
            return
        }

        if (/Pairing successful/i.test(bluetoothAgentTail)) {
            bluetoothError = ""
            bluetoothPairPromptType = ""
            bluetoothPairPasskey = ""
            bluetoothAgentTail = ""
        }
    }

    property var refreshDebounce: Timer {
        interval: 120
        onTriggered: {
            root.refreshWifi()
            root.refreshWifiNetworks()
            if (root.networkDetailsOpen)
                networkDetailsRefresh.restart()
        }
    }

    property var networkEvents: Process {
        command: ["networkctl", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => refreshDebounce.restart()
        }
    }

    // networkctl does not consistently publish NetworkManager Wi-Fi changes.
    // nmcli monitor is an event stream (not polling) and carries no secrets;
    // it only wakes the same debounced shared snapshot refresh.
    property var networkManagerEvents: Process {
        command: ["nmcli", "monitor"]
        running: root.wifiBackendName === "networkmanager"
        stdout: SplitParser {
            onRead: data => refreshDebounce.restart()
        }
    }

    property var rfkillEvents: Process {
        command: ["rfkill", "event"]
        running: true

        stdout: SplitParser {
            onRead: data => refreshDebounce.restart()
        }
    }

    property var rfkillQuery: Process {
        command: ["rfkill", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text)
                    const devices = payload.rfkilldevices || []
                    let found = false
                    let blocked = false

                    for (let i = 0; i < devices.length; ++i) {
                        const deviceBlocked = devices[i].soft === "blocked" || devices[i].hard === "blocked"
                        if (devices[i].type === "wlan") {
                            found = true
                            blocked = blocked || deviceBlocked
                        }
                    }

                    root.wifiAvailable = found
                    root.wifiEnabled = found && !blocked
                } catch (error) {
                    console.warn("Voidline: unable to parse rfkill state", error)
                }
            }
        }
    }

    property var networkQuery: Process {
        command: ["networkctl", "list", "--json=short"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text)
                    const interfaces = payload.Interfaces || []
                    root.wifiConnected = false
                    root.wifiInterface = ""
                    root.ethernetAvailable = false
                    root.ethernetConnected = false
                    root.ethernetInterface = ""

                    for (let i = 0; i < interfaces.length; ++i) {
                        const item = interfaces[i]
                        const online = item.OnlineState === "online"
                            || item.OperationalState === "routable"
                        if (item.Type === "wlan") {
                            if (root.wifiInterface.length === 0)
                                root.wifiInterface = item.Name || "Wi-Fi"
                            root.wifiConnected = root.wifiConnected || online
                        } else if (item.Type === "ether" || item.Type === "ethernet") {
                            root.ethernetAvailable = true
                            if (root.ethernetInterface.length === 0)
                                root.ethernetInterface = item.Name || "Ethernet"
                            root.ethernetConnected = root.ethernetConnected || online
                        }
                    }

                    if (root.wifiInterface.length > 0)
                        root.refreshWifiNetworks()
                } catch (error) {
                    console.warn("Voidline: unable to parse networkctl state", error)
                }
            }
        }
    }

    property var wifiToggle: Process {
        property bool shouldBlock: false
        command: ["rfkill", shouldBlock ? "block" : "unblock", "wifi"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.wifiError = I18n.tr("network.radioChangeFailed")
            root.refreshWifi()
            wifiRadioConfirm.restart()
            if (root.queuedWifiEnabled !== null) {
                const requested = root.queuedWifiEnabled
                root.queuedWifiEnabled = null
                Qt.callLater(() => root.setWifiEnabled(requested))
            }
        }
    }

    property var wifiRadioConfirm: Timer {
        interval: 800
        onTriggered: {
            root.refreshWifi()
            root.refreshWifiNetworks()
        }
    }

    property var wifiSnapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/wifi-snapshot.sh", root.wifiInterface]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n")
                const networks = []
                const groupedNetworks = ({})
                const savedNetworks = []
                let connectedSsid = ""
                for (let index = 0; index < rows.length; ++index) {
                    const fields = rows[index].split("|")
                    if (fields[0] === "backend") {
                        root.wifiBackendState = fields[1] || "missing"
                    } else if (fields[0] === "backend-name") {
                        root.wifiBackendName = fields[1] || ""
                    } else if (fields[0] === "network" && fields.length >= 6) {
                        const bssid = fields.length >= 7 ? fields[6] : ""
                        const frequency = fields.length >= 8 ? (Number(fields[7]) || 0) : 0
                        const interfaceName = fields.length >= 9
                            ? fields[8] : root.wifiInterface
                        const network = {
                            id: (interfaceName || root.wifiInterface) + ":"
                                + (bssid || fields[1]),
                            ssid: fields[1],
                            security: fields[2],
                            strength: Number(fields[3]) || 0,
                            connected: fields[4] === "1",
                            known: fields[5] === "1",
                            bssid: bssid,
                            frequency: frequency,
                            interfaceName: interfaceName
                        }
                        // One visible entry per SSID/security pair, while the
                        // selected entry retains the exact AP identity used by
                        // libnm. Prefer the connected AP, then strongest.
                        const groupKey = fields[1] + "\u0000" + fields[2]
                        const existing = groupedNetworks[groupKey]
                        if (!existing || network.connected
                                || (!existing.connected
                                    && network.strength > existing.strength))
                            groupedNetworks[groupKey] = network
                        if (fields[4] === "1")
                            connectedSsid = fields[1]
                    } else if (fields[0] === "saved" && fields.length >= 3) {
                        savedNetworks.push({
                            ssid: fields[1],
                            security: fields[2]
                        })
                    }
                }
                const groupKeys = Object.keys(groupedNetworks)
                for (let index = 0; index < groupKeys.length; ++index)
                    networks.push(groupedNetworks[groupKeys[index]])
                networks.sort((left, right) => {
                    if (left.connected !== right.connected)
                        return left.connected ? -1 : 1
                    return right.strength - left.strength
                })
                root.wifiNetworks = networks
                root.wifiSavedNetworks = savedNetworks
                if (root.wifiBackendAvailable) {
                    root.wifiSsid = connectedSsid
                    root.wifiConnected = connectedSsid.length > 0
                    if (root.wifiConnected && (root.wifiOperationState === "connecting"
                            || root.wifiOperationState === "authenticating"
                            || root.wifiOperationState === "creating-profile"
                            || (!wifiConnect.running
                                && (root.wifiOperationState === "idle"
                                    || root.wifiOperationState === "disconnected"))))
                        root.wifiOperationState = "connected"
                    else if (!root.wifiConnected && !wifiConnect.running
                            && root.wifiOperationState === "connected")
                        root.wifiOperationState = "disconnected"
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.wifiRefreshPending) {
                root.wifiRefreshPending = false
                wifiSnapshotRestart.restart()
            }
        }
    }

    property var wifiSnapshotRestart: Timer {
        interval: 80
        onTriggered: root.refreshWifiNetworks()
    }

    property var wifiScan: Process {
        command: ["sh", Paths.shellRoot + "/scripts/network-control.sh",
            "scan", root.wifiInterface]
        onExited: (exitCode, exitStatus) => {
            root.wifiScanning = false
            if (exitCode !== 0 && exitCode !== 75) {
                root.wifiError = I18n.tr("network.errors.scan")
                root.wifiOperationState = "failed"
            }
            wifiSharedStateFile.reload()
            wifiScanRefreshDelay.restart()
        }
    }

    property var wifiScanRefreshDelay: Timer {
        interval: 650
        onTriggered: root.refreshWifiNetworks()
    }

    property var wifiConnect: Process {
        command: root.wifiBackendName === "networkmanager"
            ? [Paths.networkBackend, "connect",
                "--interface", root.pendingInterface || root.wifiInterface,
                "--ssid", root.pendingSsid,
                "--security", root.pendingSecurity]
                .concat(root.pendingBssid.length > 0
                    ? ["--bssid", root.pendingBssid] : [])
                .concat(root.pendingHiddenNetwork ? ["--hidden"] : [])
            : ["sh", Paths.shellRoot + "/scripts/network-control.sh",
                "connect", root.wifiInterface, root.pendingSsid,
                root.pendingSecurity, root.pendingHiddenNetwork ? "1" : "0",
                root.pendingKnownNetwork ? "1" : "0"]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handleWifiBackendLine(String(line || "").trim())
        }

        onStarted: {
            wifiConnectTimeout.restart()
            // The credential travels only through this private pipe. Close it
            // immediately and clear the QML copy before NetworkManager starts.
            write(root.pendingPassphrase + "\n")
            closeWriteChannel()
            root.pendingPassphrase = ""
        }

        onExited: (exitCode, exitStatus) => {
            wifiConnectTimeout.stop()
            root.wifiConnecting = false
            root.pendingPassphrase = ""
            const completedSsid = root.pendingSsid
            const completedSecurity = root.pendingSecurity
            const completedInterface = root.pendingInterface
            const completedContext = root.wifiPromptContext
            if (root.wifiTimeoutRequested) {
                root.wifiOperationState = "failed"
                root.wifiFailedSsid = completedSsid
                root.wifiBackendErrorCode = "authentication-timeout"
                root.wifiError = root.sharedNetworkError(root.wifiBackendErrorCode)
                if (root.wifiPromptOpen)
                    ++root.wifiPromptRevision
            } else if (root.wifiCancelRequested || exitCode === 130) {
                root.wifiOperationState = root.wifiConnected ? "connected" : "idle"
                root.wifiError = ""
                root.wifiFailedSsid = ""
                if (root.wifiPromptOpen)
                    root.cancelWifiPrompt(completedContext)
            } else if (exitCode === 0) {
                root.wifiOperationState = "connected"
                root.wifiError = ""
                root.wifiFailedSsid = ""
                if (root.wifiPromptSsid === root.pendingSsid
                    || root.wifiPromptHidden)
                    root.cancelWifiPrompt(root.wifiPromptContext)
                if (completedContext === "settings") {
                    Qt.callLater(() => root.openNetworkDetails(completedSsid,
                        completedSecurity, true, completedInterface))
                }
            } else {
                root.wifiFailedSsid = root.pendingSsid
                root.wifiOperationState = "failed"
                if (root.wifiError.length === 0)
                    root.wifiError = I18n.tr("network.errors.activationFailed")
                // Keep the prompt open for retry, but never retain the secret.
                if (root.wifiPromptOpen)
                    ++root.wifiPromptRevision
            }
            root.pendingNetworkId = ""
            root.pendingBssid = ""
            root.pendingFrequency = 0
            root.pendingInterface = ""
            root.pendingSecurity = ""
            root.pendingKnownNetwork = false
            root.pendingHiddenNetwork = false
            root.wifiCancelRequested = false
            root.wifiTimeoutRequested = false
            if (root.wifiBackendName !== "networkmanager")
                wifiSharedStateFile.reload()
            root.refreshWifi()
            root.refreshWifiNetworks()
        }
    }

    property var wifiConnectTimeout: Timer {
        interval: 45000
        onTriggered: {
            if (wifiConnect.running) {
                root.wifiTimeoutRequested = true
                wifiConnect.signal(15)
                root.pendingPassphrase = ""
                root.wifiConnecting = false
                root.wifiOperationState = "failed"
                root.wifiFailedSsid = root.pendingSsid
                root.wifiBackendErrorCode = "authentication-timeout"
                root.wifiError = root.sharedNetworkError(root.wifiBackendErrorCode)
            }
        }
    }

    property var wifiDisconnect: Process {
        command: ["sh", Paths.shellRoot + "/scripts/network-control.sh",
            "disconnect", root.wifiInterface, root.pendingSsid]
        onExited: (exitCode, exitStatus) => {
            root.wifiConnecting = false
            if (exitCode !== 0)
                root.wifiError = I18n.tr("network.errors.disconnect")
            root.wifiOperationState = exitCode === 0 ? "disconnected" : "failed"
            if (exitCode !== 0)
                root.wifiFailedSsid = root.pendingSsid
            wifiSharedStateFile.reload()
            root.refreshWifi()
            root.refreshWifiNetworks()
        }
    }

    property string pendingForgetSsid: ""

    property var wifiForget: Process {
        command: ["sh", Paths.shellRoot + "/scripts/network-control.sh",
            "forget", root.pendingForgetSsid]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.wifiError = I18n.tr("network.errors.forget")
            else if (root.wifiOperationState === "forgetting")
                root.wifiOperationState = root.wifiConnected ? "connected" : "idle"
            wifiSharedStateFile.reload()
            root.pendingForgetSsid = ""
            root.refreshWifiNetworks()
        }
    }

    function sharedNetworkError(code) {
        if (code === "incorrect-password" || code === "authentication")
            return I18n.tr("network.errors.incorrectPassword")
        if (code === "authentication-timeout" || code === "timeout")
            return I18n.tr("network.errors.authenticationTimeout")
        if (code === "access-point-disappeared")
            return I18n.tr("network.errors.accessPointDisappeared")
        if (code === "networkmanager-unavailable")
            return I18n.tr("network.errors.networkManagerUnavailable")
        if (code === "permission-denied")
            return I18n.tr("network.errors.permissionDenied")
        if (code === "adapter-unavailable")
            return I18n.tr("network.errors.adapterUnavailable")
        if (code === "wifi-disabled")
            return I18n.tr("network.errors.wifiDisabled")
        if (code === "profile-creation-failed")
            return I18n.tr("network.errors.profileCreationFailed")
        if (code === "unsupported-security")
            return I18n.tr("network.errors.unsupportedSecurity")
        if (code === "unsupported-enterprise" || code === "enterprise")
            return I18n.tr("network.errors.enterprise")
        if (code === "dhcp-failed")
            return I18n.tr("network.errors.dhcpFailed")
        if (code === "activation-failed")
            return I18n.tr("network.errors.activationFailed")
        if (code === "invalid-credentials")
            return I18n.tr("network.errors.invalidCredentials")
        if (code === "cancelled")
            return I18n.tr("network.errors.cancelled")
        if (code === "authenticate")
            return I18n.tr("network.errors.authenticate")
        if (code === "unavailable")
            return I18n.tr("network.errors.unavailable")
        if (code === "disconnect")
            return I18n.tr("network.errors.disconnect")
        if (code === "forget")
            return I18n.tr("network.errors.forget")
        if (code === "busy")
            return I18n.tr("network.errors.busy")
        if (code === "permission")
            return I18n.tr("network.errors.scan")
        return I18n.tr("network.errors.connection")
    }

    function handleWifiBackendLine(line) {
        if (line.length === 0)
            return
        const separator = line.indexOf("|")
        if (separator <= 0)
            return
        const kind = line.slice(0, separator)
        const value = line.slice(separator + 1)
        if (kind === "state") {
            if (["creating-profile", "authenticating", "connecting",
                    "connected"].indexOf(value) >= 0) {
                wifiOperationState = value
                wifiConnecting = value !== "connected"
            }
        } else if (kind === "error") {
            wifiBackendErrorCode = value
            wifiError = sharedNetworkError(value)
        }
    }

    function loadSharedNetworkState(payload) {
        // The direct libnm worker is authoritative during an activation. Do
        // not let the legacy state file overwrite its finer-grained states.
        if (wifiConnect.running)
            return
        const rows = String(payload || "").trim().split("\n")
        const next = ({})
        for (let index = 0; index < rows.length; ++index) {
            const separator = rows[index].indexOf("|")
            if (separator > 0)
                next[rows[index].slice(0, separator)] = rows[index].slice(separator + 1)
        }
        const state = String(next.state || "")
        const ssid = String(next.ssid || "")
        if (state.length === 0)
            return
        wifiOperationState = state
        wifiScanning = state === "scanning"
        wifiConnecting = state === "creating-profile"
            || state === "authenticating" || state === "connecting"
            || state === "disconnecting"
        if (wifiConnecting && ssid.length > 0)
            pendingSsid = ssid
        if (state === "failed") {
            wifiFailedSsid = ssid
            wifiError = sharedNetworkError(String(next.error || "connection"))
        } else if (state === "connected" || state === "disconnected"
                || state === "idle") {
            wifiFailedSsid = ""
            wifiError = ""
            if (state === "connected" && wifiPromptOpen
                    && (wifiPromptSsid === ssid || wifiPromptHidden))
                cancelWifiPrompt(wifiPromptContext)
        }
        if (state === "connected" || state === "disconnected"
                || state === "failed" || state === "idle") {
            refreshWifi()
            refreshWifiNetworks()
        }
    }

    readonly property string sharedNetworkStatePath:
        String(Quickshell.env("XDG_RUNTIME_DIR") || "")
            + "/voidline/network-state"

    property var wifiSharedStateFile: FileView {
        path: root.sharedNetworkStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: sharedNetworkStateReload.restart()
        onLoaded: root.loadSharedNetworkState(text())
    }

    property var sharedNetworkStateReload: Timer {
        interval: 45
        onTriggered: wifiSharedStateFile.reload()
    }

    property var sharedNetworkStateInit: Process {
        command: ["sh", Paths.shellRoot + "/scripts/network-control.sh", "state"]
        running: true
        onExited: (exitCode, exitStatus) => wifiSharedStateFile.reload()
    }

    property var networkDetailsRefresh: Timer {
        interval: 180
        onTriggered: root.refreshNetworkDetails()
    }

    property var networkDetailsProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/network-details.sh",
            "snapshot", root.selectedNetworkInterface, root.selectedNetworkSsid]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {}
                const rows = text.trim().length > 0 ? text.trim().split("\n") : []
                for (let index = 0; index < rows.length; ++index) {
                    const fields = rows[index].split("|")
                    if (fields[0] === "detail" && fields.length >= 3)
                        next[fields[1]] = fields.slice(2).join("|")
                    else if (fields[0] === "capability" && fields[1] === "secret-helper")
                        root.networkSecretHelperAvailable = fields[2] === "1"
                    else if (fields[0] === "capability" && fields[1] === "qrencode")
                        root.networkQrAvailable = fields[2] === "1"
                }
                root.networkDetails = next
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.networkDetailsLoading = false
            if (exitCode !== 0)
                root.networkDetailsError = I18n.tr("network.details.loadFailed")
        }
    }

    property var networkSecretProcess: Process {
        command: ["pkexec", "/usr/lib/voidline/network-secret-helper",
            "reveal", root.selectedNetworkSsid]
        stdout: StdioCollector { id: networkSecretOutput }
        stderr: StdioCollector { id: networkSecretError }
        onExited: (exitCode, exitStatus) => {
            const secret = networkSecretOutput.text.replace(/[\r\n]+$/g, "")
            if (exitCode === 0 && secret.length > 0) {
                root.networkSecret = secret
                root.networkSecretVisible = true
                root.networkDetailsError = ""
            } else {
                root.networkSecret = ""
                root.networkSecretVisible = false
                root.networkDetailsError = exitCode === 5
                    ? I18n.tr("network.details.unrecoverablePassword")
                    : I18n.tr("network.details.revealFailed")
            }
        }
    }

    property var networkQrProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/wifi-qr.sh", "generate",
            root.selectedNetworkSsid, root.selectedNetworkSecurity]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n")
                for (let index = 0; index < rows.length; ++index) {
                    const separator = rows[index].indexOf("|")
                    if (separator < 0)
                        continue
                    const key = rows[index].slice(0, separator)
                    const value = rows[index].slice(separator + 1)
                    if (key === "path")
                        root.networkQrPath = value
                    else if (key === "data")
                        root.networkQrData = value
                }
            }
        }
        onStarted: write(root.networkSecret + "\n")
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.networkDetailsError = I18n.tr("network.details.qrFailed")
        }
    }

    property var qrCopyProcess: Process {
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: write(root.networkQrData)
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.networkDetailsError = I18n.tr("network.details.copyFailed")
        }
    }

    property var qrSaveProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/wifi-qr.sh", "save",
            root.selectedNetworkSsid, root.networkQrPath]
        stdout: StdioCollector { id: qrSaveOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.networkQrSavedPath = qrSaveOutput.text.trim()
            else
                root.networkDetailsError = I18n.tr("network.details.saveFailed")
        }
    }

    property var bluetoothUnblock: Process {
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.bluetoothAvailable)
                bluetoothEnableDelay.restart()
            else
                root.bluetoothError = "Bluetooth could not be unblocked"
        }
    }

    property var bluetoothEnableDelay: Timer {
        interval: 450
        onTriggered: {
            if (root.bluetoothAvailable && !root.bluetoothAdapter.enabled)
                root.bluetoothAdapter.enabled = true
        }
    }

    property var bluetoothDiscoveryDelay: Timer {
        interval: 550
        onTriggered: {
            if (root.bluetoothPageActive && root.bluetoothAvailable
                    && root.bluetoothAdapter.enabled && !root.bluetoothAdapter.discovering) {
                root.bluetoothDiscoveryOwned = true
                root.bluetoothAdapter.discovering = true
            }
        }
    }

    property var bluetoothDiscoveryTimeout: Timer {
        interval: 30000
        onTriggered: {
            root.bluetoothDiscoverySeconds = 0
            bluetoothDiscoveryTick.stop()
            if (root.bluetoothDiscoveryOwned && root.bluetoothAvailable
                    && root.bluetoothAdapter.discovering)
                root.bluetoothAdapter.discovering = false
            root.bluetoothDiscoveryOwned = false
        }
    }

    property var bluetoothDiscoveryTick: Timer {
        interval: 1000
        repeat: true
        onTriggered: root.bluetoothDiscoverySeconds = Math.max(0,
            root.bluetoothDiscoverySeconds - 1)
    }

    onBluetoothEnabledChanged: {
        if (bluetoothEnabled && bluetoothPageActive)
            bluetoothDiscoveryDelay.restart()
    }

    property var bluetoothAgent: Process {
        command: ["bluetoothctl", "--agent", "DisplayYesNo"]
        running: root.bluetoothAvailable
            && (root.bluetoothPageActive || root.pendingBluetoothDevice !== null || root.bluetoothPairPromptVisible)
        stdinEnabled: true

        onStarted: {
            root.bluetoothAgentReady = false
            root.bluetoothAgentObservedLength = 0
            root.bluetoothAgentTail = ""
            bluetoothAgentInit.restart()
        }

        onExited: (exitCode, exitStatus) => {
            root.bluetoothAgentReady = false
            if (root.bluetoothPairPromptVisible)
                root.bluetoothError = "The Bluetooth pairing agent stopped"
            root.clearBluetoothPairPrompt()
        }

        stdout: StdioCollector {
            waitForEnd: false
            onDataChanged: root.handleBluetoothAgentOutput(text)
        }
    }

    property var bluetoothAgentInit: Timer {
        interval: 450
        onTriggered: {
            if (bluetoothAgent.running)
                bluetoothAgent.write("default-agent\n")
        }
    }

    property var bluetoothPairStartDelay: Timer {
        interval: 250
        onTriggered: {
            if (!root.pendingBluetoothDevice)
                return
            if (root.bluetoothAgentReady) {
                root.pendingBluetoothDevice.pair()
            } else if (root.bluetoothPairWaitAttempts < 8) {
                ++root.bluetoothPairWaitAttempts
                restart()
            } else {
                root.bluetoothError = "Bluetooth pairing is not ready yet"
                root.pendingBluetoothDevice = null
            }
        }
    }

    property var pendingBluetoothWatcher: Connections {
        target: root.pendingBluetoothDevice
        ignoreUnknownSignals: true

        function onPairedChanged() {
            const device = pendingBluetoothWatcher.target
            if (!device || !device.paired)
                return
            device.trusted = true
            if (!device.connected)
                device.connect()
            root.bluetoothError = ""
            root.clearBluetoothPairPrompt()
        }
    }

    Component.onCompleted: refreshWifi()
}
