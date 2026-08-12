import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root

    width: 1920
    height: 1080
    property color background: config.backgroundColor || "#141218"
    color: background
    focus: true
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(root.background, 1.16) }
        GradientStop { position: 0.52; color: root.background }
        GradientStop { position: 1.0; color: Qt.lighter(root.background, 1.08) }
    }

    property string fontFamily: config.fontFamily || "Roboto Flex"
    property int clockWeight: 760
    property string clockStyle: "digital-large"
    property color clockColor: foreground
    property color accent: config.accentColor || "#8FB8AC"
    property color accentSoft: config.accentSoftColor || "#3F6C64"
    property color panel: config.panelColor || "#211F26"
    property color surface: config.surfaceColor || "#252229"
    property color surfaceRaised: config.raisedSurfaceColor || "#302D34"
    property color foreground: config.textColor || "#F1F5F3"
    property color muted: config.mutedTextColor || "#B8C4C0"
    property color outline: config.outlineColor || "#6572817C"
    property color danger: config.dangerColor || "#F2B8B5"
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
            const styles = ["digital-large", "digital-compact", "stacked",
                "horizontal", "minimal", "playful"]
            clockStyle = styles.indexOf(values.clockStyle) >= 0
                ? values.clockStyle : "digital-large"
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

    Rectangle {
        anchors.fill: parent
        color: "#52060B0C"
    }

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            margins: 24
        }
        width: hostRow.width + 28
        height: 38
        radius: 14
        color: root.panel
        border.width: 1
        border.color: root.outline

        Row {
            id: hostRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "desktop_windows"
                color: root.accent
                font.family: "Material Symbols Rounded"
                font.pixelSize: 17
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sddm.hostName
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 11
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
        width: Math.min(260, Math.max(164, userControlRow.implicitWidth + 28))
        height: 46
        radius: 16
        color: root.userMenuOpen ? root.surfaceRaised : root.panel
        border.width: 1
        border.color: root.userMenuOpen ? root.accent : root.outline

        Row {
            id: userControlRow
            anchors.centerIn: parent
            spacing: 9

            RoundedAvatar {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                cornerRadius: 10
                frameWidth: 2
                source: root.cachedAvatar
                fallbackSource: root.selectedSystemAvatar
                fallbackText: root.selectedUser.length > 0
                    ? root.selectedUser.charAt(0).toUpperCase() : "V"
                accent: root.accent
                foreground: root.foreground
                surface: root.surfaceRaised
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(150, implicitWidth)
                text: root.selectedDisplayName || root.selectedUser
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: userList.count > 1
                text: root.userMenuOpen ? "expand_less" : "expand_more"
                color: root.muted
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: userList.count > 1
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.userMenuOpen = !root.userMenuOpen
        }
    }

    Rectangle {
        id: userMenu
        anchors {
            top: userControl.bottom
            right: userControl.right
            topMargin: 8
        }
        z: 29
        width: 280
        height: root.userMenuOpen
            ? Math.min(310, userList.contentHeight + 16) : 0
        radius: 20
        color: root.panel
        border.width: 1
        border.color: root.outline
        clip: true
        opacity: root.userMenuOpen ? 1 : 0
        scale: root.userMenuOpen ? 1 : 0.97

        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            clip: true
            model: userModel
            currentIndex: root.selectedUserIndex

            delegate: Rectangle {
                width: userList.width
                height: 54
                radius: 15
                color: root.selectedUser === name
                    ? root.accentSoft : userItemMouse.containsMouse
                        ? root.surfaceRaised : "transparent"
                border.width: root.selectedUser === name ? 1 : 0
                border.color: root.accent

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 10
                    RoundedAvatar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        cornerRadius: 12
                        frameWidth: 2
                        source: "file:///var/tmp/voidline-sddm-" + name + ".avatar.png"
                        fallbackSource: icon
                        fallbackText: name.length > 0 ? name.charAt(0).toUpperCase() : "V"
                        accent: root.accent
                        foreground: root.foreground
                        surface: root.surfaceRaised
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 56
                        text: realName && realName.length > 0 ? realName : name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
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

        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Column {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.compactHeight ? 28
                : Math.max(48, parent.height * 0.065)
        }
        spacing: -7

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
                ? (root.clockStyle === "minimal" ? 46 : 58)
                : Math.max(58, Math.min(root.clockStyle === "minimal" ? 84 : 108,
                    root.height * (root.clockStyle === "minimal" ? 0.082 : 0.105)))
            font.weight: root.clockStyle === "minimal"
                ? Font.Medium : root.clockWeight
            font.letterSpacing: root.clockStyle === "minimal" ? 0 : -2
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.78
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        id: loginCard
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: root.compactHeight ? 28 : 88
        }
        width: Math.min(470, parent.width - 48)
        height: root.compactHeight ? 314 : 374
        radius: root.shapeRadius
        color: root.panel
        border.width: 1
        border.color: root.outline
        opacity: 0
        scale: 0.985

        Component.onCompleted: cardEntrance.start()

        ParallelAnimation {
            id: cardEntrance
            NumberAnimation {
                target: loginCard
                property: "opacity"
                from: 0
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: loginCard
                property: "scale"
                from: 0.985
                to: 1
                duration: 300
                easing.type: Easing.OutQuart
            }
        }

        Column {
            anchors {
                fill: parent
                margins: 22
            }
            spacing: root.compactHeight ? 6 : 12

            RoundedAvatar {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.compactHeight ? 72 : 104
                height: width
                cornerRadius: root.compactHeight ? 25 : 34
                frameWidth: root.compactHeight ? 4 : 5
                source: root.cachedAvatar
                fallbackSource: root.selectedSystemAvatar
                fallbackText: root.selectedUser.length > 0
                    ? root.selectedUser.charAt(0).toUpperCase() : "V"
                accent: root.accent
                foreground: root.foreground
                surface: root.surfaceRaised
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 1

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 34
                    source: "assets/voidline.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.selectedDisplayName || root.selectedUser
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sign in to Voidline"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle {
                id: passwordBox
                width: parent.width
                height: 54
                radius: 17
                color: passwordInput.activeFocus
                    ? root.surfaceRaised : root.surface
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus
                    ? root.accent : root.outline

                TextInput {
                    id: passwordInput
                    anchors {
                        fill: parent
                        leftMargin: 17
                        rightMargin: showPasswordButton.width + 14
                    }
                    enabled: !root.loginBusy
                    echoMode: showPasswordButton.checked
                        ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: root.foreground
                    selectionColor: root.accent
                    selectedTextColor: "#14201E"
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    Keys.onReturnPressed: root.attemptLogin()
                    Keys.onEnterPressed: root.attemptLogin()

                    Text {
                        anchors.fill: parent
                        text: root.loginBusy ? "Signing in…" : "Password"
                        color: root.muted
                        font: passwordInput.font
                        verticalAlignment: Text.AlignVCenter
                        visible: passwordInput.text.length === 0
                    }
                }

                VoidButton {
                    id: showPasswordButton
                    property bool checked: false
                    anchors {
                        right: parent.right
                        rightMargin: 7
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    height: 40
                    cornerRadius: 13
                    label: ""
                    symbol: checked ? "visibility_off" : "visibility"
                    accent: root.accent
                    foreground: root.foreground
                    muted: root.muted
                    surface: "transparent"
                    outline: "transparent"
                    enabled: !root.loginBusy
                    onClicked: checked = !checked
                }
            }

            Row {
                width: parent.width
                height: 18

                Text {
                    width: parent.width / 2
                    text: keyboard.capsLock ? "Caps Lock is on" : ""
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: 10
                }
                Text {
                    id: errorText
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    color: root.loginBusy ? root.muted : root.danger
                    font.family: root.fontFamily
                    font.pixelSize: 10
                }
            }

            Row {
                width: parent.width
                height: 48
                spacing: 8

                Rectangle {
                    id: sessionButton
                    width: parent.width * 0.42
                    height: parent.height
                    radius: 15
                    color: sessionMouse.containsMouse
                        || sessionButton.activeFocus
                        ? "#5272817C" : root.surface
                    border.width: 1
                    border.color: root.outline
                    activeFocusOnTab: true

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 13
                            rightMargin: 11
                        }
                        spacing: 7

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "desktop_windows"
                            color: root.accent
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 17
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 53
                            text: root.sessionName
                            color: root.foreground
                            elide: Text.ElideRight
                            font.family: root.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.sessionMenuOpen
                                ? "keyboard_arrow_down" : "keyboard_arrow_up"
                            color: root.muted
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 17
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

                VoidButton {
                    width: parent.width - sessionButton.width - parent.spacing
                    height: parent.height
                    label: root.loginBusy ? "Signing in…" : "Sign in"
                    symbol: root.loginBusy ? "progress_activity" : "arrow_forward"
                    primary: true
                    enabled: !root.loginBusy
                        && root.selectedUser.length > 0
                        && passwordInput.text.length > 0
                    cornerRadius: 15
                    accent: root.accent
                    foreground: root.foreground
                    muted: root.muted
                    surface: root.surface
                    outline: root.outline
                    onClicked: root.attemptLogin()
                }
            }
        }

        Rectangle {
            id: sessionMenu
            z: 8
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 22
                rightMargin: 22
                bottomMargin: 78
            }
            height: root.sessionMenuOpen
                ? Math.min(222, Math.max(50, sessionList.contentHeight + 12))
                : 0
            opacity: root.sessionMenuOpen ? 1 : 0
            visible: height > 0
            radius: 18
            color: "#FC25302F"
            border.width: 1
            border.color: root.outline
            clip: true

            ListView {
                id: sessionList
                anchors {
                    fill: parent
                    margins: 6
                }
                model: sessionModel
                currentIndex: root.sessionIndex
                spacing: 3
                clip: true

                delegate: Rectangle {
                    width: sessionList.width
                    height: 44
                    radius: 13
                    color: index === root.sessionIndex
                        ? root.accentSoft
                        : (sessionItemMouse.containsMouse
                            ? "#5272817C" : "transparent")

                    Text {
                        anchors {
                            fill: parent
                            leftMargin: 13
                            rightMargin: 13
                        }
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        font.weight: index === root.sessionIndex
                            ? Font.Bold : Font.Medium
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
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }
    }

    Row {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 28
        }
        height: 42
        spacing: 8

        VoidButton {
            visible: sddm.canSuspend
            width: 116
            height: parent.height
            label: "Suspend"
            symbol: "bedtime"
            cornerRadius: 14
            accent: root.accent
            foreground: root.foreground
            muted: root.muted
            surface: "#C925302F"
            outline: root.outline
            onClicked: sddm.suspend()
        }
        VoidButton {
            visible: sddm.canHibernate
            width: 122
            height: parent.height
            label: "Hibernate"
            symbol: "mode_standby"
            cornerRadius: 14
            accent: root.accent
            foreground: root.foreground
            muted: root.muted
            surface: "#C925302F"
            outline: root.outline
            onClicked: root.requestPower("hibernate", "hibernate")
        }
        VoidButton {
            width: 110
            height: parent.height
            label: "Restart"
            symbol: "restart_alt"
            cornerRadius: 14
            accent: root.accent
            foreground: root.foreground
            muted: root.muted
            surface: "#C925302F"
            outline: root.outline
            onClicked: root.requestPower("reboot", "restart")
        }
        VoidButton {
            width: 124
            height: parent.height
            label: "Power off"
            symbol: "power_settings_new"
            destructive: true
            cornerRadius: 14
            accent: root.accent
            foreground: root.foreground
            muted: root.muted
            surface: "#C925302F"
            outline: root.outline
            onClicked: root.requestPower("power", "power off")
        }
    }

    Rectangle {
        z: 20
        anchors.fill: parent
        visible: root.confirmOpen
        color: "#82060B0C"

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(388, parent.width - 40)
            height: 224
            radius: root.shapeRadius
            color: root.panel
            border.width: 1
            border.color: root.outline

            Column {
                anchors {
                    fill: parent
                    margins: 22
                }
                spacing: 12

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52
                    height: 52
                    radius: 18
                    color: "#40D56562"

                    Text {
                        anchors.centerIn: parent
                        text: root.pendingPowerAction === "reboot"
                            ? "restart_alt"
                            : (root.pendingPowerAction === "hibernate"
                                ? "mode_standby" : "power_settings_new")
                        color: root.danger
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 25
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Ready to " + root.pendingPowerLabel + "?"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Any unsaved work may be lost."
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: 11
                }
                Row {
                    width: parent.width
                    height: 44
                    spacing: 8

                    VoidButton {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        label: "Cancel"
                        cornerRadius: 14
                        accent: root.accent
                        foreground: root.foreground
                        muted: root.muted
                        surface: root.surface
                        outline: root.outline
                        onClicked: {
                            root.confirmOpen = false
                            passwordInput.forceActiveFocus()
                        }
                    }
                    VoidButton {
                        id: confirmButton
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        label: "Continue"
                        destructive: true
                        cornerRadius: 14
                        accent: root.accent
                        foreground: root.foreground
                        muted: root.muted
                        surface: "#40D56562"
                        outline: "#80D56562"
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
