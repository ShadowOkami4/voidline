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

    // Pixel uses pastel icon circles in dark mode and saturated ones in light.
    function categoryContainer(id) {
        return Qt.hsla(categoryHue(id), 0.45, Theme.darkMode ? 0.74 : 0.42, 1)
    }

    function categoryInk(id) {
        return Theme.darkMode ? Qt.hsla(categoryHue(id), 0.5, 0.12, 1) : "#FFFFFF"
    }

    // Categories whose page is governed by one master toggle show a Pixel
    // "main switch" bar above their settings.
    function mainSwitchInfo(id) {
        switch (id) {
        case "connections":
            return { title: I18n.tr("settings.mainSwitch.wifi"), checked: ConnectivityService.wifiEnabled,
                available: ConnectivityService.wifiAvailable }
        case "devices":
            return { title: I18n.tr("settings.mainSwitch.bluetooth"), checked: ConnectivityService.bluetoothEnabled,
                available: ConnectivityService.bluetoothAvailable }
        case "notifications":
            return { title: I18n.tr("settings.mainSwitch.dnd"), checked: NotificationService.doNotDisturb, available: true }
        case "appearance":
            return { title: I18n.tr("settings.mainSwitch.darkTheme"), checked: Theme.darkMode, available: true }
        case "assistant":
            return { title: I18n.tr("settings.mainSwitch.assistant"), checked: AssistantService.assistantEnabled, available: true }
        default:
            return null
        }
    }

    function setMainSwitch(id, checked) {
        if (id === "connections")
            ConnectivityService.setWifiEnabled(checked)
        else if (id === "devices" && checked !== ConnectivityService.bluetoothEnabled)
            ConnectivityService.toggleBluetooth()
        else if (id === "notifications")
            NotificationService.setDoNotDisturb(checked)
        else if (id === "appearance")
            Appearance.setColorMode(checked ? "dark" : "light")
        else if (id === "assistant")
            AssistantService.setAssistantEnabled(checked)
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

    // Pixel style Settings: a flat navigation list with pastel category
    // icons and a pill for the open page, and a detail pane with a large
    // regular-weight title, an optional main switch, and flat preference
    // rows under accent-coloured section labels.
    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceContainer
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
                    leftMargin: Metrics.spaceL
                    rightMargin: root.wideNavigation ? Metrics.spaceS : Metrics.spaceL
                    topMargin: Metrics.spaceL
                    bottomMargin: Metrics.spaceL
                }
                spacing: Metrics.spaceL

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spaceS

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

                    IconButton {
                        visible: !root.wideNavigation
                        icon: "close"
                        size: Math.round(44 * Metrics.scale)
                        accessibleName: I18n.tr("common.close")
                        onClicked: root.back()
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
                        spacing: Metrics.spaceM

                        Repeater {
                            model: root.navigationGroups

                            Column {
                                id: navigationGroup
                                required property var modelData
                                readonly property var items: root.visibleCategories(modelData.id)
                                width: navigationContent.width
                                visible: items.length > 0
                                spacing: 0

                                Repeater {
                                    model: navigationGroup.items

                                    Rectangle {
                                        id: categoryButton
                                        required property var modelData
                                        readonly property bool selected: root.section === modelData.id

                                        width: navigationGroup.width
                                        height: Math.round(72 * Metrics.scale)
                                        radius: height / 2
                                        color: selected ? Theme.secondaryContainer
                                            : (categoryHover.hovered ? Theme.withAlpha(Theme.text, 0.06) : "transparent")
                                        Accessible.role: Accessible.PageTab
                                        Accessible.name: modelData.title
                                        Accessible.selected: selected

                                        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

                                        RowLayout {
                                            anchors {
                                                fill: parent
                                                leftMargin: Metrics.spaceL
                                                rightMargin: Metrics.spaceL
                                            }
                                            spacing: Metrics.spaceL

                                            Rectangle {
                                                Layout.preferredWidth: Math.round(40 * Metrics.scale)
                                                Layout.preferredHeight: Layout.preferredWidth
                                                radius: width / 2
                                                color: root.categoryContainer(categoryButton.modelData.id)

                                                MaterialIcon {
                                                    anchors.centerIn: parent
                                                    text: categoryButton.modelData.icon
                                                    size: Math.round(22 * Metrics.scale)
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
                                                        ? Theme.secondaryContainerInk : Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextTitle
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: categoryButton.modelData.subtitle
                                                    color: categoryButton.selected
                                                        ? Theme.secondaryContainerInk : Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextBody
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        HoverHandler {
                                            id: categoryHover
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
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
            color: Theme.background

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: root.wideNavigation ? Metrics.spaceXL : Metrics.spaceS
                    Layout.rightMargin: Metrics.spaceM
                    Layout.topMargin: Math.round(28 * Metrics.scale)
                    Layout.bottomMargin: Metrics.spaceL
                    spacing: Metrics.spaceS

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
                        font.weight: Font.Normal
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

                    IconButton {
                        visible: root.wideNavigation
                        icon: "close"
                        size: Math.round(44 * Metrics.scale)
                        accessibleName: I18n.tr("common.close")
                        onClicked: root.back()
                    }
                }

                Flickable {
                    id: detailFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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

                            // Pixel "main switch" bar for categories with one
                            // master toggle (Use Wi-Fi, Use Bluetooth, …).
                            Rectangle {
                                id: mainSwitch
                                readonly property var info: root.mainSwitchInfo(root.section)
                                visible: info !== null
                                x: Metrics.spaceXL
                                width: parent.width - Metrics.spaceXL * 2
                                height: visible ? Math.round(72 * Metrics.scale) : 0
                                radius: height / 2
                                color: info && info.checked ? Theme.accentContainer : Theme.surfaceContainerHigh
                                opacity: info && info.available === false ? 0.5 : 1
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: info ? info.title : ""
                                Accessible.checked: info ? info.checked : false

                                Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: Math.round(28 * Metrics.scale)
                                        rightMargin: Metrics.spaceXL
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: mainSwitch.info ? mainSwitch.info.title : ""
                                        color: mainSwitch.info && mainSwitch.info.checked
                                            ? Theme.accentContainerInk : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.round(20 * Metrics.scale)
                                        font.weight: Font.Normal
                                        elide: Text.ElideRight
                                    }
                                    ToggleSwitch {
                                        checked: mainSwitch.info ? mainSwitch.info.checked : false
                                        enabled: mainSwitch.info ? mainSwitch.info.available !== false : false
                                        onToggled: checked => root.setMainSwitch(root.section, checked)
                                    }
                                }

                                TapHandler {
                                    enabled: mainSwitch.info && mainSwitch.info.available !== false
                                    onTapped: root.setMainSwitch(root.section, !mainSwitch.info.checked)
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
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
