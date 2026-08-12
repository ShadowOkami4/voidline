import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import "../components"
import "../core"
import "../services"

FocusScope {
    id: root

    property bool active: false
    property bool passwordVisible: false
    property bool profileApplied: false
    property bool qrMode: false
    property string selectedBand: "2.4"
    readonly property int requestedBodyHeight: 780
    readonly property bool settingsValid: ssidField.text.trim().length > 0
        && ssidField.text.trim().length <= 32
        && passwordField.text.length >= 8
        && passwordField.text.length <= 63
    signal back

    function applySavedProfile() {
        if (!SystemActionService.hotspotProfileLoaded || profileApplied)
            return
        ssidField.text = SystemActionService.hotspotSsid
        passwordField.text = SystemActionService.hotspotPassword
        selectedBand = SystemActionService.hotspotBand
        profileApplied = true
    }

    function persistSettings() {
        if (settingsValid)
            SystemActionService.saveHotspotProfile(ssidField.text, passwordField.text, selectedBand)
    }

    function startHotspot() {
        if (!settingsValid)
            return
        SystemActionService.startHotspot(ssidField.text, passwordField.text, selectedBand)
    }

    function showQrCode() {
        if (!settingsValid || !SystemActionService.hotspotQrAvailable)
            return
        persistSettings()
        qrMode = true
        SystemActionService.generateHotspotQr(ssidField.text, passwordField.text)
    }

    onActiveChanged: {
        SystemActionService.hotspotPageActive = active
        if (active)
            applySavedProfile()
        else
            root.focus = false
    }

    Component.onCompleted: root.applySavedProfile()
    Component.onDestruction: {
        if (SystemActionService.hotspotPageActive)
            SystemActionService.hotspotPageActive = false
    }

    Connections {
        target: SystemActionService

        function onHotspotProfileLoadedChanged() {
            root.applySavedProfile()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: root.qrMode ? "Share hotspot" : "Mobile hotspot"
            subtitle: root.qrMode
                ? ssidField.text
                : (SystemActionService.hotspotActive
                    ? SystemActionService.hotspotClientCount
                        + (SystemActionService.hotspotClientCount === 1 ? " device connected" : " devices connected")
                    : "Share this computer's connection")
            showToggle: !root.qrMode
            toggleChecked: SystemActionService.hotspotActive
            toggleEnabled: SystemActionService.hotspotAvailable && !SystemActionService.hotspotChanging
                && (SystemActionService.hotspotActive || root.settingsValid)
            onBack: {
                if (root.qrMode)
                    root.qrMode = false
                else
                    root.back()
            }
            onToggled: checked => {
                if (checked)
                    root.startHotspot()
                else
                    SystemActionService.stopHotspot()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: mainPane
                anchors.fill: parent
                spacing: 12
                enabled: !root.qrMode
                opacity: root.qrMode ? 0 : 1
                x: root.qrMode ? -28 : 0
                visible: opacity > 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    Layout.maximumHeight: 110
                    radius: Theme.radiusExtraLarge
                    color: SystemActionService.hotspotActive ? Theme.secondaryContainer : Theme.surfaceLow

                    RowLayout {
                        anchors { fill: parent; margins: 17 }
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 68
                            radius: Theme.radiusLarge
                            color: SystemActionService.hotspotActive ? Theme.secondary : Theme.surfaceHover

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: SystemActionService.hotspotChanging ? "hourglass_top" : "router"
                                size: 31
                                color: SystemActionService.hotspotActive ? Theme.accentInk : Theme.textMuted
                            }

                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: SystemActionService.hotspotActive
                                    ? ssidField.text
                                    : (SystemActionService.hotspotAvailable ? "Ready when you are" : "Hotspot unavailable")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: SystemActionService.hotspotActive
                                    ? selectedBand + " GHz · sharing " + SystemActionService.hotspotInternetInterface
                                    : (SystemActionService.hotspotProfileSaved ? "Network details saved" : "Finish the network details below")
                                color: SystemActionService.hotspotActive ? Theme.secondary : Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: SystemActionService.hotspotActive ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            visible: SystemActionService.hotspotActive
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: Theme.radiusMedium
                            color: Theme.surfaceLow

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: SystemActionService.hotspotClientCount.toString()
                                    color: Theme.secondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 19
                                    font.weight: Font.Bold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "devices"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 7
                                }
                            }
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210
                    Layout.maximumHeight: 210
                    radius: Theme.radiusExtraLarge
                    color: Theme.surface

                    ColumnLayout {
                        anchors { fill: parent; margins: 16 }
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Text {
                                Layout.fillWidth: true
                                text: "Hotspot network"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            Row {
                                visible: SystemActionService.hotspotProfileSaved
                                spacing: 4

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "lock"
                                    size: 14
                                    color: Theme.secondary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Saved"
                                    color: Theme.secondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 62
                            radius: Theme.radiusMedium
                            color: Theme.surfaceLow
                            border.width: ssidField.activeFocus ? 2 : 1
                            border.color: ssidField.activeFocus ? Theme.secondary : Theme.outlineSoft
                            opacity: SystemActionService.hotspotActive ? 0.58 : 1

                            MaterialIcon {
                                anchors { left: parent.left; leftMargin: 15; verticalCenter: parent.verticalCenter }
                                text: "wifi"
                                size: 19
                                color: Theme.textMuted
                            }

                            Column {
                                anchors { left: parent.left; leftMargin: 46; verticalCenter: parent.verticalCenter }
                                spacing: -1

                                Text {
                                    text: "Network name"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                }
                            }

                            Controls.TextField {
                                id: ssidField
                                anchors { fill: parent; leftMargin: 46; rightMargin: 14; topMargin: 13 }
                                enabled: !SystemActionService.hotspotActive && !SystemActionService.hotspotChanging
                                activeFocusOnPress: true
                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                selectionColor: Theme.secondary
                                selectedTextColor: Theme.accentInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                padding: 0
                                background: null
                                maximumLength: 32
                                onTextEdited: SystemActionService.hotspotProfileSaved = false
                                onEditingFinished: root.persistSettings()
                                onAccepted: passwordField.forceActiveFocus()
                                KeyNavigation.tab: passwordField
                            }

                            TapHandler {
                                enabled: ssidField.enabled
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: ssidField.forceActiveFocus(Qt.MouseFocusReason)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 62
                            radius: Theme.radiusMedium
                            color: Theme.surfaceLow
                            border.width: passwordField.activeFocus ? 2 : 1
                            border.color: passwordField.activeFocus ? Theme.secondary : Theme.outlineSoft
                            opacity: SystemActionService.hotspotActive ? 0.58 : 1

                            MaterialIcon {
                                anchors { left: parent.left; leftMargin: 15; verticalCenter: parent.verticalCenter }
                                text: "key"
                                size: 19
                                color: Theme.textMuted
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 46; top: parent.top; topMargin: 9 }
                                text: "Password"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 46; verticalCenter: parent.verticalCenter; verticalCenterOffset: 7 }
                                visible: passwordField.text.length === 0
                                text: "At least 8 characters"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            Controls.TextField {
                                id: passwordField
                                anchors { fill: parent; leftMargin: 46; rightMargin: 48; topMargin: 13 }
                                enabled: !SystemActionService.hotspotActive && !SystemActionService.hotspotChanging
                                activeFocusOnPress: true
                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                selectionColor: Theme.secondary
                                selectedTextColor: Theme.accentInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                padding: 0
                                background: null
                                echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText
                                maximumLength: 63
                                onTextEdited: SystemActionService.hotspotProfileSaved = false
                                onEditingFinished: root.persistSettings()
                                onAccepted: root.startHotspot()
                                KeyNavigation.backtab: ssidField
                            }

                            TapHandler {
                                enabled: passwordField.enabled
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: passwordField.forceActiveFocus(Qt.MouseFocusReason)
                            }

                            IconButton {
                                anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                                enabled: !SystemActionService.hotspotActive
                                size: 40
                                icon: root.passwordVisible ? "visibility_off" : "visibility"
                                accessibleName: "Show password"
                                onClicked: root.passwordVisible = !root.passwordVisible
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 146
                    Layout.maximumHeight: 146
                    radius: Theme.radiusLarge
                    color: Theme.surfaceLow

                    ColumnLayout {
                        anchors { fill: parent; margins: 13 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            spacing: 10

                            Text {
                                Layout.preferredWidth: 78
                                text: "Frequency"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                opacity: SystemActionService.hotspotActive ? 0.58 : 1

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: Theme.outlineSoft
                                }

                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 40
                                    y: 4
                                    x: root.selectedBand === "5" ? parent.width - width - 4 : 4
                                    radius: Theme.radiusSmall
                                    color: Theme.secondaryContainer

                                    Behavior on x {
                                        NumberAnimation { duration: Motion.selectionSlide; easing.type: Motion.morphCurve }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Repeater {
                                        model: ["2.4", "5"]

                                        delegate: Item {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData + " GHz"
                                                color: root.selectedBand === modelData ? Theme.secondary : Theme.textMuted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: root.selectedBand === modelData ? Font.Bold : Font.Medium
                                            }

                                            TapHandler {
                                                enabled: !SystemActionService.hotspotActive && !SystemActionService.hotspotChanging
                                                onTapped: {
                                                    root.selectedBand = modelData
                                                    root.persistSettings()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: Theme.radiusMedium
                            color: Theme.surface

                            RowLayout {
                                anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                                spacing: 10

                                MaterialIcon { text: "lan"; size: 20; color: Theme.tertiary }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1
                                    Text {
                                        text: "Internet"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: SystemActionService.hotspotInternetInterface.length > 0
                                            ? SystemActionService.hotspotInternetInterface : "Not detected"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }
                                }

                                MaterialIcon { text: "arrow_forward"; size: 18; color: Theme.textMuted }
                                MaterialIcon { text: "wifi"; size: 20; color: Theme.secondary }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1
                                    Text {
                                        text: "Shared over"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: SystemActionService.hotspotWifiInterface.length > 0
                                            ? SystemActionService.hotspotWifiInterface : "Not detected"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    Layout.maximumHeight: 64
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 126
                        Layout.fillHeight: true
                        radius: Theme.radiusMedium
                        color: qrTap.enabled ? Theme.tertiaryContainer : Theme.surfaceLow
                        opacity: qrTap.enabled ? 1 : 0.45
                        scale: qrTap.pressed ? 0.97 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "qr_code_2"
                                size: 21
                                color: Theme.tertiary
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Share QR"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        TapHandler {
                            id: qrTap
                            enabled: root.settingsValid && SystemActionService.hotspotQrAvailable
                            onTapped: root.showQrCode()
                        }

                        Behavior on scale { NumberAnimation { duration: Motion.instant } }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusMedium
                        color: SystemActionService.hotspotActive ? Theme.tertiaryContainer : Theme.secondary
                        opacity: actionTap.enabled ? 1 : 0.42
                        scale: actionTap.pressed ? 0.98 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: SystemActionService.hotspotChanging
                                    ? "hourglass_top"
                                    : (SystemActionService.hotspotActive ? "power_settings_new" : "router")
                                size: 22
                                color: SystemActionService.hotspotActive ? Theme.tertiary : Theme.accentInk
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: SystemActionService.hotspotChanging
                                    ? (SystemActionService.hotspotStarting ? "Starting…" : "Stopping…")
                                    : (SystemActionService.hotspotActive ? "Turn off" : "Start hotspot")
                                color: SystemActionService.hotspotActive ? Theme.text : Theme.accentInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }

                        TapHandler {
                            id: actionTap
                            enabled: SystemActionService.hotspotAvailable && !SystemActionService.hotspotChanging
                                && (SystemActionService.hotspotActive || root.settingsValid)
                            onTapped: {
                                if (SystemActionService.hotspotActive)
                                    SystemActionService.stopHotspot()
                                else
                                    root.startHotspot()
                            }
                        }

                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on scale { NumberAnimation { duration: Motion.instant } }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 30

                    Text {
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 3 }
                        text: SystemActionService.hotspotError.length > 0
                            ? SystemActionService.hotspotError
                            : (SystemActionService.hotspotMessage.length > 0
                                ? SystemActionService.hotspotMessage
                                : (SystemActionService.hotspotProfileSaved ? "Password saved for the next session" : ""))
                        color: SystemActionService.hotspotError.length > 0 ? Theme.danger : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Motion.pageEnter } }
                Behavior on x { NumberAnimation { duration: Motion.pageEnter; easing.type: Motion.pageCurve } }
            }

            ColumnLayout {
                id: qrPane
                anchors.fill: parent
                spacing: 12
                enabled: root.qrMode
                opacity: root.qrMode ? 1 : 0
                x: root.qrMode ? 0 : 34
                visible: opacity > 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusExtraLarge
                    color: Theme.surfaceLow

                    ColumnLayout {
                        anchors { fill: parent; margins: 22 }
                        spacing: 10

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "SCAN TO CONNECT"
                            color: Theme.secondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 286
                            Layout.preferredHeight: 286
                            radius: Theme.radiusExtraLarge
                            color: "#FFFFFF"

                            Image {
                                anchors { fill: parent; margins: 20 }
                                source: SystemActionService.hotspotQrPath.length > 0
                                    ? "file://" + SystemActionService.hotspotQrPath
                                        + "?v=" + SystemActionService.hotspotQrRevision
                                    : ""
                                cache: false
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                visible: source.toString().length > 0
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: SystemActionService.hotspotQrGenerating
                                    || SystemActionService.hotspotQrPath.length === 0
                                text: SystemActionService.hotspotQrGenerating ? "hourglass_top" : "qr_code_2"
                                size: 42
                                color: Theme.secondary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: ssidField.text
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: SystemActionService.hotspotActive
                                    ? "Point a phone camera at the code"
                                    : "Start the hotspot, then scan this code"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusMedium
                                color: Theme.surface

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    MaterialIcon { text: "refresh"; size: 20; color: Theme.secondary }
                                    Text {
                                        text: "Regenerate"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                TapHandler {
                                    enabled: !SystemActionService.hotspotQrGenerating
                                    onTapped: SystemActionService.generateHotspotQr(ssidField.text, passwordField.text)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusMedium
                                color: Theme.secondary

                                Text {
                                    anchors.centerIn: parent
                                    text: "Done"
                                    color: Theme.accentInk
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }

                                TapHandler { onTapped: root.qrMode = false }
                            }
                        }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Motion.pageEnter } }
                Behavior on x { NumberAnimation { duration: Motion.pageEnter; easing.type: Motion.pageCurve } }
            }
        }
    }
}
