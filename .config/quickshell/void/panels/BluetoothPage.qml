import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    property var selectedDevice: null
    property string pairingAnswer: ""
    readonly property bool interactionOpen: selectedDevice !== null || ConnectivityService.bluetoothPairPromptVisible
    readonly property int requestedBodyHeight: 690
    signal back

    function deviceName(device) {
        return device ? (device.name || device.deviceName || device.address || "Bluetooth device") : "Bluetooth device"
    }

    function deviceIcon(device) {
        const iconName = device ? (device.icon || "").toLowerCase() : ""
        if (iconName.indexOf("head") >= 0 || iconName.indexOf("audio") >= 0)
            return "headphones"
        if (iconName.indexOf("mouse") >= 0 || iconName.indexOf("input") >= 0)
            return "mouse"
        if (iconName.indexOf("keyboard") >= 0)
            return "keyboard"
        if (iconName.indexOf("phone") >= 0)
            return "smartphone"
        if (iconName.indexOf("display") >= 0 || iconName.indexOf("video") >= 0)
            return "tv"
        return "devices_other"
    }

    function deviceSubtitle(device) {
        if (!device)
            return ""
        if (device.pairing)
            return "Waiting for pairing"
        if (device.connected)
            return device.batteryAvailable ? "Connected · " + Math.round(device.battery * 100) + "% battery" : "Connected"
        if (device.paired)
            return "Saved device"
        return "Available to pair"
    }

    function primaryActionLabel(device) {
        if (!device)
            return ""
        if (device.pairing)
            return "Cancel"
        if (device.connected)
            return "Disconnect"
        if (device.paired)
            return "Connect"
        return "Pair"
    }

    function runSelectedAction() {
        if (!selectedDevice)
            return
        ConnectivityService.toggleBluetoothDevice(selectedDevice)
        if (!selectedDevice.pairing && selectedDevice.paired)
            selectedDevice = null
    }

    onActiveChanged: {
        ConnectivityService.setBluetoothPageActive(active)
        if (!active) {
            selectedDevice = null
            pairingAnswer = ""
        }
    }

    Connections {
        target: ConnectivityService
        function onBluetoothEnabledChanged() {
            if (root.active)
                ConnectivityService.setBluetoothPageActive(true)
        }
        function onBluetoothPairPromptVisibleChanged() {
            if (!ConnectivityService.bluetoothPairPromptVisible)
                root.pairingAnswer = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        PanelHeader {
            Layout.fillWidth: true
            title: I18n.tr("bluetooth.title")
            subtitle: ConnectivityService.connectedBluetoothDevices > 0
                ? ConnectivityService.connectedBluetoothDevices + " connected"
                : "Accessories and nearby devices"
            showToggle: true
            toggleChecked: ConnectivityService.bluetoothEnabled
            toggleEnabled: ConnectivityService.bluetoothAvailable && !ConnectivityService.bluetoothChanging
            onBack: root.back()
            onToggled: ConnectivityService.toggleBluetooth()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            Layout.maximumHeight: 92
            radius: Theme.radiusExtraLarge
            color: ConnectivityService.bluetoothEnabled ? Theme.secondaryContainer : Theme.surfaceLow

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            RowLayout {
                anchors { fill: parent; margins: 13 }
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 58
                    radius: Theme.pillRadius
                    color: ConnectivityService.bluetoothEnabled ? Theme.secondary : Theme.surfaceHover

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: ConnectivityService.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                        size: 30
                        color: ConnectivityService.bluetoothEnabled ? Theme.accentInk : Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: ConnectivityService.bluetoothScanning
                            ? I18n.tr("bluetooth.finding")
                            : (ConnectivityService.bluetoothEnabled
                                ? I18n.tr("bluetooth.ready") : I18n.tr("bluetooth.off"))
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ConnectivityService.bluetoothEnabled
                            ? I18n.tr("bluetooth.deviceHint")
                            : I18n.tr("bluetooth.turnOnHint")
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                MaterialIcon {
                    visible: ConnectivityService.bluetoothScanning
                    text: "progress_activity"
                    size: 23
                    color: Theme.secondary

                    RotationAnimator on rotation {
                        running: ConnectivityService.bluetoothScanning
                        from: 0
                        to: 360
                        duration: Motion.spinner
                        loops: Animation.Infinite
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: ConnectivityService.bluetoothEnabled

            Text {
                Layout.fillWidth: true
                text: I18n.tr("bluetooth.devices")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            Text {
                text: ConnectivityService.bluetoothScanning
                    ? I18n.tr("bluetooth.scanning") : I18n.tr("bluetooth.paused")
                color: ConnectivityService.bluetoothScanning ? Theme.secondary : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: ConnectivityService.bluetoothEnabled
            model: ConnectivityService.bluetoothDeviceList.slice(0, 5)
            spacing: 6
            clip: true

            delegate: ConnectionRow {
                required property var modelData

                width: deviceList.width
                icon: root.deviceIcon(modelData)
                title: root.deviceName(modelData)
                subtitle: root.deviceSubtitle(modelData)
                trailing: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                actionIcon: "chevron_right"
                actionAccessibleName: "Open device"
                active: modelData.connected
                busy: modelData.pairing
                accentColor: Theme.secondary
                containerColor: modelData.connected ? Theme.secondaryContainer : Theme.surfaceLow
                onClicked: root.selectedDevice = root.selectedDevice === modelData ? null : modelData
                onActionClicked: root.selectedDevice = root.selectedDevice === modelData ? null : modelData
            }
        }

        ConnectionRow {
            Layout.fillWidth: true
            icon: "settings"
            title: I18n.tr("bluetooth.moreSettings")
            subtitle: I18n.tr("bluetooth.moreSettingsHint")
            actionIcon: "open_in_new"
            onClicked: {
                ShellState.openSettings("bluetooth")
                ShellState.closePanels()
            }
            onActionClicked: {
                ShellState.openSettings("bluetooth")
                ShellState.closePanels()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ConnectivityService.bluetoothPairPromptVisible ? 162 : (root.selectedDevice ? 112 : 0)
            Layout.maximumHeight: Layout.preferredHeight
            visible: height > 0
            radius: Theme.radiusExtraLarge
            color: ConnectivityService.bluetoothPairPromptVisible ? Theme.tertiaryContainer : Theme.surfaceHigh
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Motion.panelResize; easing.type: Motion.morphCurve }
            }
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: ConnectivityService.bluetoothPairPromptVisible
                                ? "Pair with " + ConnectivityService.bluetoothPairDeviceName
                                : root.deviceName(root.selectedDevice)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: ConnectivityService.bluetoothPairPromptType === "confirm"
                                ? "Confirm that this code matches the device"
                                : (ConnectivityService.bluetoothPairPromptType === "pin"
                                    ? "Enter the PIN shown by the device"
                                    : (ConnectivityService.bluetoothPairPromptVisible ? "Allow this Bluetooth connection" : root.deviceSubtitle(root.selectedDevice)))
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: "close"
                        accessibleName: "Close"
                        onClicked: {
                            if (ConnectivityService.bluetoothPairPromptVisible)
                                ConnectivityService.respondBluetoothPairing(false, "")
                            else
                                root.selectedDevice = null
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    visible: ConnectivityService.bluetoothPairPromptType === "confirm"
                    radius: Theme.radiusMedium
                    color: Theme.surfaceLow

                    Text {
                        anchors.centerIn: parent
                        text: ConnectivityService.bluetoothPairPasskey
                        color: Theme.tertiary
                        font.family: Theme.fontFamily
                        font.pixelSize: 23
                        font.weight: Font.Bold
                        font.letterSpacing: 3
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    visible: ConnectivityService.bluetoothPairPromptType === "pin"
                    radius: Theme.radiusMedium
                    color: Theme.surfaceLow
                    border.width: pairingInput.activeFocus ? 2 : 1
                    border.color: pairingInput.activeFocus ? Theme.tertiary : Theme.outlineSoft

                    Text {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        visible: pairingInput.text.length === 0
                        text: "PIN or passkey"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    TextInput {
                        id: pairingInput
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.pairingAnswer
                        onTextChanged: root.pairingAnswer = text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 16
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: 7

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !ConnectivityService.bluetoothPairPromptVisible && root.selectedDevice && root.selectedDevice.paired
                        radius: Theme.radiusMedium
                        color: forgetHover.hovered ? Theme.surfaceHover : Theme.surfaceLow

                        Text {
                            anchors.centerIn: parent
                            text: "Forget"
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        HoverHandler { id: forgetHover }
                        TapHandler {
                            onTapped: {
                                ConnectivityService.forgetBluetoothDevice(root.selectedDevice)
                                root.selectedDevice = null
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusMedium
                        color: actionHover.hovered ? Theme.secondary : Theme.secondaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: ConnectivityService.bluetoothPairPromptVisible
                                ? (ConnectivityService.bluetoothPairPromptType === "pin" ? "Continue" : "Pair")
                                : root.primaryActionLabel(root.selectedDevice)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        HoverHandler { id: actionHover }
                        TapHandler {
                            onTapped: {
                                if (ConnectivityService.bluetoothPairPromptVisible)
                                    ConnectivityService.respondBluetoothPairing(true, root.pairingAnswer)
                                else
                                    root.runSelectedAction()
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: ConnectivityService.bluetoothError.length > 0
            text: ConnectivityService.bluetoothError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            visible: ConnectivityService.bluetoothEnabled && !root.interactionOpen
            text: I18n.tr("bluetooth.recentHint")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
