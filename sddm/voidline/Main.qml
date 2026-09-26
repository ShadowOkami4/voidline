import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root

    width: 1920
    height: 1080
    property color background: config.backgroundColor || "#0B0C0C"
    color: background
    focus: true
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(root.background, 1.16) }
        GradientStop { position: 0.52; color: root.background }
        GradientStop { position: 1.0; color: Qt.lighter(root.background, 1.08) }
    }

    property string fontFamily: config.fontFamily || "Roboto Flex"
    property int clockWeight: 760
    property string clockStyle: "pixel"
    // Android 16 layout: big stacked clock on the left, sign-in on the right,
    // round power buttons in the corner. Narrow screens use the centred layout.
    readonly property bool pixelLayout: clockStyle === "pixel" && width >= 1000
    property color clockColor: foreground
    property color accent: config.accentColor || "#AFD4C9"
    property color accentSoft: config.accentSoftColor || "#305A4D"
    property color panel: config.panelColor || "#161A19"
    property color surface: config.surfaceColor || "#242B29"
    property color surfaceRaised: config.raisedSurfaceColor || "#2F3A37"
    property color foreground: config.textColor || "#E7E9E9"
    property color muted: config.mutedTextColor || "#B2BDBA"
    property color outline: config.outlineColor || "#43514D"
    property color danger: config.dangerColor || "#FFB4AB"
    // Material 3 Expressive content colours derived from the cached palette.
    readonly property color accentInk: Qt.hsla(accent.hslHue,
        Math.min(0.5, accent.hslSaturation), 0.14, 1)
    readonly property color accentSoftInk: Qt.hsla(accent.hslHue,
        Math.min(0.4, accent.hslSaturation), 0.9, 1)
    readonly property color dangerContainer: "#93000A"
    readonly property color dangerInk: "#FFDAD6"
    // Material 3 Expressive spatial springs (fast and default).
    readonly property var spatialFast: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var spatialDefault: [0.38, 1.21, 0.22, 1, 1, 1]
    property int shapeRadius: Number(config.radius) || 28
    property bool compactHeight: height < 760
    property date now: new Date()
    property bool loginBusy: false
    property bool sessionMenuOpen: false
    property bool userMenuOpen: false
    property bool confirmOpen: false
    property string pendingPowerAction: ""
    property string pendingPowerLabel: ""
    property int selectedUserIndex: userModel.lastIndex >= 0
        ? userModel.lastIndex : 0
    property string selectedUser: userModel.lastUser || ""
    property string selectedDisplayName: selectedUser
    property string selectedSystemAvatar: ""
    property int sessionIndex: sessionModel.lastIndex >= 0
        ? sessionModel.lastIndex : 0
    property string sessionName: "Desktop session"
    property string cachedWallpaper: selectedUser.length > 0
        ? "file:///var/tmp/voidline-sddm-" + selectedUser
            + ".wallpaper.png" : ""
    property string cachedAvatar: selectedUser.length > 0
        ? "file:///var/tmp/voidline-sddm-" + selectedUser
            + ".avatar.png" : ""
    property string cachedMetadata: selectedUser.length > 0
        ? "/var/tmp/voidline-sddm-" + selectedUser + ".meta" : ""

    function chooseUser(userName, displayName, systemAvatar, modelIndex) {
        selectedUser = String(userName || "")
        selectedDisplayName = String(displayName || userName || "")
        selectedSystemAvatar = String(systemAvatar || "")
        selectedUserIndex = modelIndex
        userList.currentIndex = modelIndex
        passwordInput.text = ""
        errorText.text = ""
        sessionMenuOpen = false
        userMenuOpen = false
        Qt.callLater(loadPresentationCache)
        passwordInput.forceActiveFocus()
    }

    function loadPresentationCache() {
        if (selectedUser.length === 0)
            return
        const request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE
                    || (request.status !== 0 && request.status !== 200))
                return
            const values = ({})
            const rows = String(request.responseText || "").split("\n")
            for (let index = 0; index < rows.length; ++index) {
                const separator = rows[index].indexOf("=")
                if (separator > 0)
                    values[rows[index].slice(0, separator)]
                        = rows[index].slice(separator + 1)
            }
            const styles = ["pixel", "digital-large", "digital-compact", "stacked",
                "horizontal", "minimal", "playful"]
            clockStyle = styles.indexOf(values.clockStyle) >= 0
                ? values.clockStyle : "pixel"
            if (values.clockFont && values.clockFont.length <= 80)
                fontFamily = values.clockFont
            clockWeight = Math.max(100, Math.min(900,
                Number(values.clockWeight) || 760))
            if (/^#[0-9A-Fa-f]{6}$/.test(values.clockColor || ""))
                clockColor = values.clockColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.accentColor || ""))
                accent = values.accentColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.accentSoftColor || ""))
                accentSoft = values.accentSoftColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.backgroundColor || ""))
                background = values.backgroundColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.panelColor || ""))
                panel = values.panelColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.surfaceColor || ""))
                surface = values.surfaceColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.raisedSurfaceColor || ""))
                surfaceRaised = values.raisedSurfaceColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.textColor || ""))
                foreground = values.textColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.mutedTextColor || ""))
                muted = values.mutedTextColor
            if (/^#[0-9A-Fa-f]{6}$/.test(values.outlineColor || ""))
                outline = values.outlineColor
        }
        request.open("GET", "file://" + cachedMetadata)
        request.send()
    }

    function attemptLogin() {
        if (loginBusy || selectedUser.length === 0
                || passwordInput.text.length === 0)
            return
        errorText.text = "Checking password…"
        loginBusy = true
        sessionMenuOpen = false
        sddm.login(selectedUser, passwordInput.text, sessionIndex)
    }

    function requestPower(action, label) {
        pendingPowerAction = action
        pendingPowerLabel = label
        confirmOpen = true
        confirmButton.forceActiveFocus()
    }

    function runPowerAction() {
        confirmOpen = false
        if (pendingPowerAction === "reboot")
            sddm.reboot()
        else if (pendingPowerAction === "power")
            sddm.powerOff()
        else if (pendingPowerAction === "hibernate")
            sddm.hibernate()
    }

    Keys.onEscapePressed: {
        if (confirmOpen) {
            confirmOpen = false
            passwordInput.forceActiveFocus()
        } else if (sessionMenuOpen) {
            sessionMenuOpen = false
            passwordInput.forceActiveFocus()
        } else if (userMenuOpen) {
            userMenuOpen = false
            passwordInput.forceActiveFocus()
        }
    }

    Image {
        anchors.fill: parent
        source: root.cachedWallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
    }

    // Scrim: light at the top so the wallpaper shows, deeper behind the
    // sign-in controls so text stays legible on any image.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.42) }
            GradientStop { position: 0.55; color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.84) }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            margins: 24
        }
        width: hostRow.width + 32
        height: 44
        radius: height / 2
        color: root.surface

        Row {
            id: hostRow
            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                source: "assets/voidline.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sddm.hostName
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }
    }

    Rectangle {
        id: userControl
        anchors {
            top: parent.top
            right: parent.right
            margins: 24
        }
        z: 30
        width: Math.min(280, Math.max(164, userControlRow.implicitWidth + 20))
        height: 48
        radius: root.userMenuOpen ? 16 : height / 2
        color: root.userMenuOpen ? root.accentSoft
            : (userControlMouse.containsMouse ? Qt.lighter(root.surface, 1.22) : root.surface)
        activeFocusOnTab: userList.count > 1

        Behavior on radius {
            NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialFast }
        }
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            id: userControlRow
            anchors {
                left: parent.left
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }
            spacing: 10

            RoundedAvatar {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                frameWidth: 3
                ringWidth: 0
                source: root.cachedAvatar
                fallbackSource: root.selectedSystemAvatar
                fallbackText: root.selectedUser.length > 0
                    ? root.selectedUser.charAt(0).toUpperCase() : "V"
                accent: root.accent
                foreground: root.accentSoftInk
                surface: root.accentSoft
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(160, implicitWidth)
                text: root.selectedDisplayName || root.selectedUser
                color: root.userMenuOpen ? root.accentSoftInk : root.foreground
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: userList.count > 1
                text: root.userMenuOpen ? "expand_less" : "expand_more"
                color: root.userMenuOpen ? root.accentSoftInk : root.muted
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
            }
        }

        MouseArea {
            id: userControlMouse
            anchors.fill: parent
            enabled: userList.count > 1
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.userMenuOpen = !root.userMenuOpen
        }
        Keys.onSpacePressed: root.userMenuOpen = !root.userMenuOpen
        Keys.onReturnPressed: root.userMenuOpen = !root.userMenuOpen
    }

    // Material 3 menu: rounded container, pill-shaped selected item.
    Rectangle {
        id: userMenu
        anchors {
            top: userControl.bottom
            right: userControl.right
            topMargin: 6
        }
        z: 29
        width: 288
        height: root.userMenuOpen
            ? Math.min(320, userList.contentHeight + 16) : 0
        radius: 24
        color: root.panel
        clip: true
        opacity: root.userMenuOpen ? 1 : 0
        visible: height > 0

        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2
            clip: true
            model: userModel
            currentIndex: root.selectedUserIndex

            delegate: Rectangle {
                readonly property bool isSelected: root.selectedUser === name
                width: userList.width
                height: 56
                radius: isSelected ? height / 2 : 16
                color: isSelected
                    ? root.accentSoft : userItemMouse.containsMouse
                        ? root.surfaceRaised : "transparent"

                Behavior on radius {
                    NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialFast }
                }

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 12
                    }
                    spacing: 12
                    RoundedAvatar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        frameWidth: 3
                        ringWidth: parent.parent.isSelected ? 2 : 0
                        source: "file:///var/tmp/voidline-sddm-" + name + ".avatar.png"
                        fallbackSource: icon
                        fallbackText: name.length > 0 ? name.charAt(0).toUpperCase() : "V"
                        accent: root.accent
                        foreground: root.accentSoftInk
                        surface: root.accentSoft
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 86
                        text: realName && realName.length > 0 ? realName : name
                        color: parent.parent.isSelected ? root.accentSoftInk : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.weight: parent.parent.isSelected ? Font.Bold : Font.Medium
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.parent.isSelected
                        text: "check"
                        color: root.accentSoftInk
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                    }
                }
                MouseArea {
                    id: userItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chooseUser(name,
                        realName && realName.length > 0 ? realName : name,
                        icon, index)
                }

                Component.onCompleted: {
                    if (index === root.selectedUserIndex
                            || (root.selectedUser.length === 0 && index === 0)) {
                        root.chooseUser(name,
                            realName && realName.length > 0 ? realName : name,
                            icon, index)
                    }
                }
            }
        }

        Behavior on height {
            NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialDefault }
        }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Column {
        visible: root.pixelLayout
        x: Math.max(56, root.width * 0.055)
        y: Math.max(72, root.height * 0.13)
        spacing: 8

        Column {
            spacing: -Math.round(clockDigits.font.pixelSize * 0.3)

            Text {
                id: clockDigits
                text: Qt.formatTime(root.now, "HH")
                color: Qt.hsla(root.accent.hslHue, Math.min(0.55, root.accent.hslSaturation + 0.1), 0.86, 1)
                font.family: root.fontFamily
                font.pixelSize: Math.max(120, Math.min(230, root.height * 0.22))
                font.weight: Font.Black
                font.letterSpacing: -6
                lineHeight: 0.82
            }
            Text {
                text: Qt.formatTime(root.now, "mm")
                color: root.clockColor
                font.family: root.fontFamily
                font.pixelSize: clockDigits.font.pixelSize
                font.weight: Font.Black
                font.letterSpacing: -6
                lineHeight: 0.82
            }
        }
        Text {
            leftPadding: 10
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
    }

    Column {
        visible: !root.pixelLayout
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.compactHeight ? 28
                : Math.max(56, parent.height * 0.08)
        }
        spacing: -4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clockStyle === "stacked"
                ? Qt.formatTime(root.now, "HH") + "\n"
                    + Qt.formatTime(root.now, "mm")
                : Qt.formatTime(root.now, "HH:mm")
            color: root.clockColor
            font.family: root.clockStyle === "playful"
                ? "URW Chancery L" : root.fontFamily
            font.pixelSize: root.compactHeight
                ? (root.clockStyle === "minimal" ? 46 : 64)
                : Math.max(64, Math.min(root.clockStyle === "minimal" ? 88 : 128,
                    root.height * (root.clockStyle === "minimal" ? 0.085 : 0.12)))
            font.weight: root.clockStyle === "minimal"
                ? Font.Medium : root.clockWeight
            font.letterSpacing: root.clockStyle === "minimal" ? 0 : -3
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.78
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: root.foreground
            opacity: 0.86
            font.family: root.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
    }

    // Material 3 Expressive sign-in cluster, mirroring the Voidline lock
    // screen: ringed avatar, emphasized name, pill password field with a
    // filled sign-in button, and a tonal session selector.
    Item {
        id: loginCard
        x: root.pixelLayout ? root.width - width - Math.max(56, root.width * 0.08)
            : (root.width - width) / 2
        y: root.pixelLayout ? (root.height - height) / 2
            : powerRow.y - height - (root.compactHeight ? 24 : Math.max(40, root.height * 0.07))
        width: Math.min(440, parent.width - 48)
        height: loginColumn.height
        opacity: 0
        scale: 0.96

        Component.onCompleted: cardEntrance.start()

        ParallelAnimation {
            id: cardEntrance
            NumberAnimation {
                target: loginCard
                property: "opacity"
                from: 0
                to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: loginCard
                property: "scale"
                from: 0.96
                to: 1
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.spatialDefault
            }
        }

        Column {
            id: loginColumn
            width: parent.width
            spacing: root.compactHeight ? 8 : 12

            RoundedAvatar {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.compactHeight ? 80 : 104
                height: width
                frameWidth: root.compactHeight ? 6 : 7
                ringWidth: 3
                source: root.cachedAvatar
                fallbackSource: root.selectedSystemAvatar
                fallbackText: root.selectedUser.length > 0
                    ? root.selectedUser.charAt(0).toUpperCase() : "V"
                accent: errorText.text === "Incorrect password" ? root.danger : root.accent
                foreground: root.accentSoftInk
                surface: root.accentSoft
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.selectedDisplayName || root.selectedUser
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sign in to Voidline"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: 13
                }
            }

            Item {
                width: parent.width
                height: root.compactHeight ? 2 : 6
            }

            Rectangle {
                id: passwordBox
                width: parent.width
                height: 64
                radius: height / 2
                color: passwordInput.activeFocus
                    ? Qt.lighter(root.surfaceRaised, 1.12) : root.surfaceRaised
                border.width: passwordInput.activeFocus || errorText.text === "Incorrect password" ? 2 : 0
                border.color: errorText.text === "Incorrect password" ? root.danger : root.accent

                transform: Translate { id: shakeOffset }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 50; easing.type: Easing.OutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: 8; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: -5; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation {
                        target: shakeOffset; property: "x"; to: 0; duration: 350
                        easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialFast
                    }
                }

                Behavior on color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: passwordInput
                    anchors {
                        fill: parent
                        leftMargin: 24
                        rightMargin: showPasswordButton.width + signInButton.width + 24
                    }
                    enabled: !root.loginBusy
                    echoMode: showPasswordButton.checked
                        ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: root.foreground
                    selectionColor: root.accent
                    selectedTextColor: root.accentInk
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    Keys.onReturnPressed: root.attemptLogin()
                    Keys.onEnterPressed: root.attemptLogin()

                    Text {
                        anchors.fill: parent
                        text: root.loginBusy ? "Signing in…" : "Password"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        visible: passwordInput.text.length === 0
                    }
                }

                VoidButton {
                    id: showPasswordButton
                    property bool checked: false
                    anchors {
                        right: signInButton.left
                        rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    width: 44
                    height: 44
                    label: ""
                    symbol: checked ? "visibility_off" : "visibility"
                    flat: true
                    accent: root.muted
                    foreground: root.foreground
                    enabled: !root.loginBusy
                    onClicked: checked = !checked
                }

                VoidButton {
                    id: signInButton
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: 48
                    height: 48
                    label: ""
                    symbol: root.loginBusy ? "progress_activity" : "arrow_forward"
                    primary: true
                    // Morphs to a rounded square while the session starts.
                    cornerRadius: root.loginBusy ? 16 : height / 2
                    enabled: !root.loginBusy
                        && root.selectedUser.length > 0
                        && passwordInput.text.length > 0
                    accent: root.accent
                    accentInk: root.accentInk
                    foreground: root.foreground
                    onClicked: root.attemptLogin()
                }
            }

            Item {
                width: parent.width
                height: 20

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 24
                        verticalCenter: parent.verticalCenter
                    }
                    text: keyboard.capsLock ? "Caps Lock is on" : ""
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Text {
                    id: errorText
                    anchors {
                        right: parent.right
                        rightMargin: 24
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    color: root.loginBusy ? root.muted : root.danger
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                id: sessionButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, sessionRow.implicitWidth + 40)
                height: 44
                radius: sessionMouse.pressed ? 12 : height / 2
                color: root.sessionMenuOpen ? root.accentSoft
                    : (sessionMouse.containsMouse || sessionButton.activeFocus
                        ? Qt.lighter(root.surface, 1.22) : root.surface)
                activeFocusOnTab: true

                Behavior on radius {
                    NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialFast }
                }
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: sessionRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "desktop_windows"
                        color: root.sessionMenuOpen ? root.accentSoftInk : root.accent
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, loginCard.width - 110)
                        text: root.sessionName
                        color: root.sessionMenuOpen ? root.accentSoftInk : root.foreground
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sessionMenuOpen
                            ? "keyboard_arrow_down" : "keyboard_arrow_up"
                        color: root.sessionMenuOpen ? root.accentSoftInk : root.muted
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                    }
                }

                MouseArea {
                    id: sessionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.sessionMenuOpen = !root.sessionMenuOpen
                        sessionButton.forceActiveFocus()
                    }
                }
                Keys.onSpacePressed:
                    root.sessionMenuOpen = !root.sessionMenuOpen
                Keys.onReturnPressed:
                    root.sessionMenuOpen = !root.sessionMenuOpen
            }
        }

        Rectangle {
            id: sessionMenu
            z: 8
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: sessionButton.height + 8
            }
            width: Math.min(parent.width, 320)
            height: root.sessionMenuOpen
                ? Math.min(240, Math.max(56, sessionList.contentHeight + 16))
                : 0
            opacity: root.sessionMenuOpen ? 1 : 0
            visible: height > 0
            radius: 24
            color: root.panel
            clip: true

            ListView {
                id: sessionList
                anchors {
                    fill: parent
                    margins: 8
                }
                model: sessionModel
                currentIndex: root.sessionIndex
                spacing: 2
                clip: true

                delegate: Rectangle {
                    readonly property bool isSelected: index === root.sessionIndex
                    width: sessionList.width
                    height: 48
                    radius: isSelected ? height / 2 : 14
                    color: isSelected
                        ? root.accentSoft
                        : (sessionItemMouse.containsMouse
                            ? root.surfaceRaised : "transparent")

                    Behavior on radius {
                        NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialFast }
                    }

                    Text {
                        anchors {
                            fill: parent
                            leftMargin: 18
                            rightMargin: 44
                        }
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: name
                        color: parent.isSelected ? root.accentSoftInk : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.weight: parent.isSelected ? Font.Bold : Font.Medium
                    }
                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        visible: parent.isSelected
                        text: "check"
                        color: root.accentSoftInk
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                    }
                    MouseArea {
                        id: sessionItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sessionIndex = index
                            root.sessionName = name
                            root.sessionMenuOpen = false
                            passwordInput.forceActiveFocus()
                        }
                    }
                    Component.onCompleted: {
                        if (index === root.sessionIndex)
                            root.sessionName = name
                    }
                }
            }

            Behavior on height {
                NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialDefault }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }

    // Material 3 Expressive button group for power actions.
    Row {
        id: powerRow
        anchors {
            horizontalCenter: root.pixelLayout ? undefined : parent.horizontalCenter
            right: root.pixelLayout ? parent.right : undefined
            rightMargin: 40
            bottom: parent.bottom
            bottomMargin: root.pixelLayout ? 40 : (root.compactHeight ? 20 : 32)
        }
        height: root.pixelLayout ? 56 : 48
        spacing: root.pixelLayout ? 12 : 6

        VoidButton {
            visible: sddm.canSuspend
            width: root.pixelLayout ? parent.height : 124
            height: parent.height
            label: root.pixelLayout ? "" : "Suspend"
            symbol: "bedtime"
            accent: root.accent
            foreground: root.foreground
            surface: root.surface
            onClicked: sddm.suspend()
        }
        VoidButton {
            visible: sddm.canHibernate
            width: root.pixelLayout ? parent.height : 134
            height: parent.height
            label: root.pixelLayout ? "" : "Hibernate"
            symbol: "mode_standby"
            accent: root.accent
            foreground: root.foreground
            surface: root.surface
            onClicked: root.requestPower("hibernate", "hibernate")
        }
        VoidButton {
            width: root.pixelLayout ? parent.height : 120
            height: parent.height
            label: root.pixelLayout ? "" : "Restart"
            symbol: "restart_alt"
            accent: root.accent
            foreground: root.foreground
            surface: root.surface
            onClicked: root.requestPower("reboot", "restart")
        }
        VoidButton {
            width: root.pixelLayout ? parent.height : 134
            height: parent.height
            label: root.pixelLayout ? "" : "Power off"
            symbol: "power_settings_new"
            destructive: true
            danger: root.danger
            dangerContainer: root.dangerContainer
            dangerInk: root.dangerInk
            onClicked: root.requestPower("power", "power off")
        }
    }

    // Material 3 dialog: scrim, 28px container, icon, headline, supporting
    // text, and end-aligned actions.
    Rectangle {
        z: 40
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.confirmOpen ? 1 : 0
        color: Qt.rgba(0, 0, 0, 0.56)

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(360, parent.width - 40)
            height: dialogColumn.implicitHeight + 48
            radius: 28
            color: root.panel
            scale: root.confirmOpen ? 1 : 0.9

            Behavior on scale {
                NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spatialDefault }
            }

            Column {
                id: dialogColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 24
                }
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.pendingPowerAction === "reboot"
                        ? "restart_alt"
                        : (root.pendingPowerAction === "hibernate"
                            ? "mode_standby" : "power_settings_new")
                    color: root.danger
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 28
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Ready to " + root.pendingPowerLabel + "?"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Any unsaved work may be lost."
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: 14
                }
                Item {
                    width: parent.width
                    height: 8
                }
                Row {
                    anchors.right: parent.right
                    height: 44
                    spacing: 8

                    VoidButton {
                        width: 96
                        height: parent.height
                        label: "Cancel"
                        flat: true
                        accent: root.accent
                        foreground: root.foreground
                        onClicked: {
                            root.confirmOpen = false
                            passwordInput.forceActiveFocus()
                        }
                    }
                    VoidButton {
                        id: confirmButton
                        width: 112
                        height: parent.height
                        label: "Continue"
                        destructive: true
                        danger: root.danger
                        dangerContainer: root.dangerContainer
                        dangerInk: root.dangerInk
                        onClicked: root.runPowerAction()
                    }
                }
            }
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.loginBusy = false
            passwordInput.text = ""
            errorText.text = "Incorrect password"
            shake.restart()
            passwordInput.forceActiveFocus()
        }

        function onLoginSucceeded() {
            errorText.text = "Starting session…"
        }

        function onInformationMessage(message) {
            if (message && String(message).length > 0)
                errorText.text = String(message)
        }

    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (userList.count > 0) {
                userList.currentIndex = Math.max(0,
                    Math.min(root.selectedUserIndex, userList.count - 1))
                userList.positionViewAtIndex(userList.currentIndex,
                    ListView.Contain)
            }
            passwordInput.forceActiveFocus()
        })
    }
}
