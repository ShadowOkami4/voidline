import Quickshell
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18

    property string section: "notifications"
    property int versionTaps: 0
    property string message: ""
    // Lock screen: advanced clock typography stays folded away by default.
    property bool lockClockAdvanced: false
    property string pendingAvatarSource: ""
    property real avatarZoom: 1
    property real avatarOffsetX: 0
    property real avatarOffsetY: 0

    onSectionChanged: {
        if (section === "security")
            SecurityService.refresh()
        else if (section === "updates" && UpdateService.stage === "Not checked")
            UpdateService.check()
        else if (section === "developer")
            DiagnosticsService.refresh()
    }

    function localPath(url) {
        const value = String(url || "")
        return decodeURIComponent(value.replace(/^file:\/\//, ""))
    }

    function beginAvatarCrop(path) {
        pendingAvatarSource = String(path || "")
        avatarZoom = 1
        avatarOffsetX = 0
        avatarOffsetY = 0
    }

    function tapVersion() {
        if (Appearance.developerMode) {
            message = I18n.tr("settings.about.developerAlreadyEnabled")
        } else {
            versionTaps++
            const remaining = 7 - versionTaps
            if (remaining <= 0) {
                Appearance.setDeveloperMode(true)
                message = I18n.tr("settings.about.developerEnabled")
                versionTaps = 0
            }
        }
        if (message.length > 0)
            messageTimer.restart()
    }

    FileDialog {
        id: avatarPicker
        title: I18n.tr("settings.about.chooseProfilePicture")
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: root.beginAvatarCrop(root.localPath(selectedFile))
    }

    Timer {
        id: messageTimer
        interval: 2200
        onTriggered: root.message = ""
    }

    SettingsSection {
        visible: root.section === "notifications"
        title: "Notification behavior"
        subtitle: "Voidline receives and stores desktop notifications directly"
        icon: "notifications"

        SettingsToggle {
            width: parent.width
            icon: "notification_important"
            title: "Popup notifications"
            subtitle: "Show new notifications in the top-right connected popup"
            checked: Appearance.notificationPopups
            onToggled: value => Appearance.setNotificationPopups(value)
        }
        SettingsAction {
            width: parent.width
            icon: "notifications_active"
            title: "Notification center"
            subtitle: NotificationService.count + " notifications in history"
            value: "Open"
            onClicked: ShellState.openControlCenter("")
        }
        SettingsAction {
            width: parent.width
            icon: "delete_sweep"
            title: "Clear history"
            subtitle: "Dismiss all stored notifications"
            enabled: NotificationService.count > 0
            onClicked: NotificationService.clearAll()
        }
    }

    // ---------------- Lock screen ----------------
    SettingsSection {
        visible: root.section === "lock"
        fullWidth: true
        title: "Preview"
        icon: "lock"

        Rectangle {
            id: clockEditor
            readonly property real safeMargin: Metrics.spaceM
            readonly property real safeWidth: width - safeMargin * 2
            readonly property real previewAuthHeight: Math.round(66 * Metrics.scale)
            readonly property real previewAuthBottom: safeMargin
            readonly property real safeBottom: height - previewAuthBottom
                - previewAuthHeight - safeMargin
            readonly property real safeHeight: Math.max(1, safeBottom - safeMargin)
            x: Metrics.spaceXL
            width: parent.width - Metrics.spaceXL * 2
            height: Math.max(260, Math.min(380, width * 0.56))
            radius: Theme.radiusLarge
            color: Theme.surfaceLow
            clip: true

            Image {
                anchors.fill: parent
                source: Appearance.wallpaperPath.length > 0
                    ? "file://" + Appearance.wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                opacity: 0.72
            }
            Rectangle {
                anchors.fill: parent
                color: "#66141218"
            }

            LockClock {
                id: clockPreview
                width: Math.min(400, clockEditor.width * 0.58)
                height: Math.min(170, clockEditor.height * 0.44)
                x: clockEditor.safeMargin
                    + Math.max(0, clockEditor.safeWidth - width)
                        * Appearance.lockClockX
                y: clockEditor.safeMargin
                    + Math.max(0, clockEditor.safeHeight - height)
                        * Appearance.lockClockY
                date: new Date()
                preview: true
                clockScale: Appearance.lockClockSize * 0.62

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.OpenHandCursor
                    drag.target: clockPreview
                    drag.minimumX: clockEditor.safeMargin
                    drag.maximumX: clockEditor.width - clockPreview.width
                        - clockEditor.safeMargin
                    drag.minimumY: clockEditor.safeMargin
                    drag.maximumY: clockEditor.safeBottom - clockPreview.height
                    onPressed: cursorShape = Qt.ClosedHandCursor
                    onReleased: {
                        cursorShape = Qt.OpenHandCursor
                        Appearance.setLockClockPosition(
                            (clockPreview.x - clockEditor.safeMargin)
                                / Math.max(1, clockEditor.safeWidth
                                    - clockPreview.width),
                            (clockPreview.y - clockEditor.safeMargin)
                                / Math.max(1, clockEditor.safeHeight
                                    - clockPreview.height))
                    }
                }
            }

            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    margins: Metrics.spaceM
                }
                width: Math.min(Math.round(260 * Metrics.scale), parent.width * 0.54)
                height: clockEditor.previewAuthHeight
                radius: Metrics.radiusL
                color: Theme.withAlpha(Theme.panelRaised, 0.9)

                RoundedImage {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: Metrics.spaceS
                    }
                    width: Math.round(48 * Metrics.scale)
                    height: width
                    radius: Metrics.tileRadius
                    source: ProfileImageService.avatarSource
                    fallbackIcon: "person"
                    fallbackColor: Theme.groupSurfaceRaised
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: Math.round(66 * Metrics.scale)
                        rightMargin: Metrics.spaceM
                        bottomMargin: Metrics.spaceS
                    }
                    height: Math.round(18 * Metrics.scale)
                    radius: Metrics.pillRadius
                    color: Theme.surfaceLow
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 12
                }
                width: editorHint.implicitWidth + 20
                height: 32
                radius: Theme.pillRadius
                color: Theme.withAlpha(Theme.panelRaised, 0.9)
                Text {
                    id: editorHint
                    anchors.centerIn: parent
                    text: "Drag the clock to reposition it"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }

        ClockStylePicker {
            width: parent.width
            title: "Clock style"
            maxColumns: 4
            options: ["pixel", "digital-large", "digital-compact", "stacked",
                "horizontal", "minimal", "analog", "playful"]
            optionLabels: ["Pixel", "Large digital", "Digital with date", "Stacked",
                "Horizontal", "Minimal", "Analog", "Playful"]
            value: Appearance.lockClockStyle
            onSelected: value => Appearance.setLockClockStyle(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Color"
            options: ["wallpaper", "custom", "gradient"]
            optionLabels: ["Wallpaper", "Custom", "Two-tone"]
            value: Appearance.lockClockColorMode
            onSelected: value => Appearance.setLockClockColorMode(value)
        }
        SettingsField {
            width: parent.width
            visible: Appearance.lockClockColorMode !== "wallpaper"
            icon: "palette"
            title: "Primary color"
            subtitle: "Hex color such as #FFFFFF"
            value: Appearance.lockClockColor1
            onAccepted: value => Appearance.setLockClockColors(
                value, Appearance.lockClockColor2)
        }
        SettingsField {
            width: parent.width
            visible: Appearance.lockClockColorMode === "gradient"
            icon: "gradient"
            title: "Secondary color"
            subtitle: "Used for the date, weather, and analog minute hand"
            value: Appearance.lockClockColor2
            onAccepted: value => Appearance.setLockClockColors(
                Appearance.lockClockColor1, value)
        }
        SettingsChoice {
            width: parent.width
            title: "Date"
            options: ["above", "below", "side", "hidden"]
            optionLabels: ["Above", "Below", "Beside", "Hidden"]
            value: Appearance.lockDatePlacement
            onSelected: value => Appearance.setLockDatePlacement(value)
        }
        SettingsAction {
            width: parent.width
            icon: root.lockClockAdvanced ? "expand_less" : "tune"
            title: root.lockClockAdvanced ? "Fewer clock options" : "Customize clock"
            subtitle: root.lockClockAdvanced ? "" : "Font, weight, size, and spacing"
            onClicked: root.lockClockAdvanced = !root.lockClockAdvanced
        }
        SettingsChoice {
            width: parent.width
            visible: root.lockClockAdvanced
            title: "Clock font"
            options: ["Roboto Flex", "Noto Sans", "sans-serif", "serif",
                "monospace", "Comic Sans MS"]
            optionLabels: ["Roboto Flex", "Noto Sans", "System Sans",
                "Serif", "Monospace", "Playful"]
            value: Appearance.lockClockFont
            onSelected: value => Appearance.setLockClockFont(value)
        }
        SettingsSlider {
            width: parent.width
            visible: root.lockClockAdvanced
            title: "Font weight"
            icon: "format_bold"
            from: 100; to: 900; step: 50
            value: Appearance.lockClockWeight
            onChanged: value => Appearance.setLockClockWeight(value)
        }
        SettingsSlider {
            width: parent.width
            visible: root.lockClockAdvanced
            title: "Clock size"
            icon: "format_size"
            from: 65; to: 160; step: 5
            value: Appearance.lockClockSize * 100
            suffix: "%"
            onChanged: value => Appearance.setLockClockSize(value / 100)
        }
        SettingsSlider {
            width: parent.width
            visible: root.lockClockAdvanced
            title: "Character spacing"
            icon: "format_letter_spacing"
            from: -6; to: 12; step: 0.5
            value: Appearance.lockClockSpacing
            onChanged: value => Appearance.setLockClockSpacing(value)
        }
        SettingsAction {
            width: parent.width
            visible: root.lockClockAdvanced
            icon: "restart_alt"
            title: "Reset clock design"
            subtitle: "Restore the default style, colors, and position"
            value: "Reset"
            onClicked: Appearance.resetLockClock()
        }
    }

    SettingsSection {
        visible: root.section === "lock"
        title: "Weather"
        icon: "partly_cloudy_day"

        SettingsField {
            width: parent.width
            icon: "location_on"
            title: "Location"
            subtitle: "Only this manually entered location is sent to Open-Meteo"
            value: Appearance.weatherLocation
            placeholder: "For example, Berlin"
            onAccepted: value => WeatherService.setLocation(value)
        }
        SettingsToggle {
            width: parent.width
            icon: "partly_cloudy_day"
            title: "Show weather"
            subtitle: Appearance.weatherLocation.length > 0
                ? Appearance.weatherLocation : "Choose a weather location first"
            checked: Appearance.lockShowWeather
            enabled: Appearance.weatherLocation.length > 0
            onToggled: value => Appearance.setLockShowWeather(value)
        }
        SettingsToggle {
            width: parent.width
            visible: Appearance.lockShowWeather
            icon: "thermostat"
            title: I18n.tr("lock.weatherTemperature")
            checked: Appearance.lockShowWeatherTemperature
            onToggled: value => Appearance.setLockWeatherPart("temperature", value)
        }
        SettingsToggle {
            width: parent.width
            visible: Appearance.lockShowWeather
            icon: "partly_cloudy_day"
            title: I18n.tr("lock.weatherCondition")
            checked: Appearance.lockShowWeatherCondition
            onToggled: value => Appearance.setLockWeatherPart("condition", value)
        }
        SettingsToggle {
            width: parent.width
            visible: Appearance.lockShowWeather
            icon: "cloud"
            title: I18n.tr("lock.weatherIcon")
            checked: Appearance.lockShowWeatherIcon
            onToggled: value => Appearance.setLockWeatherPart("icon", value)
        }
        SettingsToggle {
            width: parent.width
            visible: Appearance.lockShowWeather
            icon: "calendar_view_week"
            title: I18n.tr("lock.weatherForecast")
            checked: Appearance.lockShowWeatherForecast
            onToggled: value => Appearance.setLockWeatherPart("forecast", value)
        }
    }

    SettingsSection {
        visible: root.section === "lock"
        title: "Screen lock"
        icon: "lock_clock"

        SettingsChoice {
            width: parent.width
            title: "Lock after inactivity"
            maxColumns: 5
            options: ["60", "300", "600", "900", "1800"]
            optionLabels: ["1 min", "5 min", "10 min", "15 min", "30 min"]
            value: String(SecurityService.lockTimeout)
            enabled: !SecurityService.changing
            onSelected: value => SecurityService.setLockTimeout(Number(value))
        }
        SettingsAction {
            width: parent.width
            icon: "lock"
            title: "Lock now"
            value: "Lock"
            onClicked: LockService.lock()
        }
        SettingsAction {
            width: parent.width
            // Only worth mentioning while the SDDM copy is out of date.
            visible: !WallpaperService.sddmCacheReady
            icon: "wallpaper"
            title: "Login background"
            subtitle: "Waiting to export the wallpaper for the login screen"
            value: "Pending"
            interactive: false
        }
    }

    // ---------------- Security & privacy ----------------
    SettingsSection {
        visible: root.section === "security"
        title: "Device protection"
        icon: "shield"

        SettingsToggle {
            width: parent.width
            icon: "local_fire_department"
            title: "Firewall"
            subtitle: SecurityService.firewallAvailable
                ? SecurityService.firewallBackend + " · " + SecurityService.firewallStatus
                : "No supported firewall service was detected"
            checked: SecurityService.firewallEnabled
            enabled: SecurityService.firewallAvailable && !SecurityService.changing
            onToggled: SecurityService.requestFirewallToggle()
        }
        SettingsAction {
            width: parent.width
            visible: SecurityService.firewallConfirmation
            icon: "warning"
            title: SecurityService.firewallEnabled ? "Turn off firewall?" : "Turn on firewall?"
            subtitle: "This changes network filtering for the whole computer and requires authentication"
            value: "Confirm"
            onClicked: SecurityService.confirmFirewallToggle()
        }
        SettingsAction {
            width: parent.width
            icon: "verified"
            title: "Secure Boot"
            subtitle: "Firmware verification state"
            value: SecurityService.secureBootStatus
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "encrypted"
            title: "Disk encryption"
            subtitle: SecurityService.rootDevice
            value: SecurityService.encryptionStatus
            interactive: false
        }
        SettingsAction {
            width: parent.width
            visible: SecurityService.error.length > 0
            icon: "error"
            title: "Security setting failed"
            subtitle: SecurityService.error
            enabled: false
        }
    }

    SettingsSection {
        visible: root.section === "security"
        title: "Sign-in and sessions"
        icon: "verified_user"

        SettingsAction {
            width: parent.width
            icon: "verified_user"
            title: "Session authentication"
            subtitle: "The lock screen authenticates through the system PAM stack"
            value: "Protected"
            active: true
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "admin_panel_settings"
            title: "Policy authorization"
            subtitle: "Voidline handles Polkit requests without storing passwords"
            value: PolkitService.registered ? "Ready" : "Unavailable"
            active: PolkitService.registered
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "group"
            title: "Active user sessions"
            subtitle: "Local and remote sessions currently known to logind"
            value: String(SecurityService.activeSessions)
            interactive: false
        }
    }

    SettingsSection {
        visible: root.section === "accessibility"
        title: "Screen reader and keyboard"
        icon: "record_voice_over"

        SettingsAction {
            width: parent.width
            icon: "record_voice_over"
            title: "Screen reader"
            subtitle: AccessibilityService.available("orca")
                ? "Start Orca screen reader" : "Install Orca to enable screen reading"
            value: "Open"
            enabled: AccessibilityService.available("orca")
            onClicked: AccessibilityService.launchReader()
        }
        SettingsAction {
            width: parent.width
            icon: "keyboard_alt"
            title: "On-screen keyboard"
            subtitle: AccessibilityService.available("wvkbd-mobintl")
                || AccessibilityService.available("onboard")
                ? "Open the installed virtual keyboard" : "Install wvkbd-mobintl or Onboard"
            value: "Open"
            enabled: AccessibilityService.available("wvkbd-mobintl")
                || AccessibilityService.available("onboard")
            onClicked: AccessibilityService.launchKeyboard()
        }
    }

    SettingsSection {
        visible: root.section === "accessibility"
        title: "Display and text"
        icon: "text_increase"

        SettingsSlider {
            width: parent.width
            title: "Text scaling"
            subtitle: "Increase text and essential control sizing"
            icon: "text_increase"
            from: 85; to: 160; step: 5
            value: Appearance.textScale * 100
            suffix: "%"
            onChanged: value => Appearance.setTextScale(value / 100)
        }
        SettingsToggle {
            width: parent.width
            icon: "contrast"
            title: "Higher contrast"
            subtitle: "Strengthen borders and surface separation"
            checked: Appearance.highContrast
            onToggled: value => Appearance.setHighContrast(value)
        }
        SettingsToggle {
            width: parent.width
            icon: "mouse"
            title: "Large pointer"
            subtitle: "Use a larger cursor across Hyprland applications"
            checked: Appearance.largePointer
            onToggled: value => Appearance.setLargePointer(value)
        }
        SettingsToggle {
            width: parent.width
            icon: "filter_center_focus"
            title: "Stronger focus indicators"
            subtitle: "Make focused and pointed controls easier to locate"
            checked: Appearance.focusIndicators
            onToggled: value => Appearance.setFocusIndicators(value)
        }
    }

    SettingsSection {
        visible: root.section === "accessibility"
        title: "Motion"
        icon: "animation"

        SettingsToggle {
            width: parent.width
            icon: "motion_photos_off"
            title: "Reduce motion"
            subtitle: "Replace shell transitions with immediate state changes"
            checked: Appearance.reduceMotion
            onToggled: value => Appearance.setReduceMotion(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Animation duration"
            subtitle: "Slow transitions down without changing their shape"
            options: ["0.75", "1", "1.5", "2"]
            optionLabels: ["Faster", "Standard", "Longer", "Longest"]
            value: String(Appearance.animationDurationScale)
            visible: !Appearance.reduceMotion
            onSelected: value => Appearance.setAnimationDurationScale(Number(value))
        }
    }

    SettingsSection {
        visible: root.section === "accessibility"
        title: "Keyboard"
        icon: "keyboard"

        SettingsToggle {
            width: parent.width
            icon: "keyboard"
            title: "Sticky keys"
            subtitle: "Press modifier keys one at a time"
            checked: AccessibilityService.states.sticky
            enabled: AccessibilityService.available("org.gnome.desktop.a11y.keyboard")
            onToggled: value => AccessibilityService.setFeature("sticky", value)
        }
        SettingsToggle {
            width: parent.width
            icon: "hourglass_top"
            title: "Slow keys"
            subtitle: "Require keys to be held briefly before accepting them"
            checked: AccessibilityService.states.slow
            enabled: AccessibilityService.available("org.gnome.desktop.a11y.keyboard")
            onToggled: value => AccessibilityService.setFeature("slow", value)
        }
        SettingsToggle {
            width: parent.width
            icon: "keyboard_hide"
            title: "Bounce keys"
            subtitle: "Ignore rapidly repeated key presses"
            checked: AccessibilityService.states.bounce
            enabled: AccessibilityService.available("org.gnome.desktop.a11y.keyboard")
            onToggled: value => AccessibilityService.setFeature("bounce", value)
        }
    }

    SettingsSection {
        visible: root.section === "accessibility"
        title: "Pointer and clicks"
        icon: "mouse"

        SettingsToggle {
            width: parent.width
            icon: "touch_app"
            title: "Click assistance"
            subtitle: "Trigger a secondary click by holding the primary button"
            checked: AccessibilityService.states.clickAssist
            enabled: AccessibilityService.available("org.gnome.desktop.a11y.mouse")
            onToggled: value => AccessibilityService.setFeature("click-assist", value)
        }
        SettingsToggle {
            width: parent.width
            icon: "my_location"
            title: "Dwell click"
            subtitle: "Click automatically when the pointer stops moving"
            checked: AccessibilityService.states.dwell
            enabled: AccessibilityService.available("org.gnome.desktop.a11y.mouse")
            onToggled: value => AccessibilityService.setFeature("dwell", value)
        }
    }

    SettingsSection {
        visible: root.section === "accessibility"
        title: "Hearing"
        icon: "hearing"

        SettingsToggle {
            width: parent.width
            icon: "flash_on"
            title: "Visual notification alerts"
            subtitle: "Use visible cues alongside notification sounds"
            checked: Appearance.visualAlerts
            onToggled: value => Appearance.setVisualAlerts(value)
        }
    }

    // Pixel "System update" layout: one status headline with a single
    // primary action; details follow below.
    SettingsSection {
        visible: root.section === "updates"
        fullWidth: true

        Item {
            id: updateHero
            readonly property int count: UpdateService.officialPackages.length
            readonly property bool busy: UpdateService.checking || UpdateService.installing
            width: parent.width
            height: updateActions.y + updateActions.height + Metrics.spaceS

            Rectangle {
                id: updateBadge
                x: Metrics.spaceXL
                y: Metrics.spaceL
                width: Math.round(72 * Metrics.scale)
                height: width
                // Morphs from a circle to a rounded square while working.
                radius: updateHero.busy ? Metrics.radiusL : width / 2
                color: updateHero.count > 0 ? Theme.accentContainer : Theme.surfaceContainerHigh
                Behavior on radius {
                    NumberAnimation {
                        duration: Motion.springDefault
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialDefault
                    }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    text: updateHero.busy ? "progress_activity"
                        : (updateHero.count > 0 ? "system_update" : "verified")
                    fill: 1
                    size: Math.round(36 * Metrics.scale)
                    color: updateHero.count > 0 ? Theme.accentContainerInk : Theme.accent
                }
            }

            Column {
                id: updateText
                anchors {
                    left: parent.left
                    leftMargin: Metrics.spaceXL
                    right: parent.right
                    rightMargin: Metrics.spaceXL
                    top: updateBadge.bottom
                    topMargin: Metrics.spaceL
                }
                spacing: Metrics.spaceXS

                Text {
                    width: parent.width
                    text: UpdateService.installing ? "Installing updates"
                        : (UpdateService.checking ? "Checking for updates"
                            : (updateHero.count > 0
                                ? updateHero.count + " updates available"
                                : "Your system is up to date"))
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(26 * Metrics.scale)
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: UpdateService.installing
                        ? Math.round(UpdateService.progress) + "% · " + UpdateService.stage
                        : UpdateService.stage
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextBody
                    elide: Text.ElideRight
                }
            }

            Row {
                id: updateActions
                anchors {
                    right: parent.right
                    rightMargin: Metrics.spaceXL
                }
                y: updateText.y + updateText.height + Metrics.spaceL
                spacing: Metrics.spaceS

                Rectangle {
                    width: checkLabel.implicitWidth + Metrics.spaceXL * 2
                    height: Math.round(44 * Metrics.scale)
                    radius: checkTap.pressed ? Metrics.radiusM : height / 2
                    color: checkHover.hovered ? Theme.surfaceHover : "transparent"
                    border.width: Metrics.border
                    border.color: Theme.outline
                    opacity: updateHero.busy ? 0.4 : 1
                    Text {
                        id: checkLabel
                        anchors.centerIn: parent
                        text: "Check again"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.appTextBody
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: checkHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: checkTap
                        enabled: !updateHero.busy
                        onTapped: UpdateService.check()
                    }
                }
                Rectangle {
                    visible: updateHero.count > 0
                    width: installLabel.implicitWidth + Metrics.spaceXL * 2
                    height: Math.round(44 * Metrics.scale)
                    radius: installTap.pressed ? Metrics.radiusM : height / 2
                    color: installHover.hovered ? Theme.accentStrong : Theme.accent
                    opacity: updateHero.busy ? 0.4 : 1
                    Text {
                        id: installLabel
                        anchors.centerIn: parent
                        text: "Install now"
                        color: Theme.accentInk
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.appTextBody
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: installHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: installTap
                        enabled: !updateHero.busy
                        onTapped: UpdateService.requestInstall()
                    }
                }
            }
        }

        SettingsAction {
            width: parent.width
            visible: UpdateService.confirmationPending
            icon: "warning"
            title: "Confirm system update"
            subtitle: "pacman will install every official repository update after Polkit authentication"
            value: "Install"
            active: true
            onClicked: UpdateService.confirmInstall()
        }
        SettingsAction {
            width: parent.width
            visible: UpdateService.confirmationPending
            icon: "close"
            title: "Cancel update"
            subtitle: "No packages have been changed"
            value: "Cancel"
            onClicked: UpdateService.cancelInstall()
        }
        SettingsAction {
            width: parent.width
            visible: UpdateService.error.length > 0
            icon: "error"
            title: "Update error"
            subtitle: UpdateService.error
            value: "Retry"
            onClicked: UpdateService.check()
        }
        SettingsAction {
            width: parent.width
            visible: UpdateService.restartRecommended
            icon: "restart_alt"
            title: "Restart may be required"
            subtitle: "A kernel or core system component is included in this update"
            value: "After update"
            enabled: false
        }
    }

    SettingsSection {
        visible: root.section === "updates" && UpdateService.packages.length > 0
        title: "Available packages"
        subtitle: UpdateService.officialPackages.length + " official · "
            + UpdateService.aurPackages.length + " AUR"
        icon: "package_2"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        Repeater {
            model: UpdateService.packages.slice(0, 40)
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: modelData.source === "aur" ? "construction" : "inventory_2"
                title: modelData.name
                subtitle: modelData.oldVersion + " → " + modelData.newVersion
                value: modelData.source === "aur" ? "AUR" : "Official"
                interactive: false
            }
        }
        SettingsAction {
            width: parent.width
            visible: UpdateService.aurPackages.length > 0
            icon: "info"
            title: "AUR packages are listed separately"
            subtitle: "Automated AUR installation stays disabled until a safe non-terminal build transaction backend is available"
            enabled: false
        }
    }

    SettingsSection {
        visible: root.section === "updates" && UpdateService.history.length > 0
        title: "Update history"
        subtitle: "The latest package transactions started by Voidline"
        icon: "history"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        Repeater {
            model: UpdateService.history.slice(0, 10)
            SettingsAction {
                required property var modelData
                width: parent.width
                icon: modelData.success ? "check_circle" : "error"
                title: UpdateService.historyLabel(modelData)
                subtitle: modelData.detail
                value: modelData.packages + " packages"
                active: modelData.success
                enabled: false
            }
        }
    }

    SettingsSection {
        visible: root.section === "system"
        fullWidth: true
        // The device header needs no section label.
        icon: "account_circle"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        Rectangle {
            width: parent.width
            height: Math.round(170 * Metrics.scale)
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: Metrics.cardPaddingWide
                spacing: Metrics.spaceXL

                Rectangle {
                    Layout.preferredWidth: Math.round(132 * Metrics.scale)
                    Layout.preferredHeight: Math.round(132 * Metrics.scale)
                    radius: width / 2
                    color: Theme.accentContainer
                    border.width: Metrics.focusBorder
                    border.color: Theme.accent

                    RoundedImage {
                        anchors.fill: parent
                        anchors.margins: Metrics.spaceS
                        radius: width / 2
                        source: root.pendingAvatarSource.length > 0
                            ? "file://" + root.pendingAvatarSource
                            : ProfileImageService.avatarSource
                        fallbackIcon: "person"
                        fallbackColor: Theme.groupSurfaceRaised
                        imageScale: root.avatarZoom
                        imageOffsetX: root.avatarOffsetX * 22
                        imageOffsetY: root.avatarOffsetY * 22
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spaceXS
                    Text {
                        Layout.fillWidth: true
                        text: SettingsService.hostName.length > 0
                            ? SettingsService.hostName : I18n.tr("settings.about.thisDevice")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(24 * Metrics.scale)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: SettingsService.osName
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.appTextBody
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("settings.about.version", {
                            version: SettingsService.voidlineVersion
                        })
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.appTextSupporting
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }
        SettingsSlider {
            visible: root.pendingAvatarSource.length > 0
            width: parent.width
            title: I18n.tr("settings.about.cropZoom")
            subtitle: I18n.tr("settings.about.cropZoomHint")
            icon: "crop"
            from: 1; to: 3; step: 0.05
            value: root.avatarZoom; suffix: "×"
            onChanged: value => root.avatarZoom = value
        }
        SettingsSlider {
            visible: root.pendingAvatarSource.length > 0
            width: parent.width
            title: I18n.tr("settings.about.horizontalPosition")
            icon: "swap_horiz"
            from: -1; to: 1; step: 0.05
            value: root.avatarOffsetX
            onChanged: value => root.avatarOffsetX = value
        }
        SettingsSlider {
            visible: root.pendingAvatarSource.length > 0
            width: parent.width
            title: I18n.tr("settings.about.verticalPosition")
            icon: "swap_vert"
            from: -1; to: 1; step: 0.05
            value: root.avatarOffsetY
            onChanged: value => root.avatarOffsetY = value
        }
        SettingsAction {
            width: parent.width
            icon: ProfileImageService.avatarAvailable ? "edit" : "add_photo_alternate"
            title: ProfileImageService.avatarAvailable
                ? I18n.tr("settings.about.replaceProfilePicture")
                : I18n.tr("settings.about.selectProfilePicture")
            subtitle: SystemSettingsService.available("imagemagick")
                ? I18n.tr("settings.about.chooseAndCrop")
                : I18n.tr("settings.about.installImageMagick")
            value: SystemSettingsService.available("imagemagick")
                ? I18n.tr("settings.about.choose")
                : I18n.tr("common.unsupported")
            enabled: !ProfileImageService.busy
                && SystemSettingsService.available("imagemagick")
            onClicked: avatarPicker.open()
        }
        SettingsAction {
            visible: root.pendingAvatarSource.length > 0
            width: parent.width
            icon: "check"
            title: I18n.tr("settings.about.applyCrop")
            subtitle: I18n.tr("settings.about.applyCropHint")
            value: ProfileImageService.busy
                ? I18n.tr("settings.about.saving") : I18n.tr("common.apply")
            enabled: !ProfileImageService.busy
            active: true
            onClicked: {
                ProfileImageService.applyCrop(root.pendingAvatarSource,
                    root.avatarZoom, root.avatarOffsetX, root.avatarOffsetY)
                root.pendingAvatarSource = ""
            }
        }
        SettingsAction {
            visible: ProfileImageService.avatarAvailable
                || root.pendingAvatarSource.length > 0
            width: parent.width
            icon: "person_off"
            title: I18n.tr("settings.about.useGeneratedAvatar")
            subtitle: I18n.tr("settings.about.useGeneratedAvatarHint")
            value: I18n.tr("common.remove")
            enabled: !ProfileImageService.busy
            onClicked: {
                root.pendingAvatarSource = ""
                ProfileImageService.remove()
            }
        }
        SettingsAction {
            visible: ProfileImageService.error.length > 0
            width: parent.width
            icon: "error"
            title: I18n.tr("settings.about.profilePictureError")
            subtitle: ProfileImageService.error
            enabled: false
        }
    }

    SettingsSection {
        plain: true
        visible: root.section === "system"
        fullWidth: true
        title: I18n.tr("settings.about.title")
        subtitle: I18n.tr("settings.about.subtitle")
        icon: "info"

        // Pixel "About" list: one flat row per fact, value on the right.
        Repeater {
            model: [
                { icon: "computer", title: I18n.tr("settings.about.deviceName"), value: SettingsService.hostName, subtitle: SettingsService.osName },
                { icon: "memory", title: I18n.tr("settings.about.processor"), value: SettingsService.cpu, subtitle: "CPU" },
                { icon: "developer_board", title: I18n.tr("settings.about.graphics"), value: SettingsService.gpu, subtitle: "GPU" },
                { icon: "memory_alt", title: I18n.tr("settings.about.installedMemory"), value: SettingsService.installedRam, subtitle: I18n.tr("settings.about.installedMemoryHint") },
                { icon: "hard_drive", title: I18n.tr("settings.about.storage"), value: SettingsService.storageCapacity, subtitle: I18n.tr("settings.about.storageUsed", { value: SettingsService.storageUsed }) },
                { icon: "terminal", title: I18n.tr("settings.about.kernel"), value: SettingsService.kernel, subtitle: I18n.tr("settings.about.kernelType", { type: SettingsService.kernelType }) },
                { icon: "schedule", title: I18n.tr("settings.about.uptime"), value: SettingsService.uptime, subtitle: I18n.tr("settings.about.uptimeHint") }
            ]

            SettingsValueRow {
                required property var modelData
                width: parent ? parent.width : 0
                icon: modelData.icon
                title: modelData.title
                value: modelData.value || modelData.subtitle
            }
        }
    }

    SettingsSection {
        visible: root.section === "system"
        fullWidth: true
        title: I18n.tr("settings.about.components")
        subtitle: I18n.tr("settings.about.componentsHint")
        icon: "layers"

        SettingsBrandRow {
            width: parent.width
            logoSource: "file://" + Paths.shellRoot + "/assets/branding/arch-linux.svg"
            title: "Arch Linux"
            subtitle: SettingsService.osName
            value: I18n.tr("settings.about.operatingSystem")
        }
        SettingsBrandRow {
            width: parent.width
            logoSource: "file://" + Paths.shellRoot + "/assets/branding/hyprland.svg"
            title: "Hyprland"
            subtitle: SettingsService.hyprlandVersion
            value: SettingsService.windowManager
        }
        SettingsBrandRow {
            width: parent.width
            logoSource: "file://" + Paths.shellRoot + "/assets/branding/quickshell.svg"
            title: "Quickshell"
            subtitle: SettingsService.quickshellVersion
            value: I18n.tr("settings.about.shellRuntime")
        }
        SettingsBrandRow {
            width: parent.width
            logoSource: "file://" + Paths.shellRoot + "/assets/branding/voidline.svg"
            title: "Voidline"
            subtitle: root.message.length > 0 ? root.message
                : I18n.tr("settings.about.version", { version: SettingsService.voidlineVersion })
            value: I18n.tr("settings.about.desktopShell")
            interactive: true
            onClicked: root.tapVersion()
        }

        Rectangle {
            width: parent.width
            height: 46
            color: "transparent"

            Rectangle {
                anchors { right: parent.right; rightMargin: Metrics.cardPadding; verticalCenter: parent.verticalCenter }
                width: supportLabel.implicitWidth + Metrics.spaceXL
                height: Metrics.controlS
                radius: Metrics.buttonRadius
                color: supportHover.hovered ? Theme.groupSurfaceRaised : "transparent"
                border.width: Metrics.border
                border.color: Theme.outlineSoft

                Text {
                    id: supportLabel
                    anchors.centerIn: parent
                    text: I18n.tr("settings.about.supportKofi")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textSupporting
                    font.weight: Font.Medium
                }
                HoverHandler { id: supportHover }
                TapHandler {
                    onTapped: Qt.openUrlExternally("https://ko-fi.com/shadowokami")
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    // ---------------- Language & region ----------------
    SettingsSection {
        visible: root.section === "language"
        title: I18n.tr("settings.language.title")
        icon: "language"

        Repeater {
            model: [
                { id: "auto", label: I18n.tr("settings.language.automatic") },
                { id: "en-US", label: I18n.tr("settings.language.english") },
                { id: "de-DE", label: I18n.tr("settings.language.german") },
                { id: "pl-PL", label: I18n.tr("settings.language.polish") }
            ]

            SettingsAction {
                required property var modelData
                width: parent.width
                icon: Appearance.language === modelData.id
                    ? "radio_button_checked" : "radio_button_unchecked"
                title: modelData.label
                active: Appearance.language === modelData.id
                onClicked: Appearance.setLanguage(modelData.id)
            }
        }
    }

    SettingsSection {
        visible: root.section === "developer" && Appearance.developerMode
        title: "Developer and debug"
        subtitle: "Runtime controls and live service inspection"
        icon: "code"

        SettingsToggle {
            width: parent.width
            icon: "code_off"
            title: "Developer options"
            subtitle: "Hide this category and disable developer diagnostics"
            checked: true
            onToggled: value => {
                if (!value)
                    ShellState.openSettings("system")
                if (!value)
                    Appearance.setDeveloperMode(false)
            }
        }

        SettingsAction {
            width: parent.width
            icon: "restart_alt"
            title: "Reload Quickshell"
            subtitle: "Reuse existing windows and reload every component"
            value: "Reload"
            onClicked: Quickshell.reload(false)
        }
        SettingsAction {
            width: parent.width
            icon: "refresh"
            title: "Refresh system snapshot"
            subtitle: "Re-read monitors, devices, packages, and optional services"
            onClicked: {
                SettingsService.refresh()
                SystemSettingsService.refresh()
                SecurityService.refresh()
                AudioService.refreshProfiles()
                DiagnosticsService.refresh()
            }
        }
        SettingsToggle {
            width: parent.width
            icon: "description"
            title: "Verbose logging"
            subtitle: "Include extended service output and 500 recent log lines in reports"
            checked: DiagnosticsService.verboseLogging
            onToggled: value => DiagnosticsService.setVerboseLogging(value)
        }
        SettingsAction {
            width: parent.width
            icon: "bug_report"
            title: "Send test notification"
            subtitle: "Exercise the native daemon, popup, and history"
            value: "Test"
            onClicked: Quickshell.execDetached({
                command: ["notify-send", "-a", "Voidline diagnostics",
                    "Voidline test", "Notification delivery is working"]
            })
        }
        SettingsAction {
            width: parent.width
            icon: "animation"
            title: "Test panel animation"
            subtitle: "Open the Action Center on the focused display"
            value: "Open"
            onClicked: ShellState.openControlCenter("")
        }
        SettingsAction {
            width: parent.width
            icon: "admin_panel_settings"
            title: "Test authentication dialog"
            subtitle: "Run a harmless Polkit authorization request"
            value: PolkitService.registered ? "Test" : "Unavailable"
            enabled: PolkitService.registered
            onClicked: Quickshell.execDetached({
                command: ["pkexec", "/usr/bin/true"]
            })
        }
        SettingsAction {
            width: parent.width
            icon: "terminal"
            title: "Runtime"
            subtitle: SettingsService.quickshellVersion
            value: SettingsService.hyprlandVersion
            interactive: false
        }
    }

    SettingsSection {
        visible: root.section === "developer" && Appearance.developerMode
        title: "Active services"
        subtitle: "Live state from the shell and desktop session"
        icon: "monitor_heart"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsAction {
            visible: FeatureRegistry.aiInstalled
            width: parent.width
            icon: "smart_toy"
            title: "Lyra backend"
            subtitle: DiagnosticsService.assistantStatus
            value: AssistantService.selectedModel
            active: AssistantService.providerReady
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "graphic_eq"
            title: "PipeWire and WirePlumber"
            subtitle: AudioService.outputName
            value: AudioService.outputReady ? "Ready" : "Unavailable"
            active: AudioService.outputReady
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "bluetooth"
            title: "Bluetooth"
            subtitle: ConnectivityService.connectedBluetoothDevices + " connected devices"
            value: ConnectivityService.bluetoothEnabled ? "On" : "Off"
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "network_check"
            title: "Network"
            subtitle: ConnectivityService.activeNetworkLabel
            value: ConnectivityService.activeNetworkType
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "notifications"
            title: "Notification daemon"
            subtitle: NotificationService.count + " stored notifications"
            value: NotificationService.doNotDisturb ? "DND" : "Ready"
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "apps"
            title: "System tray"
            subtitle: "StatusNotifierItem registrations"
            value: DiagnosticsService.trayCount + " items"
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "desktop_windows"
            title: "Detected monitors and devices"
            subtitle: SystemSettingsService.monitors.length + " monitors · "
                + SystemSettingsService.list("usb").length + " USB devices"
            value: "Inspect"
            onClicked: ShellState.openSettings("devices")
        }
        SettingsAction {
            width: parent.width
            icon: "palette"
            title: "Wallpaper palette"
            subtitle: Appearance.wallpaperPath
            value: Theme.accent.toString()
            interactive: false
        }
    }

    SettingsSection {
        visible: root.section === "developer" && Appearance.developerMode
        title: "Diagnostics and recovery"
        subtitle: "Reports contain system state but never passwords"
        icon: "troubleshoot"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsAction {
            width: parent.width
            icon: "content_copy"
            title: "Copy diagnostic information"
            subtitle: "Copy the current report to the clipboard"
            value: DiagnosticsService.busy ? "Collecting…" : "Copy"
            enabled: !DiagnosticsService.busy
            onClicked: DiagnosticsService.copyReport()
        }
        SettingsAction {
            width: parent.width
            icon: "article"
            title: "View recent shell logs"
            subtitle: "Show the diagnostic snapshot inside Settings"
            value: DiagnosticsService.reportVisible ? "Hide" : "View"
            active: DiagnosticsService.reportVisible
            onClicked: DiagnosticsService.toggleReport()
        }
        Rectangle {
            width: parent.width
            height: DiagnosticsService.reportVisible ? 250 : 0
            visible: height > 0
            radius: Theme.radiusLarge
            color: Theme.surfaceLow
            border.width: 1
            border.color: Theme.outlineSoft
            clip: true

            Flickable {
                anchors { fill: parent; margins: 12 }
                contentWidth: width
                contentHeight: logText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: logText
                    width: parent.width
                    text: DiagnosticsService.reportText.length > 0
                        ? DiagnosticsService.reportText : "Collecting diagnostics…"
                    color: Theme.textMuted
                    font.family: "monospace"
                    font.pixelSize: 10
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
        SettingsAction {
            width: parent.width
            icon: "save"
            title: "Export diagnostic report"
            subtitle: DiagnosticsService.reportPath.length > 0
                ? DiagnosticsService.reportPath : "Save under Documents/Voidline/Diagnostics"
            value: "Export"
            onClicked: DiagnosticsService.exportReport()
        }
        SettingsAction {
            width: parent.width
            icon: "delete_sweep"
            title: "Clear shell cache"
            subtitle: "Remove only Voidline's disposable cache files"
            value: DiagnosticsService.cacheConfirmation ? "Confirm" : "Clear"
            active: DiagnosticsService.cacheConfirmation
            onClicked: {
                if (DiagnosticsService.cacheConfirmation)
                    DiagnosticsService.confirmClearCache()
                else
                    DiagnosticsService.requestClearCache()
            }
        }
        SettingsAction {
            width: parent.width
            visible: DiagnosticsService.error.length > 0
            icon: "error"
            title: "Diagnostic action failed"
            subtitle: DiagnosticsService.error
            enabled: false
        }
    }
}
