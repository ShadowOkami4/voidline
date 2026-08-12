import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    readonly property bool loginOpen: ConnectivityService.wifiPromptOpen
        && ConnectivityService.wifiPromptContext === "action"
    readonly property int requestedBodyHeight: 718
    signal back

    function clearSelection() {
        ConnectivityService.cancelWifiPrompt("action")
    }

    function showHiddenNetwork() {
        if (ConnectivityService.wifiOperationBusy)
            return
        ConnectivityService.requestHiddenWifi("action")
    }

    function chooseNetwork(network) {
        ConnectivityService.requestWifiConnection(network, "action")
    }

    onActiveChanged: {
        ConnectivityService.setWifiPageActive(active)
        if (!active && !ConnectivityService.wifiConnecting)
            clearSelection()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        PanelHeader {
            Layout.fillWidth: true
            title: I18n.tr("network.title")
            subtitle: ConnectivityService.ethernetConnected
                ? I18n.tr("network.wiredOn", { interfaceName: ConnectivityService.ethernetInterface })
                : (ConnectivityService.wifiConnected
                    ? I18n.tr("network.connectedTo", { network: ConnectivityService.wifiLabel })
                    : I18n.tr("network.subtitle"))
            showToggle: true
            toggleChecked: ConnectivityService.wifiEnabled
            toggleEnabled: ConnectivityService.wifiAvailable && !ConnectivityService.wifiChanging
            onBack: root.back()
            onToggled: checked => ConnectivityService.setWifiEnabled(checked)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ConnectivityService.ethernetAvailable ? 58 : 0
            Layout.maximumHeight: ConnectivityService.ethernetAvailable ? 58 : 0
            visible: ConnectivityService.ethernetAvailable
            radius: Theme.radiusLarge
            color: ConnectivityService.ethernetConnected
                ? Theme.secondaryContainer : Theme.surfaceLow

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 14
                }
                spacing: 10
                MaterialIcon {
                    text: "lan"
                    size: 22
                    color: ConnectivityService.ethernetConnected
                        ? Theme.secondary : Theme.textMuted
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("network.ethernet")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: ConnectivityService.ethernetInterface
                            + (ConnectivityService.ethernetConnected
                                ? I18n.tr("network.connectedSuffix")
                                : I18n.tr("network.cableDisconnectedSuffix"))
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
                MaterialIcon {
                    text: ConnectivityService.ethernetConnected
                        ? "check_circle" : "link_off"
                    size: 18
                    color: ConnectivityService.ethernetConnected
                        ? Theme.secondary : Theme.textMuted
                }
            }

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            Layout.maximumHeight: 92
            radius: Theme.radiusExtraLarge
            color: ConnectivityService.wifiConnected ? Theme.accentContainer : Theme.surfaceLow

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            RowLayout {
                anchors {
                    fill: parent
                    margins: 13
                }
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 58
                    radius: Theme.pillRadius
                    color: ConnectivityService.wifiConnected ? Theme.accent : Theme.surfaceHover

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: ConnectivityService.wifiEnabled ? "wifi" : "wifi_off"
                        size: 30
                        color: ConnectivityService.wifiConnected ? Theme.accentInk : Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: ConnectivityService.wifiConnected
                            ? ConnectivityService.wifiLabel
                            : (ConnectivityService.wifiEnabled
                                ? I18n.tr("network.choose") : I18n.tr("network.off"))
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ConnectivityService.wifiConnected
                            ? I18n.tr("network.internetAvailable")
                            : (ConnectivityService.wifiEnabled
                                ? I18n.tr("network.appearBelow") : I18n.tr("network.turnOnToScan"))
                        color: ConnectivityService.wifiConnected ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: ConnectivityService.wifiConnected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    visible: ConnectivityService.wifiConnected
                    icon: "info"
                    accessibleName: I18n.tr("network.details.title")
                    onClicked: {
                        const current = ConnectivityService.wifiNetworks.find(
                            item => item.connected)
                        ConnectivityService.openNetworkDetails(
                            ConnectivityService.wifiSsid,
                            current ? current.security : "", true)
                        ShellState.openSettings("connections")
                    }
                }

                IconButton {
                    visible: ConnectivityService.wifiConnected
                    icon: "link_off"
                    accessibleName: I18n.tr("network.disconnect")
                    active: true
                    onClicked: ConnectivityService.disconnectWifi()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            Layout.maximumHeight: 76
            visible: ConnectivityService.wifiBackendState === "missing" || ConnectivityService.wifiBackendState === "inactive"
            radius: Theme.radiusLarge
            color: Theme.tertiaryContainer

            RowLayout {
                anchors { fill: parent; margins: 13 }
                spacing: 11

                MaterialIcon { text: "info"; size: 24; color: Theme.tertiary }

                Text {
                    Layout.fillWidth: true
                    text: ConnectivityService.wifiBackendState === "missing"
                        ? I18n.tr("network.installIwd")
                        : I18n.tr("network.startIwd")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: ConnectivityService.wifiBackendAvailable && ConnectivityService.wifiEnabled
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: I18n.tr("network.nearby")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            IconButton {
                icon: "visibility_off"
                accessibleName: I18n.tr("network.hidden")
                enabled: !ConnectivityService.wifiConnecting
                onClicked: root.showHiddenNetwork()
            }

            IconButton {
                icon: "settings"
                accessibleName: I18n.tr("network.fullSettings")
                enabled: !ConnectivityService.wifiConnecting
                onClicked: ShellState.openSettings("connections")
            }

            Rectangle {
                Layout.preferredWidth: scanLabel.implicitWidth + 34
                Layout.preferredHeight: 30
                radius: Theme.pillRadius
                color: scanHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIcon {
                        text: ConnectivityService.wifiScanning ? "progress_activity" : "refresh"
                        size: 16
                        color: Theme.accent

                        RotationAnimator on rotation {
                            running: ConnectivityService.wifiScanning
                            from: 0
                            to: 360
                            duration: Motion.spinner
                            loops: Animation.Infinite
                        }
                    }

                    Text {
                        id: scanLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: ConnectivityService.wifiScanning
                            ? I18n.tr("network.scanning") : I18n.tr("network.scan")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }

                HoverHandler { id: scanHover }
                TapHandler {
                    enabled: !ConnectivityService.wifiScanning
                    onTapped: ConnectivityService.scanWifi()
                }
            }
        }

        ListView {
            id: networkList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: ConnectivityService.wifiBackendAvailable && ConnectivityService.wifiEnabled
            model: ConnectivityService.wifiNetworks
            spacing: 6
            clip: true

            delegate: ConnectionRow {
                required property var modelData

                width: networkList.width
                height: modelData.connected ? 0 : implicitHeight
                visible: !modelData.connected
                icon: modelData.strength >= 65 ? "signal_wifi_4_bar" : (modelData.strength >= 35 ? "network_wifi_2_bar" : "network_wifi_1_bar")
                title: modelData.ssid
                subtitle: modelData.known
                    ? I18n.tr("network.savedSecurity", { security: modelData.security.toUpperCase() })
                    : (modelData.security === "open"
                        ? I18n.tr("network.openNetwork") : modelData.security.toUpperCase())
                trailing: ConnectivityService.wifiConnecting && ConnectivityService.pendingSsid === modelData.ssid
                    ? I18n.tr("network.connecting")
                    : (ConnectivityService.wifiFailedSsid === modelData.ssid
                        ? I18n.tr("common.retry") : modelData.strength + "%")
                actionIcon: modelData.known ? "delete_outline" : "chevron_right"
                actionAccessibleName: modelData.known
                    ? I18n.tr("network.forget") : I18n.tr("network.open")
                busy: ConnectivityService.wifiConnecting && ConnectivityService.pendingSsid === modelData.ssid
                available: !ConnectivityService.wifiOperationBusy
                onClicked: root.chooseNetwork(modelData)
                onActionClicked: {
                    if (modelData.known)
                        ConnectivityService.forgetWifi(modelData.ssid)
                    else
                        root.chooseNetwork(modelData)
                }
            }
        }

        WifiConnectionForm {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            context: "action"
            compact: true
        }

        Text {
            Layout.fillWidth: true
            visible: ConnectivityService.wifiError.length > 0 && !root.loginOpen
            text: ConnectivityService.wifiError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            visible: ConnectivityService.wifiBackendAvailable && !root.loginOpen
            text: I18n.tr("network.enterpriseUnsupported")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
