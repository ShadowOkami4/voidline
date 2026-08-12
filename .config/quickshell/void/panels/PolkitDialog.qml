import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

PanelWindow {
    id: root

    readonly property bool activeForScreen: PolkitService.active
        && screen && screen.name === PolkitService.screenName
    property bool showResponse: false
    property string response: ""

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    focusable: activeForScreen
    visible: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-polkit"
    WlrLayershell.keyboardFocus: activeForScreen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        x: root.activeForScreen ? 0 : root.width
        y: 0
        width: root.activeForScreen ? root.width : 0
        height: root.activeForScreen ? root.height : 0
    }

    onActiveForScreenChanged: {
        response = ""
        showResponse = false
        if (activeForScreen)
            focusDelay.restart()
    }

    Timer {
        id: focusDelay
        interval: 80
        onTriggered: passwordInput.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.shadow, root.activeForScreen ? 0.48 : 0)
        visible: root.activeForScreen || opacity > 0

        Behavior on color {
            ColorAnimation { duration: Appearance.reduceMotion ? 0 : Motion.fast }
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(520, root.width - 40)
        height: content.implicitHeight + 40
        radius: Theme.radiusExtraLarge
        color: Theme.panel
        border.width: 1
        border.color: Theme.outlineSoft
        opacity: root.activeForScreen ? 1 : 0
        scale: root.activeForScreen ? 1 : 0.94
        clip: true

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.reduceMotion ? 0 : Motion.fast
                easing.type: Motion.standardCurve
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.reduceMotion ? 0 : Motion.enter
                easing.type: Motion.enterCurve
            }
        }

        ColumnLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 20
            }
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 54
                    radius: 19
                    color: Theme.accentContainer

                    Image {
                        id: requestIcon
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        source: PolkitService.iconName.length > 0
                            ? Quickshell.iconPath(PolkitService.iconName) : ""
                        visible: source.toString().length > 0 && status === Image.Ready
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !requestIcon.visible
                        text: "admin_panel_settings"
                        size: 28
                        color: Theme.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("polkit.title")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 23
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("polkit.request", {
                            application: PolkitService.applicationLabel()
                        })
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: explanationText.implicitHeight + 24
                radius: Theme.radiusMedium
                color: Theme.groupSurface

                Text {
                    id: explanationText
                    anchors { fill: parent; margins: 12 }
                    text: PolkitService.explanation()
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                visible: PolkitService.identities && PolkitService.identities.length > 1
                radius: Theme.radiusMedium
                color: Theme.surfaceLow

                Flickable {
                    anchors { fill: parent; margins: 8 }
                    contentWidth: identityRow.implicitWidth
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: identityRow
                        height: parent.height
                        spacing: 6

                        Repeater {
                            model: PolkitService.identities || []

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: PolkitService.flow
                                    && PolkitService.flow.selectedIdentity === modelData
                                width: Math.max(112, identityLabel.implicitWidth + 42)
                                height: identityRow.height
                                radius: Theme.radiusMedium
                                color: selected ? Theme.accentContainer
                                    : (identityHover.hovered
                                        ? Theme.surfaceHover : Theme.groupSurface)
                                border.width: selected ? 1 : 0
                                border.color: Theme.accent

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    MaterialIcon {
                                        text: "person"
                                        size: 18
                                        color: selected ? Theme.accent : Theme.textMuted
                                    }
                                    Text {
                                        id: identityLabel
                                        Layout.fillWidth: true
                                        text: String(modelData)
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: selected ? Font.Bold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }
                                HoverHandler { id: identityHover }
                                TapHandler {
                                    onTapped: PolkitService.selectIdentity(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Theme.radiusMedium
                color: Theme.surfaceLow
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus ? Theme.accent : Theme.outlineSoft

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 15
                        verticalCenter: parent.verticalCenter
                    }
                    visible: passwordInput.text.length === 0
                    text: PolkitService.inputPrompt.length > 0
                        ? PolkitService.inputPrompt : I18n.tr("polkit.password")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                TextInput {
                    id: passwordInput
                    anchors {
                        fill: parent
                        leftMargin: 15
                        rightMargin: 52
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.response
                    onTextChanged: root.response = text
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    echoMode: root.showResponse || PolkitService.responseVisible
                        ? TextInput.Normal : TextInput.Password
                    passwordMaskDelay: 0
                    Keys.onReturnPressed: authenticateButton.trigger()
                }

                IconButton {
                    anchors {
                        right: parent.right
                        rightMargin: 7
                        verticalCenter: parent.verticalCenter
                    }
                    icon: root.showResponse ? "visibility_off" : "visibility"
                    accessibleName: root.showResponse
                        ? I18n.tr("polkit.hidePassword") : I18n.tr("polkit.showPassword")
                    onClicked: root.showResponse = !root.showResponse
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: messageText.implicitHeight + 20
                visible: PolkitService.supplementaryMessage.length > 0
                    || PolkitService.failed
                radius: Theme.radiusMedium
                color: PolkitService.supplementaryIsError || PolkitService.failed
                    ? Theme.dangerContainer : Theme.secondaryContainer

                Text {
                    id: messageText
                    anchors { fill: parent; margins: 10 }
                    text: PolkitService.supplementaryMessage.length > 0
                        ? PolkitService.supplementaryMessage
                        : I18n.tr("polkit.failed")
                    color: PolkitService.supplementaryIsError || PolkitService.failed
                        ? Theme.danger : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: 9

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMedium
                    color: cancelHover.hovered ? Theme.surfaceHover : Theme.groupSurface

                    Text {
                        anchors.centerIn: parent
                        text: I18n.tr("common.cancel")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: cancelHover }
                    TapHandler {
                        onTapped: {
                            root.response = ""
                            PolkitService.cancel()
                        }
                    }
                }

                Rectangle {
                    id: authenticateButton
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMedium
                    color: authHover.hovered ? Theme.accentStrong : Theme.accent
                    enabled: PolkitService.responseRequired

                    function trigger() {
                        if (!enabled)
                            return
                        const value = root.response
                        root.response = ""
                        PolkitService.submit(value)
                    }

                    opacity: enabled ? 1 : 0.5
                    Text {
                        anchors.centerIn: parent
                        text: PolkitService.failed
                            ? I18n.tr("polkit.retry") : I18n.tr("polkit.authenticate")
                        color: Theme.accentInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                    HoverHandler { id: authHover }
                    TapHandler { onTapped: authenticateButton.trigger() }
                }
            }
        }
    }
}
