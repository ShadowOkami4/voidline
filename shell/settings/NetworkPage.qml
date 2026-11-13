import Quickshell
import Quickshell.Networking
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
                description: modelData.stateChanging ? "Connecting..."
                    : (modelData.connected ? "Connected" : (modelData.known ? "Saved" : (open ? "Open" : "Secured")))
                clickable: !modelData.connected && !asking
                onClicked: {
                    if (modelData.known || open) modelData.connect()
                    else page.asking = modelData
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
                            net.modelData.connectWithPsk(psk.text)
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
}
