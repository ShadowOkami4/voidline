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

    // Scrim keeps text legible over any wallpaper while letting its colour
    // through; the clock and unlock controls float directly on it.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.withAlpha(Theme.background, Theme.darkMode ? 0.42 : 0.28) }
            GradientStop { position: 0.55; color: Theme.withAlpha(Theme.background, Theme.darkMode ? 0.5 : 0.36) }
            GradientStop { position: 1; color: Theme.withAlpha(Theme.background, Theme.darkMode ? 0.82 : 0.7) }
        }
    }

    LockClock {
        id: lockClock
        width: Appearance.lockClockStyle === "pixel"
            ? Math.min(560, root.width * 0.45) : Math.min(660, root.width - 40)
        height: Appearance.lockClockStyle === "pixel"
            ? Math.min(560, root.height * 0.62) : Math.min(280, root.height * 0.32)
        x: root.lockSafeLeft + Math.max(0, root.lockSafeWidth - width)
            * Appearance.lockClockX
        y: root.lockSafeTop + Math.max(0, root.lockSafeHeight - height)
            * Appearance.lockClockY
        date: clock.date
    }

    // Material 3 Expressive unlock cluster: avatar, emphasized greeting, a
    // pill password field on a tonal container, and a filled unlock button
    // that morphs while authentication runs.
    Item {
        id: unlockCard
        // With the clock on the left (the Pixel layout) the unlock column
        // takes the right side of the screen; otherwise it sits at the bottom.
        readonly property bool sideLayout: Appearance.lockClockX < 0.4
            && root.width >= Math.round(1000 * Metrics.scale)
        x: sideLayout ? root.width - width - Math.max(48, root.width * 0.08)
            : (root.width - width) / 2
        y: sideLayout ? (root.height - height) / 2
            : root.height - height - Math.max(56, root.height * 0.1)
        width: Math.min(Math.round(420 * Metrics.scale), parent.width - 48)
        height: unlockColumn.implicitHeight

        ColumnLayout {
            id: unlockColumn
            width: parent.width
            spacing: Metrics.spaceM

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(96 * Metrics.scale)
                Layout.preferredHeight: Layout.preferredWidth

                Rectangle {
                    id: avatarRing
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(3, Math.round(3 * Metrics.scale))
                    border.color: LockService.messageIsError ? Theme.danger : Theme.accent

                    Behavior on border.color { ColorAnimation { duration: Motion.effectsFastDuration } }
                }
                RoundedImage {
                    anchors {
                        fill: parent
                        margins: avatarRing.border.width + Math.round(3 * Metrics.scale)
                    }
                    radius: width / 2
                    source: ProfileImageService.avatarSource
                    fallbackIcon: "person"
                    fallbackColor: Theme.accentContainer
                    fallbackIconSize: Math.round(width * 0.52)
                    fallbackIconColor: Theme.accentContainerInk
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceXS
                text: I18n.tr("lock.welcome")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(26 * Metrics.scale)
                font.weight: Font.Bold
                font.variableAxes: ({ "wght": 720, "wdth": 110, "opsz": 32 })
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: -Metrics.spaceS
                text: I18n.tr("lock.prompt")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextSupporting
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Rectangle {
                id: passwordField
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spaceS
                Layout.preferredHeight: Math.round(64 * Metrics.scale)
                radius: height / 2
                color: passwordInput.activeFocus ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.width: LockService.messageIsError ? 2 : (passwordInput.activeFocus ? 2 : 0)
                border.color: LockService.messageIsError ? Theme.danger : Theme.accent

                // Expressive error feedback: a short horizontal shake.
                transform: Translate { id: shakeOffset }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 50; easing.type: Easing.OutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: -5; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation {
                        target: shakeOffset; property: "x"; to: 0; duration: Motion.springFast
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialFast
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Math.round(24 * Metrics.scale)
                        rightMargin: Math.round(8 * Metrics.scale)
                    }
                    spacing: Metrics.spaceS

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
                        font.pixelSize: Math.round(16 * Metrics.scale)
                        font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: LockService.authenticating
                                ? I18n.tr("lock.checkingPassword") : I18n.tr("lock.password")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: passwordInput.font.pixelSize
                            verticalAlignment: Text.AlignVCenter
                            visible: passwordInput.text.length === 0
                        }

                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                    }
                    IconButton {
                        id: showPassword
                        property bool checked: false
                        size: Math.round(40 * Metrics.scale)
                        icon: checked ? "visibility_off" : "visibility"
                        accessibleName: checked ? I18n.tr("common.hidePassword")
                            : I18n.tr("common.showPassword")
                        onClicked: checked = !checked
                    }

                    // Filled primary unlock button. It morphs from a circle
                    // to a rounded square and spins its glyph while checking.
                    Rectangle {
                        id: unlockButton
                        readonly property bool ready: passwordInput.text.length > 0
                            && !LockService.authenticating
                        Layout.preferredWidth: Math.round(48 * Metrics.scale)
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: LockService.authenticating || unlockTap.pressed
                            ? Metrics.radiusM : width / 2
                        color: ready || LockService.authenticating ? Theme.accent : Theme.surfaceHigh
                        activeFocusOnTab: ready
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.tr("lock.unlock")

                        Behavior on radius {
                            NumberAnimation {
                                duration: Motion.springFast
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.spatialFast
                            }
                        }
                        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: LockService.authenticating ? "progress_activity" : "arrow_forward"
                            size: Math.round(24 * Metrics.scale)
                            fill: 1
                            color: unlockButton.ready || LockService.authenticating
                                ? Theme.accentInk : Theme.textMuted

                            RotationAnimation on rotation {
                                running: LockService.authenticating && !Appearance.reduceMotion
                                from: 0
                                to: 360
                                loops: Animation.Infinite
                                duration: Motion.spinner
                            }
                        }

                        TapHandler {
                            id: unlockTap
                            enabled: unlockButton.ready
                            onTapped: root.submit()
                        }
                        HoverHandler {
                            enabled: unlockButton.ready
                            cursorShape: Qt.PointingHandCursor
                        }
                        Keys.onReturnPressed: root.submit()
                        Keys.onSpacePressed: root.submit()
                    }
                }

                Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
                Behavior on border.color { ColorAnimation { duration: Motion.effectsFastDuration } }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(20 * Metrics.scale)
                text: LockService.message
                opacity: text.length > 0 ? 1 : 0
                color: LockService.messageIsError ? Theme.danger : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextSupporting
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight

                Behavior on opacity { NumberAnimation { duration: Motion.effectsFastDuration } }
            }
        }
    }

    // Pending notifications, shown as app glyphs under the clock area.
    Row {
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: lockClock.x + Math.round(10 * Metrics.scale)
            bottomMargin: Math.round(120 * Metrics.scale)
        }
        visible: NotificationService.count > 0 && !Appearance.doNotDisturb
        spacing: Metrics.spaceS

        Repeater {
            model: Math.min(4, NotificationService.count)

            Rectangle {
                width: Math.round(40 * Metrics.scale)
                height: width
                radius: width / 2
                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.85)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "notifications"
                    size: Math.round(20 * Metrics.scale)
                    fill: 1
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Metrics.spaceXS
            text: I18n.tr("actionCenter.notifications") + " · " + NotificationService.count
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(14 * Metrics.scale)
            font.weight: Font.DemiBold
        }
    }

    // Corner shortcut: suspend without unlocking.
    Rectangle {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Math.round(40 * Metrics.scale)
        }
        width: Math.round(64 * Metrics.scale)
        height: width
        radius: sleepTap.pressed ? Metrics.radiusL : width / 2
        color: Theme.withAlpha(Theme.surfaceContainerHighest, sleepHover.hovered ? 0.95 : 0.8)
        Accessible.role: Accessible.Button
        Accessible.name: I18n.tr("power.sleep")

        Behavior on radius {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        MaterialIcon {
            anchors.centerIn: parent
            text: "bedtime"
            size: Math.round(26 * Metrics.scale)
        }
        HoverHandler {
            id: sleepHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: sleepTap
            onTapped: SystemActionService.performSessionAction("suspend")
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
            if (!Appearance.reduceMotion)
                shake.restart()
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
