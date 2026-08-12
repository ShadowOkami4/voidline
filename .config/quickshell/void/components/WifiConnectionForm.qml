import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Rectangle {
    id: root

    property string context: "action"
    property bool embedded: false
    property bool compact: false
    property string ssid: ""
    property string security: "psk"
    property bool hiddenNetwork: false
    property bool passwordVisible: false

    readonly property bool active: ConnectivityService.wifiPromptOpen
        && ConnectivityService.wifiPromptContext === context
    readonly property bool passwordRequired: security !== "open" && security !== "owe"
    readonly property bool inputValid: ssid.trim().length > 0
        && (!passwordRequired || (security === "sae"
            ? passwordField.text.length >= 1 : passwordField.text.length >= 8))
    readonly property bool connecting: ConnectivityService.wifiConnecting
        && ((ConnectivityService.pendingNetworkId.length > 0
                && ConnectivityService.pendingNetworkId
                    === ConnectivityService.wifiPromptNetworkId)
            || ConnectivityService.pendingSsid === ssid.trim())
    readonly property string connectActionLabel: {
        if (ConnectivityService.wifiOperationState === "creating-profile")
            return I18n.tr("network.creatingProfile")
        if (ConnectivityService.wifiOperationState === "authenticating")
            return I18n.tr("network.authenticating")
        if (connecting)
            return I18n.tr("network.connecting")
        if (ConnectivityService.wifiOperationState === "failed")
            return I18n.tr("common.retry")
        return I18n.tr("network.connect")
    }

    visible: active
    implicitHeight: active ? content.implicitHeight + (embedded ? 12 : 24) : 0
    radius: embedded ? 0 : Theme.radiusExtraLarge
    color: embedded ? "transparent" : Theme.secondaryContainer
    clip: true

    function syncPrompt() {
        if (!active)
            return
        ssid = ConnectivityService.wifiPromptSsid
        security = ConnectivityService.wifiPromptSecurity || "psk"
        hiddenNetwork = ConnectivityService.wifiPromptHidden
        passwordVisible = false
        passwordField.text = ""
        if (hiddenNetwork)
            hiddenSsidField.text = ""
        Qt.callLater(() => hiddenNetwork
            ? hiddenSsidField.forceActiveFocus(Qt.MouseFocusReason)
            : passwordField.forceActiveFocus(Qt.MouseFocusReason))
    }

    function submit() {
        const targetSsid = hiddenNetwork ? hiddenSsidField.text.trim() : ssid
        if (!inputValid || connecting)
            return
        ssid = targetSsid
        if (ConnectivityService.submitWifiCredentials(targetSsid, security,
                passwordField.text, context)) {
            // Never retain credentials in a visual control once the backend
            // has accepted them for its private stdin pipe.
            passwordField.text = ""
            passwordVisible = false
        }
    }

    Connections {
        target: ConnectivityService
        function onWifiPromptRevisionChanged() { root.syncPrompt() }
    }

    onActiveChanged: {
        if (!active) {
            passwordField.text = ""
            passwordVisible = false
        }
    }

    Component.onCompleted: syncPrompt()

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.reduceMotion ? 0 : Motion.panelResize
            easing.type: Motion.morphCurve
        }
    }

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.embedded ? 6 : 12
        }
        spacing: Metrics.spaceS

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spaceS

            Rectangle {
                Layout.preferredWidth: root.compact ? 40 : 46
                Layout.preferredHeight: width
                radius: Metrics.iconContainerRadius
                color: Theme.accentContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.hiddenNetwork ? "visibility_off" : "wifi_lock"
                    size: root.compact ? Metrics.iconM : Metrics.iconL
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.hiddenNetwork ? I18n.tr("network.hidden")
                        : I18n.tr("network.connectTo", { network: root.ssid })
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? Metrics.textBody : Metrics.textTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.hiddenNetwork ? I18n.tr("network.hiddenHint")
                        : I18n.tr("network.connectionSummary", {
                            signal: ConnectivityService.wifiPromptStrength,
                            security: root.security.toUpperCase()
                        })
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textCaption
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "close"
                accessibleName: I18n.tr("common.cancel")
                onClicked: ConnectivityService.cancelWifiPrompt(root.context)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.hiddenNetwork ? Metrics.minimumHitSize : 0
            visible: root.hiddenNetwork
            radius: Metrics.buttonRadius
            color: Theme.surfaceLow
            border.width: hiddenSsidField.activeFocus ? 2 : 1
            border.color: hiddenSsidField.activeFocus ? Theme.secondary : Theme.outlineSoft

            Text {
                anchors { left: parent.left; leftMargin: Metrics.inputPaddingX; verticalCenter: parent.verticalCenter }
                visible: hiddenSsidField.text.length === 0
                text: I18n.tr("network.networkName")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.textSupporting
            }
            TextInput {
                id: hiddenSsidField
                anchors { fill: parent; leftMargin: Metrics.inputPaddingX; rightMargin: Metrics.inputPaddingX }
                enabled: !root.connecting
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.secondary
                selectedTextColor: Theme.accentInk
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.textBody
                maximumLength: 32
                onTextChanged: root.ssid = text.trim()
                onAccepted: passwordField.forceActiveFocus()
            }
        }

        SlidingChoice {
            Layout.fillWidth: true
            visible: root.hiddenNetwork
            options: ["psk", "open"]
            optionLabels: [I18n.tr("network.protectedNetwork"),
                I18n.tr("network.openNetwork")]
            value: root.security
            maxColumns: 2
            enabled: !root.connecting
            onSelected: value => root.security = value
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.minimumHitSize
            spacing: Metrics.spaceS

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Metrics.buttonRadius
                color: Theme.surfaceLow
                border.width: passwordField.activeFocus ? 2 : 1
                border.color: passwordField.activeFocus ? Theme.secondary : Theme.outlineSoft
                opacity: root.passwordRequired ? 1 : 0.55

                Text {
                    anchors { left: parent.left; leftMargin: Metrics.inputPaddingX; verticalCenter: parent.verticalCenter }
                    visible: passwordField.text.length === 0
                    text: root.passwordRequired ? I18n.tr("network.passwordHint")
                        : I18n.tr("network.passwordNotRequired")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textSupporting
                }
                TextInput {
                    id: passwordField
                    anchors { fill: parent; leftMargin: Metrics.inputPaddingX; rightMargin: 48 }
                    enabled: root.passwordRequired && !root.connecting
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.secondary
                    selectedTextColor: Theme.accentInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textBody
                    echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText
                    maximumLength: 64
                    onAccepted: root.submit()
                }
                IconButton {
                    anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                    visible: root.passwordRequired
                    enabled: !root.connecting
                    size: 40
                    icon: root.passwordVisible ? "visibility_off" : "visibility"
                    accessibleName: root.passwordVisible
                        ? I18n.tr("network.hidePassword") : I18n.tr("network.showPassword")
                    onClicked: root.passwordVisible = !root.passwordVisible
                }
            }

            Rectangle {
                id: cancelButton
                Layout.preferredWidth: root.compact ? 46 : Math.max(78,
                    cancelLabel.implicitWidth + 30)
                Layout.fillHeight: true
                radius: Metrics.buttonRadius
                color: cancelHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                scale: cancelTap.pressed ? 0.97 : 1

                Row {
                    anchors.centerIn: parent
                    spacing: Metrics.spaceXS
                    MaterialIcon {
                        text: root.connecting ? "stop_circle" : "close"
                        size: Metrics.iconS
                        color: Theme.text
                    }
                    Text {
                        id: cancelLabel
                        visible: !root.compact
                        text: I18n.tr("common.cancel")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textSupporting
                        font.weight: Font.Bold
                    }
                }
                HoverHandler { id: cancelHover }
                TapHandler {
                    id: cancelTap
                    onTapped: ConnectivityService.cancelWifiPrompt(root.context)
                }
                Behavior on scale { NumberAnimation { duration: Motion.instant } }
            }

            Rectangle {
                id: connectButton
                Layout.preferredWidth: root.compact ? 48 : Math.max(104, connectLabel.implicitWidth + 40)
                Layout.fillHeight: true
                radius: Metrics.buttonRadius
                color: root.inputValid && !root.connecting
                    ? (connectHover.hovered ? Theme.accentStrong : Theme.accent)
                    : Theme.surfaceHover
                opacity: root.inputValid ? 1 : 0.5
                scale: connectTap.pressed ? 0.97 : 1

                Row {
                    anchors.centerIn: parent
                    spacing: Metrics.spaceXS
                    MaterialIcon {
                        text: root.connecting ? "progress_activity"
                            : (ConnectivityService.wifiOperationState === "failed"
                                ? "refresh" : "arrow_forward")
                        size: Metrics.iconS
                        color: root.inputValid ? Theme.accentInk : Theme.textMuted
                        RotationAnimator on rotation {
                            running: root.connecting
                            from: 0
                            to: 360
                            duration: Motion.spinner
                            loops: Animation.Infinite
                        }
                    }
                    Text {
                        id: connectLabel
                        visible: !root.compact
                        text: root.connectActionLabel
                        color: root.inputValid ? Theme.accentInk : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textSupporting
                        font.weight: Font.Bold
                    }
                }
                HoverHandler { id: connectHover; enabled: root.inputValid && !root.connecting }
                TapHandler {
                    id: connectTap
                    enabled: root.inputValid && !root.connecting
                    onTapped: root.submit()
                }
                Behavior on scale { NumberAnimation { duration: Motion.instant } }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: ConnectivityService.wifiOperationState === "failed"
                && ConnectivityService.wifiError.length > 0
            text: ConnectivityService.wifiError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.textSupporting
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
