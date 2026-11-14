import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// Wi-Fi and wired connections through NetworkManager (Quickshell.Networking).
ColumnLayout {
    id: page
    spacing: 24

    readonly property bool available: Networking.backend !== NetworkBackendType.None
    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.filter(d => d.type !== DeviceType.Wifi)
    readonly property var networks: wifi ? wifi.networks.values.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []

    // Network waiting for a password, and what the user typed.
    property var asking: null
    // Name of the network whose last attempt failed.
    property string failed: ""

    // Joins with a password. A saved network keeps its old (wrong) password,
    // so it is forgotten first and joined fresh a moment later.
    function join(network, password) {
        failed = ""
        if (network.known) {
            again.name = network.name
            again.password = password
            network.forget()
            again.restart()
        } else network.connectWithPsk(password)
    }
    Timer {
        id: again
        property string name: ""
        property string password: ""
        interval: 900
        onTriggered: {
            const n = page.networks.find(x => x.name === name)
            if (n) n.connectWithPsk(password)
            else page.failed = name
            password = ""
        }
    }

    // Scan only while this page is open.
    Component.onCompleted: if (wifi) wifi.scannerEnabled = true
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false
    onWifiChanged: if (wifi) wifi.scannerEnabled = true

    function bars(strength) {
        return strength > 0.75 ? "signal_wifi_4_bar" : (strength > 0.5 ? "network_wifi_3_bar"
            : (strength > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"))
    }

    // ---- NetworkManager missing --------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: !page.available
        implicitHeight: missing.implicitHeight + 48
        radius: Theme.cornerXXL
        color: Theme.tertiaryContainer

        ColumnLayout {
            id: missing
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: "NetworkManager is not running"
                font.pixelSize: Theme.textTitle + 4
                font.weight: Font.Black
                color: Theme.inkOnTertiaryContainer
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.inkOnTertiaryContainer
                opacity: 0.9
                text: "Voidline manages networks through NetworkManager. Your connection is currently handled by something else, so it is left alone. To manage it here, enable NetworkManager in a terminal:"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 44
                radius: Theme.cornerM
                color: Theme.alpha(Theme.inkOnTertiaryContainer, 0.14)
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 16
                    text: "sudo systemctl enable --now NetworkManager"
                    font.family: "monospace"
                    color: Theme.inkOnTertiaryContainer
                }
            }
        }
    }

    // Without NetworkManager: read-only facts about the connection in use.
    property var link: ({})
    Process {
        running: !page.available
        command: ["sh", "-c", "r=$(ip -4 route get 1.1.1.1 2>/dev/null | head -1); dev=$(echo \"$r\" | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p'); [ -n \"$dev\" ] || exit 0; echo \"dev=$dev\"; echo \"ip=$(echo \"$r\" | sed -n 's/.* src \\([^ ]*\\).*/\\1/p')\"; echo \"gw=$(echo \"$r\" | sed -n 's/.* via \\([^ ]*\\).*/\\1/p')\"; [ -d /sys/class/net/$dev/wireless ] && echo kind=wifi || echo kind=wired; echo \"speed=$(cat /sys/class/net/$dev/speed 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                page.link = out
            }
        }
    }
    SegGroup {
        visible: !page.available
        title: "Current connection"
        SegItem {
            icon: !page.link.dev ? "public_off" : (page.link.kind === "wifi" ? "wifi" : "lan")
            hue: 0
            lobes: 8
            title: !page.link.dev ? "Not connected" : (page.link.kind === "wifi" ? "Wi-Fi" : "Wired") + " (" + page.link.dev + ")"
            description: !page.link.dev ? "No route to the internet was found."
                : "Connected" + (parseInt(page.link.speed) > 0 ? "  ·  " + page.link.speed + " Mbit/s" : "")
        }
        SegItem {
            visible: !!page.link.ip
            icon: "tag"
            hue: 1
            lobes: 0
            title: "Address"
            description: (page.link.ip || "") + (page.link.gw ? "  ·  router " + page.link.gw : "")
        }
    }

    // ---- Wi-Fi ----------------------------------------------------------------------------
    SegGroup {
        visible: page.available
        title: "Wi-Fi"

        SegItem {
            icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
            hue: 0
            lobes: 8
            title: "Wi-Fi"
            description: !page.wifi ? "No Wi-Fi adapter found" : (Networking.wifiEnabled ? "On" : "Off")
            Toggle {
                checked: Networking.wifiEnabled
                onToggled: v => Networking.wifiEnabled = v
            }
        }

        Repeater {
            model: Networking.wifiEnabled ? page.networks : []

            SegItem {
                id: net
                required property var modelData
                readonly property bool open: modelData.security === WifiSecurityType.Open
                readonly property bool asking: page.asking === modelData

                icon: page.bars(modelData.signalStrength)
                hue: modelData.connected ? 0 : 2
                lobes: modelData.connected ? 8 : 0
                title: modelData.name || "Hidden network"
                readonly property bool failed: page.failed === modelData.name && !modelData.connected
                description: modelData.stateChanging ? "Connecting..."
                    : (modelData.connected ? "Connected"
                        : (failed ? "Could not connect. Check the password and try again."
                            : (modelData.known ? "Saved" : (open ? "Open" : "Secured"))))
                clickable: !modelData.connected && !asking
                onClicked: {
                    page.failed = ""
                    if (failed && !open) page.asking = modelData
                    else if (modelData.known || open) modelData.connect()
                    else page.asking = modelData
                }
                // A failed attempt (wrong password) opens the password field again.
                Connections {
                    target: net.modelData
                    ignoreUnknownSignals: true
                    function onConnectionFailed(reason) {
                        page.failed = net.modelData.name
                        if (!net.open) page.asking = net.modelData
                    }
                }

                Row {
                    spacing: 6
                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !net.open && !net.modelData.connected
                        icon: "lock"
                        size: 18
                        color: Theme.inkMuted
                    }
                    IconBtn {
                        visible: net.modelData.known && !net.modelData.connected && !net.open
                        icon: "key"
                        size: 38
                        onClicked: page.asking = net.modelData
                    }
                    IconBtn {
                        visible: net.modelData.known && !net.modelData.connected
                        icon: "delete"
                        size: 38
                        onClicked: net.modelData.forget()
                    }
                    Pressable {
                        visible: net.modelData.connected
                        width: 116
                        height: 40
                        color: Theme.surfaceContainerHighest
                        onClicked: net.modelData.disconnect()
                        Label { anchors.centerIn: parent; text: "Disconnect"; font.pixelSize: Theme.textLabel + 1; font.weight: Font.DemiBold }
                    }
                }

                extra: RowLayout {
                    Layout.fillWidth: true
                    visible: net.asking
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Theme.cornerM
                        color: Theme.surfaceContainerHighest
                        border.width: 2
                        border.color: Theme.primary
                        TextInput {
                            id: psk
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.ink
                            font.family: Theme.font
                            font.pixelSize: Theme.textBody
                            clip: true
                            focus: net.asking
                            onVisibleChanged: if (visible) forceActiveFocus()
                            Keys.onEscapePressed: page.asking = null
                            onAccepted: join.clicked(null)
                            Label {
                                visible: psk.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                color: Theme.inkMuted
                            }
                        }
                    }
                    Pressable {
                        implicitWidth: 92
                        implicitHeight: 48
                        color: Theme.surfaceContainerHighest
                        onClicked: page.asking = null
                        Label { anchors.centerIn: parent; text: "Cancel"; font.weight: Font.DemiBold }
                    }
                    Pressable {
                        id: join
                        implicitWidth: 92
                        implicitHeight: 48
                        enabledInput: psk.text.length >= 8
                        opacity: enabledInput ? 1 : 0.5
                        color: Theme.primary
                        tint: Theme.inkOnPrimary
                        onClicked: {
                            page.join(net.modelData, psk.text)
                            psk.text = ""
                            page.asking = null
                        }
                        Label { anchors.centerIn: parent; text: "Join"; font.weight: Font.Bold; color: Theme.inkOnPrimary }
                    }
                }
            }
        }
    }

    // ---- wired ------------------------------------------------------------------------------
    SegGroup {
        visible: page.available && page.wired.length > 0
        title: "Wired"
        Repeater {
            model: page.wired
            SegItem {
                required property var modelData
                icon: "lan"
                hue: 4
                lobes: 4
                title: modelData.name
                description: modelData.connected ? "Connected" : "Not connected"
            }
        }
    }

    // ---- hotspot and VPN, through nmcli -----------------------------------------------
    property var vpns: []           // [{ name, active }]
    property bool hotspotOn: false
    property string hotspotName: Quickshell.env("USER") + "-hotspot"
    property string hotspotNote: ""

    function refreshExtras() { if (page.available) extras.running = true }
    onAvailableChanged: refreshExtras()
    Process {
        id: extras
        running: page.available
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE,802-11-wireless.mode", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const vpns = []
                let hot = false
                for (const line of text.split("\n")) {
                    const p = line.split(":")
                    if (p.length < 3) continue
                    if (p[1] === "vpn" || p[1] === "wireguard") vpns.push({ name: p[0], active: p[2] === "yes" })
                    if (p[0] === "Hotspot" && p[2] === "yes") hot = true
                }
                page.vpns = vpns
                page.hotspotOn = hot
            }
        }
    }
    Process {
        id: nm
        stderr: StdioCollector { id: nmErrors }
        onExited: code => {
            page.hotspotNote = code === 0 ? "" : (nmErrors.text.trim().split("\n").pop() || "That did not work.")
            page.refreshExtras()
        }
    }
    function nmcli(args) { hotspotNote = ""; nm.command = ["nmcli"].concat(args); nm.running = true }

    SegGroup {
        visible: page.available && !!page.wifi
        title: "Hotspot"
        SegItem {
            icon: "wifi_tethering"
            hue: 3
            lobes: 5
            title: "Share this connection"
            description: page.hotspotNote.length > 0 ? page.hotspotNote
                : (page.hotspotOn ? "Other devices can join “" + page.hotspotName + "”." : "Turns this computer's Wi-Fi into a network others can join. Wi-Fi itself disconnects while it is on.")
            Toggle {
                checked: page.hotspotOn
                onToggled: v => {
                    if (!v) page.nmcli(["connection", "down", "Hotspot"])
                    else if (hotPass.text.length >= 8) page.nmcli(["device", "wifi", "hotspot", "con-name", "Hotspot", "ssid", page.hotspotName, "password", hotPass.text])
                    else page.hotspotNote = "Choose a password of at least 8 characters first."
                }
            }
            extra: Rectangle {
                visible: !page.hotspotOn
                Layout.fillWidth: true
                implicitHeight: 48
                radius: hotPass.activeFocus ? Theme.cornerM : height / 2
                color: Theme.surfaceContainerHighest
                border.width: hotPass.activeFocus ? 2 : 0
                border.color: Theme.primary
                Behavior on radius { Spring {} }
                MIcon { id: keyIcon; x: 16; anchors.verticalCenter: parent.verticalCenter; icon: "key"; size: 20; color: Theme.inkMuted }
                TextInput {
                    id: hotPass
                    anchors.left: keyIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    color: Theme.ink
                    selectionColor: Theme.primaryContainer
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    clip: true
                    Label {
                        visible: hotPass.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password for the hotspot"
                        color: Theme.inkMuted
                    }
                }
            }
        }
    }

    SegGroup {
        visible: page.available && page.vpns.length > 0
        title: "VPN"
        Repeater {
            model: page.vpns
            SegItem {
                id: tunnel
                required property var modelData
                required property int index
                icon: "vpn_lock"
                hue: index + 4
                lobes: [8, 0, 4, 5][index % 4]
                title: modelData.name
                description: modelData.active ? "Connected" : "Off"
                Toggle {
                    checked: tunnel.modelData.active
                    onToggled: v => page.nmcli(["connection", v ? "up" : "down", "id", tunnel.modelData.name])
                }
            }
        }
    }
}
