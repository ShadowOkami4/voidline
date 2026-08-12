import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

FocusScope {
    id: root

    property bool entered: false
    opacity: LockService.unlocking ? 0 : (entered ? 1 : 0)
    scale: LockService.unlocking ? 1.018 : (entered ? 1 : 0.992)

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.reduceMotion ? 0
                : (LockService.unlocking ? Motion.pageExit : Motion.pageEnter)
            easing.type: LockService.unlocking ? Motion.pageExitCurve : Motion.pageCurve
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Appearance.reduceMotion ? 0 : Motion.pageEnter
            easing.type: Motion.pageCurve
        }
    }

    readonly property real lockSafeLeft: Math.max(20, Metrics.spaceXL)
    readonly property real lockSafeRight: root.width - lockSafeLeft
    readonly property real lockSafeTop: Math.max(24, Metrics.spaceXL)
    readonly property real lockSafeBottom: Math.max(lockSafeTop + lockClock.height,
        unlockCard.y - Metrics.spaceXL)
    readonly property real lockSafeWidth: Math.max(lockClock.width,
        lockSafeRight - lockSafeLeft)
    readonly property real lockSafeHeight: Math.max(lockClock.height,
        lockSafeBottom - lockSafeTop)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Image {
        anchors.fill: parent
        source: WallpaperService.currentPath.length > 0
            ? "file://" + WallpaperService.currentPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.darkMode ? "#A6100E14" : "#8A141218"
    }

    LockClock {
        id: lockClock
        width: Math.min(660, root.width - 40)
        height: Math.min(280, root.height * 0.32)
        x: root.lockSafeLeft + Math.max(0, root.lockSafeWidth - width)
            * Appearance.lockClockX
        y: root.lockSafeTop + Math.max(0, root.lockSafeHeight - height)
            * Appearance.lockClockY
        date: clock.date
    }

    Rectangle {
        id: unlockCard
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Math.max(70, parent.height * 0.13)
        }
        width: Math.min(430, parent.width - 48)
        height: 226
        radius: Theme.radiusExtraLarge
        color: Theme.panel
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42)
        scale: LockService.authenticating ? 0.99 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.standardCurve
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 20
            }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                spacing: 14
                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 76
                    radius: Theme.radiusExtraLarge
                    color: Theme.accentContainer
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r,
                        Theme.accent.g, Theme.accent.b, 0.72)

                    RoundedImage {
                        anchors {
                            fill: parent
                            margins: 4
                        }
                        radius: Theme.radiusLarge
                        source: ProfileImageService.avatarSource
                        fallbackIcon: "person"
                        fallbackColor: Theme.groupSurfaceRaised
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("lock.welcome")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 19
                        font.weight: Font.Bold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("lock.prompt")
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
                MaterialIcon {
                    text: "lock"
                    size: 20
                    color: Theme.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radiusMedium
                color: passwordInput.activeFocus ? Theme.surfaceHigh : Theme.surfaceLow
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus ? Theme.accent : Theme.outlineSoft

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 16
                        rightMargin: 8
                    }
                    spacing: 8
                    TextInput {
                        id: passwordInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        enabled: !LockService.authenticating
                        echoMode: showPassword.checked
                            ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: LockService.authenticating
                                ? I18n.tr("lock.checkingPassword") : I18n.tr("lock.password")
                            color: Theme.textMuted
                            font: passwordInput.font
                            verticalAlignment: Text.AlignVCenter
                            visible: passwordInput.text.length === 0
                        }

                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                    }
                    IconButton {
                        id: showPassword
                        property bool checked: false
                        size: 38
                        icon: checked ? "visibility_off" : "visibility"
                        accessibleName: checked ? I18n.tr("common.hidePassword")
                            : I18n.tr("common.showPassword")
                        onClicked: checked = !checked
                    }
                    IconButton {
                        size: 38
                        icon: LockService.authenticating ? "progress_activity" : "arrow_forward"
                        accessibleName: I18n.tr("lock.unlock")
                        enabled: passwordInput.text.length > 0
                            && !LockService.authenticating
                        active: passwordInput.text.length > 0
                        onClicked: root.submit()
                    }
                }

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                text: LockService.message
                visible: text.length > 0
                color: LockService.messageIsError ? Theme.danger : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    function submit() {
        if (LockService.authenticate(passwordInput.text))
            passwordInput.text = ""
    }

    Connections {
        target: LockService
        function onAuthenticationFailed() {
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        WeatherService.setLockActive(Appearance.lockShowWeather)
        Qt.callLater(() => {
            root.entered = true
            passwordInput.forceActiveFocus()
        })
    }
    Component.onDestruction: WeatherService.setLockActive(false)
    Connections {
        target: Appearance
        function onLockShowWeatherChanged() {
            WeatherService.setLockActive(Appearance.lockShowWeather)
        }
    }
}
