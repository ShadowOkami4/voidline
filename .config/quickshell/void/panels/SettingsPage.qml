import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"
import "settings"

FocusScope {
    id: root

    property var shellScreen
    property bool active: false
    readonly property string section: ShellState.settingsSection
    readonly property bool wideNavigation: width >= Metrics.settingsNarrow
    readonly property bool navigationVisible: wideNavigation || section === "home"
    property string searchText: ""
    readonly property var navigationGroups: [
        { id: "connected", title: I18n.tr("settings.groups.connected") },
        { id: "personal", title: I18n.tr("settings.groups.personal") },
        { id: "system", title: I18n.tr("settings.groups.system") }
    ]
    readonly property var categories: {
        const items = [
            { id: "connections", group: "connected", title: I18n.tr("settings.categories.connections.0"), subtitle: I18n.tr("settings.categories.connections.1"), icon: "wifi", tone: 0 },
            { id: "audio", group: "connected", title: I18n.tr("settings.categories.audio.0"), subtitle: I18n.tr("settings.categories.audio.1"), icon: "volume_up", tone: 2 },
            { id: "devices", group: "connected", title: I18n.tr("settings.categories.devices.0"), subtitle: I18n.tr("settings.categories.devices.1"), icon: "devices_other", tone: 1 },
            { id: "notifications", group: "personal", title: I18n.tr("settings.categories.notifications.0"), subtitle: I18n.tr("settings.categories.notifications.1"), icon: "notifications", tone: 2 },
            { id: "display", group: "personal", title: I18n.tr("settings.categories.display.0"), subtitle: I18n.tr("settings.categories.display.1"), icon: "desktop_windows", tone: 0 },
            { id: "appearance", group: "personal", title: I18n.tr("settings.categories.appearance.0"), subtitle: I18n.tr("settings.categories.appearance.1"), icon: "palette", tone: 1 },
            { id: "lock", group: "personal", title: I18n.tr("settings.categories.lock.0"), subtitle: I18n.tr("settings.categories.lock.1"), icon: "lock", tone: 0 },
            { id: "security", group: "personal", title: I18n.tr("settings.categories.security.0"), subtitle: I18n.tr("settings.categories.security.1"), icon: "security", tone: 2 },
            { id: "accessibility", group: "personal", title: I18n.tr("settings.categories.accessibility.0"), subtitle: I18n.tr("settings.categories.accessibility.1"), icon: "accessibility_new", tone: 1 },
            { id: "updates", group: "system", title: I18n.tr("settings.categories.updates.0"), subtitle: I18n.tr("settings.categories.updates.1"), icon: "system_update", tone: 2 },
            { id: "system", group: "system", title: I18n.tr("settings.categories.system.0"), subtitle: I18n.tr("settings.categories.system.1"), icon: "info", tone: 0 }
        ]
        if (FeatureRegistry.aiInstalled)
            items.splice(items.length - 1, 0, {
                id: "assistant", group: "system",
                title: I18n.tr("settings.categories.assistant.0"),
                subtitle: I18n.tr("settings.categories.assistant.1"),
                icon: "neurology", tone: 1
            })
        if (Appearance.developerMode)
            items.push({ id: "developer", group: "system", title: I18n.tr("settings.categories.developer.0"), subtitle: I18n.tr("settings.categories.developer.1"), icon: "code", tone: 1 })
        return items
    }

    signal back

    function visibleCategories(group) {
        const query = searchText.trim().toLowerCase()
        return categories.filter(item => item.group === group
            && (query.length === 0
                || item.title.toLowerCase().indexOf(query) >= 0
                || item.subtitle.toLowerCase().indexOf(query) >= 0))
    }

    function resultCount() {
        let count = 0
        for (let index = 0; index < navigationGroups.length; ++index)
            count += visibleCategories(navigationGroups[index].id).length
        return count
    }

    function category() {
        for (let index = 0; index < categories.length; ++index) {
            if (categories[index].id === section)
                return categories[index]
        }
        return { title: I18n.tr("settings.title"), subtitle: I18n.tr("settings.subtitle"), icon: "settings", tone: 0 }
    }

    // Every category owns a hue, like Pixel Settings, so destinations are
    // recognisable at a glance while staying inside the tonal system.
    readonly property var categoryHues: ({
        connections: 0.58, audio: 0.07, devices: 0.36, notifications: 0.95,
        display: 0.52, appearance: 0.76, lock: 0.12, security: 0.3,
        accessibility: 0.64, updates: 0.44, assistant: 0.84, system: 0.2,
        developer: 0.0
    })

    function categoryHue(id) {
        const hue = categoryHues[id]
        return hue === undefined ? Theme.seed.hslHue : hue
    }

    function categoryContainer(id) {
        return Qt.hsla(categoryHue(id), 0.42, Theme.darkMode ? 0.3 : 0.86, 1)
    }

    function categoryInk(id) {
        return Qt.hsla(categoryHue(id), 0.6, Theme.darkMode ? 0.86 : 0.24, 1)
    }

    function heroInfo(id) {
        const fallback = category()
        switch (id) {
        case "connections":
            if (ConnectivityService.ethernetConnected)
                return { icon: "lan", title: I18n.tr("settings.hero.wired"), subtitle: ConnectivityService.activeNetworkLabel || "", active: true }
            if (ConnectivityService.wifiConnected)
                return { icon: "wifi", title: ConnectivityService.wifiSsid || fallback.title,
                    subtitle: ConnectivityService.activeNetworkLabel || "", active: true }
            return { icon: ConnectivityService.wifiEnabled ? "wifi_find" : "wifi_off",
                title: ConnectivityService.wifiEnabled ? I18n.tr("settings.hero.notConnected") : I18n.tr("settings.hero.wifiOff"),
                subtitle: fallback.subtitle, active: false }
        case "audio":
            return { icon: AudioService.outputMuted ? "volume_off" : "volume_up",
                title: AudioService.outputLabel || fallback.title,
                subtitle: AudioService.outputMuted ? I18n.tr("settings.hero.muted")
                    : I18n.tr("settings.hero.volume", { value: Math.round(Number(AudioService.outputVolume || 0) * 100) }),
                active: !AudioService.outputMuted }
        case "devices": {
            const count = Number(ConnectivityService.connectedBluetoothDevices || 0)
            return { icon: ConnectivityService.bluetoothEnabled ? "bluetooth_connected" : "bluetooth_disabled",
                title: !ConnectivityService.bluetoothEnabled ? I18n.tr("settings.hero.bluetoothOff")
                    : (count > 0 ? I18n.tr("settings.hero.devicesConnected", { count: count }) : I18n.tr("settings.hero.noDevices")),
                subtitle: fallback.subtitle, active: ConnectivityService.bluetoothEnabled && count > 0 }
        }
        case "notifications":
            return { icon: NotificationService.doNotDisturb ? "do_not_disturb_on" : "notifications_active",
                title: NotificationService.doNotDisturb ? I18n.tr("settings.hero.dndOn")
                    : I18n.tr("settings.hero.notificationsCount", { count: NotificationService.count || 0 }),
                subtitle: fallback.subtitle, active: !NotificationService.doNotDisturb }
        case "display":
            return { icon: "desktop_windows",
                title: I18n.tr("settings.hero.displays", { count: Math.max(1, (SystemSettingsService.monitors || []).length) }),
                subtitle: fallback.subtitle, active: true }
        case "appearance":
            return { icon: Theme.darkMode ? "dark_mode" : "light_mode",
                title: Appearance.colorMode === "auto" ? I18n.tr("settings.hero.autoTheme")
                    : (Appearance.colorMode === "light" ? I18n.tr("settings.hero.lightTheme") : I18n.tr("settings.hero.darkTheme")),
                subtitle: Appearance.magicColors ? I18n.tr("settings.hero.wallpaperColors") : I18n.tr("settings.hero.accentColor"),
                active: true }
        case "security":
            return { icon: SecurityService.firewallEnabled ? "shield_lock" : "shield",
                title: SecurityService.firewallEnabled ? I18n.tr("settings.hero.firewallOn") : I18n.tr("settings.hero.firewallOff"),
                subtitle: fallback.subtitle, active: SecurityService.firewallEnabled }
        case "updates":
            return { icon: UpdateService.count > 0 ? "system_update" : "verified",
                title: UpdateService.count > 0
                    ? I18n.tr("settings.hero.updatesAvailable", { count: UpdateService.count }) : I18n.tr("settings.hero.upToDate"),
                subtitle: fallback.subtitle, active: UpdateService.count > 0 }
        case "assistant":
            return { icon: "neurology",
                title: AssistantService.assistantEnabled ? I18n.tr("settings.hero.assistantOn") : I18n.tr("settings.hero.assistantOff"),
                subtitle: fallback.subtitle, active: AssistantService.assistantEnabled }
        case "system":
            return { icon: "computer",
                title: SettingsService.hostName || fallback.title,
                subtitle: [SettingsService.osName, SettingsService.voidlineVersion
                    ? "Voidline " + SettingsService.voidlineVersion : ""].filter(Boolean).join(" · "),
                active: true }
        default:
            return { icon: fallback.icon, title: fallback.title, subtitle: fallback.subtitle, active: false }
        }
    }

    function closeOrBack() {
        if (!wideNavigation && section !== "home")
            ShellState.settingsSection = "home"
        else
            root.back()
    }

    onActiveChanged: {
        if (active)
            wideModeTimer.restart()
        SettingsService.setActive(active)
        SystemSettingsService.setActive(active)
        SystemSettingsService.setDevicesActive(active && section === "devices")
        PowerService.brightnessMonitoring = active
        ConnectivityService.setWifiPageActive(active && section === "connections")
        ConnectivityService.setBluetoothPageActive(active && (section === "connections"
            || section === "devices"))
        AudioService.profileMonitoring = active && section === "audio"
        if (active && section === "assistant")
            AssistantService.refreshRuntimeMetrics()
        if (active) {
            ConnectivityService.refreshWifi()
            SystemActionService.refreshCapabilities()
            WallpaperService.refresh()
        }
    }

    onSectionChanged: {
        detailFlick.contentY = 0
        ConnectivityService.setWifiPageActive(active && section === "connections")
        ConnectivityService.setBluetoothPageActive(active && (section === "connections"
            || section === "devices"))
        AudioService.profileMonitoring = active && section === "audio"
        if (section !== "home")
            Qt.callLater(() => pageReveal.restart())
    }

    onWideNavigationChanged: {
        if (active && section === "home")
            wideModeTimer.restart()
    }

    Timer {
        id: wideModeTimer
        interval: 180
        onTriggered: {
            if (root.active && root.wideNavigation && root.section === "home")
                ShellState.settingsSection = "connections"
        }
    }

    Keys.onEscapePressed: event => {
        closeOrBack()
        event.accepted = true
    }

    // Android 16 style Settings: a navigation pane with a large title, pill
    // search, and coloured category icons; a rounded detail pane with a large
    // title and a status hero card above the category's grouped settings.
    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceContainerLow
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: navigationPane
            visible: root.navigationVisible
            Layout.preferredWidth: root.wideNavigation ? Metrics.settingsSidebar : 0
            Layout.fillWidth: !root.wideNavigation
            Layout.fillHeight: true

            ColumnLayout {
                anchors {
                    fill: parent
                    leftMargin: root.wideNavigation ? 20 : 28
                    rightMargin: root.wideNavigation ? 16 : 28
                    topMargin: 24
                    bottomMargin: 18
                }
                spacing: Metrics.spaceL

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spaceS

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Metrics.spaceS
                        text: I18n.tr("settings.title")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(40 * Metrics.scale)
                        font.weight: Font.DemiBold
                        font.variableAxes: ({ "wght": 600, "wdth": 105, "opsz": 40 })
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "close"
                        size: Math.round(44 * Metrics.scale)
                        accessibleName: I18n.tr("common.close")
                        onClicked: root.back()
                    }
                }

                SettingsSearchField {
                    Layout.fillWidth: true
                    placeholder: I18n.tr("settings.search")
                    showAvatar: true
                    onAvatarClicked: ShellState.openSettings("system")
                    onTextChanged: root.searchText = text
                    onAccepted: {
                        for (let group = 0; group < root.navigationGroups.length; ++group) {
                            const results = root.visibleCategories(root.navigationGroups[group].id)
                            if (results.length > 0) {
                                ShellState.openSettings(results[0].id)
                                return
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: navigationContent.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: navigationContent
                        width: parent.width
                        spacing: Metrics.spaceL

                        Repeater {
                            model: root.navigationGroups

                            Column {
                                id: navigationGroup
                                required property var modelData
                                readonly property var items: root.visibleCategories(modelData.id)
                                width: navigationContent.width
                                visible: items.length > 0
                                spacing: Metrics.segmentGap

                                Repeater {
                                    model: navigationGroup.items

                                    Rectangle {
                                        id: categoryButton
                                        required property int index
                                        required property var modelData
                                        readonly property bool selected: root.section === modelData.id
                                        readonly property bool first: index === 0
                                        readonly property bool last: index === navigationGroup.items.length - 1
                                        readonly property real outer: Metrics.cardRadius
                                        readonly property real inner: Metrics.segmentInnerRadius

                                        width: navigationGroup.width
                                        height: Math.round(72 * Metrics.scale)
                                        topLeftRadius: selected ? height / 2 : (first ? outer : inner)
                                        topRightRadius: topLeftRadius
                                        bottomLeftRadius: selected ? height / 2 : (last ? outer : inner)
                                        bottomRightRadius: bottomLeftRadius
                                        color: selected ? Theme.accentContainer
                                            : (categoryHover.hovered ? Theme.surfaceContainerHighest
                                                : Theme.surfaceContainerHigh)
                                        scale: categoryTap.pressed ? 0.985 : 1

                                        Behavior on topLeftRadius {
                                            NumberAnimation {
                                                duration: Motion.springFast
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Motion.spatialFast
                                            }
                                        }
                                        Behavior on bottomLeftRadius {
                                            NumberAnimation {
                                                duration: Motion.springFast
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Motion.spatialFast
                                            }
                                        }
                                        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Motion.springFast
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Motion.spatialFast
                                            }
                                        }

                                        RowLayout {
                                            anchors {
                                                fill: parent
                                                leftMargin: Metrics.spaceM
                                                rightMargin: Metrics.spaceL
                                            }
                                            spacing: Metrics.spaceM

                                            Rectangle {
                                                Layout.preferredWidth: Math.round(40 * Metrics.scale)
                                                Layout.preferredHeight: Layout.preferredWidth
                                                radius: width / 2
                                                color: root.categoryContainer(categoryButton.modelData.id)

                                                MaterialIcon {
                                                    anchors.centerIn: parent
                                                    text: categoryButton.modelData.icon
                                                    size: Math.round(21 * Metrics.scale)
                                                    fill: 1
                                                    color: root.categoryInk(categoryButton.modelData.id)
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: categoryButton.modelData.title
                                                    color: categoryButton.selected
                                                        ? Theme.accentContainerInk : Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextTitle
                                                    font.weight: categoryButton.selected ? Font.DemiBold : Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: categoryButton.modelData.subtitle
                                                    color: categoryButton.selected
                                                        ? Theme.accentContainerInk : Theme.textMuted
                                                    opacity: categoryButton.selected ? 0.8 : 1
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextSupporting
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        HoverHandler {
                                            id: categoryHover
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            id: categoryTap
                                            onTapped: ShellState.openSettings(categoryButton.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.resultCount() === 0
                            width: parent.width
                            height: 72
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: I18n.tr("settings.noResults", { query: root.searchText })
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Metrics.appTextBody
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        Rectangle {
            id: detailPane
            visible: root.wideNavigation || root.section !== "home"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.wideNavigation ? Metrics.spaceM : 0
            Layout.bottomMargin: root.wideNavigation ? Metrics.spaceM : 0
            Layout.rightMargin: root.wideNavigation ? Metrics.spaceM : 0
            radius: root.wideNavigation ? Metrics.radiusXL : 0
            color: Theme.surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: root.wideNavigation ? 32 : 20
                    Layout.rightMargin: 20
                    Layout.topMargin: 24
                    Layout.bottomMargin: Metrics.spaceL
                    spacing: Metrics.spaceM

                    IconButton {
                        visible: !root.wideNavigation
                        icon: "arrow_back"
                        size: Math.round(44 * Metrics.scale)
                        accessibleName: I18n.tr("common.back")
                        onClicked: ShellState.settingsSection = "home"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.category().title
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(34 * Metrics.scale)
                        font.weight: Font.DemiBold
                        font.variableAxes: ({ "wght": 600, "wdth": 105, "opsz": 34 })
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: SettingsService.loading || SystemSettingsService.loading
                            ? "progress_activity" : "refresh"
                        size: Math.round(44 * Metrics.scale)
                        accessibleName: I18n.tr("settings.refresh")
                        onClicked: {
                            SettingsService.refresh()
                            SystemSettingsService.refresh()
                            if (root.section === "devices")
                                SystemSettingsService.refreshDevices()
                            ConnectivityService.refreshWifi()
                        }
                    }
                }

                Flickable {
                    id: detailFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: root.wideNavigation ? 28 : 18
                    Layout.rightMargin: root.wideNavigation ? 28 : 18
                    contentWidth: width
                    contentHeight: pageFrame.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        id: pageFrame
                        width: detailFlick.width
                        height: Math.max(detailFlick.height, pageColumn.height + 28)

                        Column {
                            id: pageColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, Metrics.settingsContentMax)
                            spacing: Metrics.settingsSectionGap

                            // Hero: the category's live status at a glance.
                            Rectangle {
                                id: hero
                                readonly property var info: root.heroInfo(root.section)
                                width: parent.width
                                height: Math.round(120 * Metrics.scale)
                                radius: Metrics.radiusXL
                                color: info.active ? Theme.accentContainer : Theme.surfaceContainerHigh
                                visible: root.section !== "home"

                                Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: Metrics.spaceL
                                        rightMargin: Metrics.spaceXL
                                    }
                                    spacing: Metrics.spaceL

                                    Rectangle {
                                        Layout.preferredWidth: Math.round(80 * Metrics.scale)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: width / 2
                                        color: hero.info.active ? Theme.accent
                                            : root.categoryContainer(root.section)

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: hero.info.icon
                                            size: Math.round(38 * Metrics.scale)
                                            fill: 1
                                            color: hero.info.active ? Theme.accentInk
                                                : root.categoryInk(root.section)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: hero.info.title
                                            color: hero.info.active ? Theme.accentContainerInk : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.round(24 * Metrics.scale)
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: hero.info.subtitle
                                            visible: text.length > 0
                                            color: hero.info.active ? Theme.accentContainerInk : Theme.textMuted
                                            opacity: hero.info.active ? 0.82 : 1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Metrics.appTextBody
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Loader {
                                id: pageLoader
                                property real revealOffset: 0
                                // Settings is a normal app window but its content
                                // is still expensive (wallpaper previews, monitor
                                // models, device lists). Destroy the current page
                                // when the window closes instead of keeping a
                                // hidden GeneralSettings object graph alive for the
                                // entire desktop session.
                                active: root.active && root.section !== "home"
                                width: parent.width
                                height: item ? item.implicitHeight : 0
                                transform: Translate { x: pageLoader.revealOffset }
                                sourceComponent: root.section === "connections" ? connectionsPage
                                    : (root.section === "audio" ? audioPage
                                        : (root.section === "devices" ? devicesPage
                                            : (root.section === "display" ? displayPage
                                                : (root.section === "appearance" ? appearancePage
                                                    : (root.section === "assistant" ? assistantPage
                                                        : generalPage)))))
                            }
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: pageReveal
        PropertyAction { target: pageLoader; property: "opacity"; value: 0 }
        PropertyAction { target: pageLoader; property: "revealOffset"; value: 10 }
        PauseAnimation { duration: Appearance.reduceMotion ? 0 : 16 }
        ParallelAnimation {
            NumberAnimation {
                target: pageLoader
                property: "opacity"
                to: 1
                duration: Appearance.reduceMotion ? 0 : Motion.enter
                easing.type: Motion.enterCurve
            }
            NumberAnimation {
                target: pageLoader
                property: "revealOffset"
                to: 0
                duration: Appearance.reduceMotion ? 0 : Motion.enter
                easing.type: Motion.enterCurve
            }
        }
    }

    Component {
        id: connectionsPage
        ConnectionsSettings { shellScreen: root.shellScreen }
    }
    Component { id: audioPage; AudioSettings {} }
    Component { id: devicesPage; DevicesSettings {} }
    Component { id: displayPage; DisplaySettings {} }
    Component { id: appearancePage; AppearanceSettings {} }
    Component { id: assistantPage; LyraSettings {} }
    Component {
        id: generalPage
        GeneralSettings { section: root.section }
    }
}
