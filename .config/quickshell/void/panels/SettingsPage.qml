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

    function toneContainer(tone) {
        return tone === 1 ? Theme.secondaryContainer
            : (tone === 2 ? Theme.tertiaryContainer : Theme.accentContainer)
    }

    function toneColor(tone) {
        return tone === 1 ? Theme.secondary
            : (tone === 2 ? Theme.tertiary : Theme.accent)
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
                    leftMargin: root.wideNavigation ? 20 : 26
                    rightMargin: root.wideNavigation ? 18 : 26
                    topMargin: 20
                    bottomMargin: 18
                }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2

                        Text {
                            text: I18n.tr("settings.title")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: root.wideNavigation
                                ? Metrics.appTextHeader : Math.round(Metrics.appTextHeader * 1.12)
                            font.weight: Font.DemiBold
                            font.variableAxes: { "wght": 680, "wdth": 95, "opsz": 34, "GRAD": 18 }
                        }
                        Text {
                            text: I18n.tr("settings.subtitle")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Metrics.appTextCaption
                            font.weight: Font.Medium
                        }
                    }

                    IconButton {
                        icon: "close"
                        accessibleName: I18n.tr("common.close")
                        onClicked: root.back()
                    }
                }

                SettingsSearchField {
                    Layout.fillWidth: true
                    placeholder: I18n.tr("settings.search")
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
                        spacing: 14

                        Repeater {
                            model: root.navigationGroups

                            Column {
                                id: navigationGroup
                                required property var modelData
                                readonly property var items: root.visibleCategories(modelData.id)
                                width: navigationContent.width
                                visible: items.length > 0
                                spacing: 7

                                Text {
                                    width: parent.width
                                    leftPadding: 8
                                    text: navigationGroup.modelData.title
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.appTextCaption
                                    font.weight: Font.DemiBold
                                }

                                // Material 3 Expressive segmented navigation:
                                // each destination is its own segment and the
                                // selected one morphs into a filled pill.
                                Item {
                                    width: parent.width
                                    height: navigationRows.implicitHeight

                                    Column {
                                        id: navigationRows
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            top: parent.top
                                        }
                                        spacing: Metrics.segmentGap

                                        Repeater {
                                            model: navigationGroup.items

                                            Item {
                                                id: categoryItem
                                                required property int index
                                                required property var modelData
                                                width: navigationRows.width
                                                height: 58

                                                Rectangle {
                                                    id: categoryButton
                                                    readonly property bool selected:
                                                        root.section === categoryItem.modelData.id
                                                    readonly property bool first: categoryItem.index === 0
                                                    readonly property bool last: categoryItem.index
                                                        === navigationGroup.items.length - 1
                                                    readonly property real outer: Metrics.cardRadius
                                                    readonly property real inner: Metrics.segmentInnerRadius
                                                    anchors.fill: parent
                                                    topLeftRadius: selected ? height / 2 : (first ? outer : inner)
                                                    topRightRadius: topLeftRadius
                                                    bottomLeftRadius: selected ? height / 2 : (last ? outer : inner)
                                                    bottomRightRadius: bottomLeftRadius
                                                    color: selected
                                                        ? Theme.accentContainer
                                                        : (categoryHover.hovered
                                                            ? Theme.groupSurfaceRaised : Theme.groupSurface)
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

                                                    RowLayout {
                                                        anchors {
                                                            fill: parent
                                                            leftMargin: 9
                                                            rightMargin: 11
                                                        }
                                                        spacing: 10

                                                        Rectangle {
                                                            Layout.preferredWidth: 36
                                                            Layout.preferredHeight: 36
                                                            radius: width / 2
                                                            color: root.toneContainer(categoryItem.modelData.tone)

                                                            MaterialIcon {
                                                                anchors.centerIn: parent
                                                                text: categoryItem.modelData.icon
                                                                size: 19
                                                                fill: categoryButton.selected ? 1 : 0
                                                                color: root.toneColor(categoryItem.modelData.tone)
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: -1

                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: categoryItem.modelData.title
                                                                color: categoryButton.selected
                                                                    ? Theme.accentContainerInk : Theme.text
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: Metrics.appTextBody
                                                                font.weight: root.section === categoryItem.modelData.id
                                                                    ? Font.DemiBold : Font.Medium
                                                                elide: Text.ElideRight
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: categoryItem.modelData.subtitle
                                                                color: Theme.textMuted
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: Metrics.appTextCaption
                                                                elide: Text.ElideRight
                                                            }
                                                        }

                                                        MaterialIcon {
                                                            text: "chevron_right"
                                                            size: 17
                                                            color: root.section === categoryItem.modelData.id
                                                                ? Theme.accent : Theme.textMuted
                                                        }
                                                    }

                                                    HoverHandler { id: categoryHover }
                                                    TapHandler {
                                                        id: categoryTap
                                                        onTapped: ShellState.openSettings(categoryItem.modelData.id)
                                                    }
                                                    Behavior on color {
                                                        ColorAnimation { duration: Motion.fast }
                                                    }
                                                    Behavior on scale {
                                                        NumberAnimation { duration: Motion.instant }
                                                    }
                                                }

                                            }
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
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                    topMargin: 20
                    bottomMargin: 20
                }
                width: 1
                visible: root.wideNavigation
                color: Theme.divider
            }
        }

        Item {
            id: detailPane
            visible: root.wideNavigation || root.section !== "home"
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Metrics.settingsHeaderHeight

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: root.wideNavigation ? 28 : 22
                            rightMargin: 24
                            topMargin: 16
                            bottomMargin: 10
                        }
                        spacing: 13

                        IconButton {
                            visible: !root.wideNavigation
                            icon: "arrow_back"
                            accessibleName: I18n.tr("common.back")
                            onClicked: ShellState.settingsSection = "home"
                        }

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: Metrics.radiusM
                            color: root.toneContainer(root.category().tone)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.category().icon
                                size: 24
                                color: root.toneColor(root.category().tone)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            Text {
                                Layout.fillWidth: true
                                text: root.category().title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.appTextHeader
                                font.weight: Font.DemiBold
                                font.variableAxes: { "wght": 680, "wdth": 95, "opsz": 34, "GRAD": 20 }
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.category().subtitle
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.appTextSupporting
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            icon: SettingsService.loading || SystemSettingsService.loading
                                ? "progress_activity" : "refresh"
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
                }

                Flickable {
                    id: detailFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: root.wideNavigation ? 28 : 22
                    Layout.rightMargin: root.wideNavigation ? 28 : 22
                    Layout.bottomMargin: 22
                    contentWidth: width
                    contentHeight: pageFrame.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        id: pageFrame
                        width: detailFlick.width
                        height: Math.max(detailFlick.height, pageLoader.height + 16)

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
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, Metrics.settingsContentMax)
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
