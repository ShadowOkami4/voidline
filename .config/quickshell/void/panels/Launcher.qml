import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"
import "../core"
import "../services"

PanelWindow {
    id: root

    property var parentBar
    property bool isClosing: false
    property bool surfaceExpanded: false
    property bool contentReady: false
    property string queryText: ""
    property string resultMode: "root"
    property string clipboardSection: "clipboard"
    property string fileFilter: "all"
    property string fileSearchMode: "recent"
    property string fileLocation: "home"
    property string statusMessage: ""
    property int selectedIndex: 0

    readonly property bool isOpen: parentBar && ShellState.isLauncherScreen(parentBar.screen)
    readonly property bool surfaceActive: isOpen || isClosing
    readonly property bool shellQuery: resultMode === "shell"
        || queryText.trim().startsWith(">")
    readonly property bool contextualHeaderVisible: resultMode === "files"
        || resultMode === "clipboard" || shellQuery
    readonly property bool contextualHint: contextualHeaderVisible
        && results.length === 1 && results[0].kind === "hint"
    readonly property bool shellOutputVisible: shellQuery
        && queryText.trim().length === 0
        && (LauncherService.pendingShellCommand || "").length > 0
    readonly property int cornerSize: Theme.concaveRadius
    readonly property int standardBodyWidth: Metrics.launcherWidth
    readonly property int standardBodyHeight: Metrics.launcherHeight
    readonly property int targetBodyWidth: {
        if (resultMode === "overview") return overviewPage.requestedBodyWidth
        if (resultMode === "games") return gamesPage.requestedBodyWidth
        if (resultMode === "wallpaper") return wallpaperPage.requestedBodyWidth
        if (resultMode === "local-ai") return localAiPage.requestedBodyWidth
        if (resultMode === "files") return Metrics.launcherFileWidth
        if (shellQuery) return Metrics.launcherWideWidth
        if (resultMode === "clipboard") return Metrics.panelWide
        return standardBodyWidth
    }
    readonly property int targetBodyHeight: {
        if (resultMode === "overview") return overviewPage.requestedBodyHeight
        if (resultMode === "games") return gamesPage.requestedBodyHeight
        if (resultMode === "wallpaper") return wallpaperPage.requestedBodyHeight
        if (resultMode === "local-ai") return localAiPage.requestedBodyHeight
        if (resultMode === "files") return Metrics.launcherFileHeight
        return standardBodyHeight
    }
    readonly property int collapsedWidth: Metrics.launcherCollapsedWidth
    readonly property int launcherMorph: Motion.launcherMorph
    readonly property int launcherContentDelay: Motion.launcherContentDelay
    readonly property int launcherContentDuration: Motion.launcherContent
    readonly property var results: LauncherService.resultsFor(
        queryText, resultMode, clipboardSection, fileFilter, fileSearchMode)
    readonly property var selectedResult: selectedIndex >= 0
        && selectedIndex < results.length ? results[selectedIndex] : null
    readonly property bool selectedFileAvailable: selectedResult
        && selectedResult.kind === "file"

    screen: parentBar ? parentBar.screen : null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    focusable: isOpen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-launcher"
    visible: true
    color: "transparent"

    mask: Region {
        x: root.surfaceActive ? attachedSurface.x : 0
        y: root.surfaceActive ? attachedSurface.y : 0
        width: root.surfaceActive ? attachedSurface.width : 0
        height: root.surfaceActive ? attachedSurface.height : 0
    }
    HyprlandWindow.visibleMask: Region {
        x: root.surfaceActive ? attachedSurface.x : 0
        y: root.surfaceActive ? attachedSurface.y : 0
        width: root.surfaceActive ? attachedSurface.width : 0
        height: root.surfaceActive ? attachedSurface.height : 0
    }

    function iconSource(iconName) {
        if (!iconName || iconName.length === 0)
            return ""
        return iconName.startsWith("/") ? "file://" + iconName
            : (Quickshell.hasThemeIcon(iconName)
                ? Quickshell.iconPath(iconName) : "")
    }

    function resetToRoot() {
        resultMode = "root"
        ShellState.launcherPage = "root"
        queryText = ""
        searchField.text = ""
        statusMessage = ""
        searchField.forceActiveFocus()
    }

    function normalizedMode(mode) {
        const modes = ["apps", "overview", "calculator", "files", "games",
            "clipboard", "shell", "wallpaper"]
        if (FeatureRegistry.aiInstalled && AssistantService.assistantEnabled)
            modes.push("local-ai")
        return modes.indexOf(mode) >= 0 ? mode : "root"
    }

    function gridMode() {
        return resultMode === "apps"
    }

    function symbolGridMode() {
        return resultMode === "clipboard" && clipboardSection === "symbols"
    }

    function searchPlaceholder() {
        if (resultMode === "apps") return I18n.tr("launcher.searchApps")
        if (resultMode === "games") return I18n.tr("launcher.searchGames")
        if (resultMode === "calculator") return I18n.tr("calculator.typeEquation")
        if (resultMode === "files") return I18n.tr("launcher.searchFiles")
        if (resultMode === "clipboard") return clipboardSection === "clipboard"
            ? I18n.tr("launcher.searchClipboard") : (clipboardSection === "symbols"
                ? I18n.tr("launcher.searchSymbols") : I18n.tr("launcher.searchClipboardSymbols"))
        if (resultMode === "local-ai" && FeatureRegistry.aiInstalled
                && AssistantService.assistantEnabled) return AssistantService.canAsk
            ? I18n.tr("launcher.askAssistant")
            : I18n.tr("launcher.assistantStatus")
        if (shellQuery) return I18n.tr("launcher.typeCommand")
        return ""
    }

    function contextualTitle() {
        if (resultMode === "files") return I18n.tr("launcher.findFiles")
        if (resultMode === "clipboard") return I18n.tr("launcher.clipboardSymbols")
        if (shellQuery) return I18n.tr("launcher.shell")
        return ""
    }

    function contextualSubtitle() {
        if (resultMode === "files") return I18n.tr("launcher.filesSubtitle")
        if (resultMode === "clipboard") return I18n.tr("launcher.clipboardSubtitle")
        if (shellQuery) return I18n.tr("launcher.shellSubtitle")
        return ""
    }

    function contextualIcon() {
        if (resultMode === "files") return "manage_search"
        if (resultMode === "clipboard") return "content_paste_search"
        if (shellQuery) return "terminal"
        return "search"
    }

    function applyLauncherView() {
        if (resultMode === "clipboard") {
            clipboardSection = ShellState.launcherView === "symbols"
                ? "symbols" : "clipboard"
        } else if (resultMode === "files") {
            const filters = ["all", "documents", "images", "media", "code"]
            fileFilter = filters.indexOf(ShellState.launcherView) >= 0
                ? ShellState.launcherView : "all"
        }
    }

    function applyRequestedQuery() {
        const requested = String(ShellState.launcherQuery || "").trim()
        if (requested.length === 0)
            return
        searchField.text = requested
        if (resultMode === "files") {
            LauncherService.searchFiles(requested,
                ShellState.launcherFileMode, ShellState.launcherFileLocation)
            ShellState.launcherFileMode = "name"
            ShellState.launcherFileLocation = "home"
        }
        ShellState.launcherQuery = ""
    }

    function moveSelection(offset) {
        if (results.length === 0)
            return
        selectedIndex = (selectedIndex + offset + results.length) % results.length
        if (gridMode() && !shellQuery)
            appGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
        else if (symbolGridMode())
            symbolGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
        else
            resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function setFileSearchMode(mode) {
        fileSearchMode = mode
        LauncherService.searchFiles(searchField.text, fileSearchMode, fileLocation)
    }

    function setFileLocation(location) {
        fileLocation = location
        LauncherService.searchFiles(searchField.text, fileSearchMode, fileLocation)
    }

    function cycleFileLocation(offset) {
        const locations = ["home", "desktop", "documents", "downloads",
            "music", "pictures", "videos", "projects"]
        const current = Math.max(0, locations.indexOf(fileLocation))
        setFileLocation(locations[(current + offset + locations.length) % locations.length])
    }

    function activate(index) {
        if (index < 0 || index >= results.length)
            return
        const result = results[index]
        if (result.kind === "module") {
            if (result.id === "settings") {
                ShellState.openSettings()
                return
            } else if (result.id === "apps") {
                resultMode = "apps"
                ShellState.launcherPage = "apps"
                searchField.text = ""
            } else if (result.id === "overview") {
                resultMode = "overview"
                ShellState.launcherPage = "overview"
                searchField.text = ""
                Qt.callLater(() => overviewPage.forceActiveFocus())
            } else if (result.id === "shell") {
                resultMode = "shell"
                ShellState.launcherPage = "shell"
                searchField.text = ""
            } else {
                resultMode = normalizedMode(result.id)
                searchField.text = ""
                if (resultMode === "files") {
                    fileFilter = "all"
                    fileSearchMode = "recent"
                    fileLocation = "home"
                    LauncherService.searchFiles("", fileSearchMode, fileLocation)
                } else if (resultMode === "clipboard") {
                    clipboardSection = "clipboard"
                    LauncherService.refreshClipboard()
                } else if (resultMode === "local-ai") {
                    AssistantService.refreshCapabilities()
                }
            }
            statusMessage = ""
            if (resultMode === "overview")
                overviewPage.forceActiveFocus()
            else
                searchField.forceActiveFocus()
            return
        }
        const executed = LauncherService.execute(result, parentBar ? parentBar.screen.name : "")
        if (executed && result.kind === "shell") {
            searchField.text = ""
            searchField.forceActiveFocus()
            return
        }
        if (!executed && LauncherService.actionMessage.length > 0) {
            statusMessage = LauncherService.actionMessage
            statusTimer.restart()
        }
    }

    function backOrClose() {
        if (searchField.text.length > 0) {
            searchField.text = ""
        } else if (resultMode !== "root") {
            resetToRoot()
        } else {
            ShellState.closePanels()
        }
    }

    onResultsChanged: {
        selectedIndex = results.length > 0 && results[0].kind !== "hint" ? 0 : -1
        if (resultList)
            resultList.positionViewAtBeginning()
        if (appGrid)
            appGrid.positionViewAtBeginning()
        if (symbolGrid)
            symbolGrid.positionViewAtBeginning()
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeTimer.stop()
            concealTimer.stop()
            isClosing = false
            surfaceExpanded = false
            contentReady = false
            resultMode = normalizedMode(ShellState.launcherPage)
            queryText = ""
            clipboardSection = "clipboard"
            fileFilter = "all"
            fileSearchMode = "recent"
            fileLocation = "home"
            applyLauncherView()
            statusMessage = ""
            searchField.text = ""
            Qt.callLater(() => root.applyRequestedQuery())
            LauncherService.refreshApplications()
            LauncherService.refreshToolCapabilities()
            if (resultMode === "local-ai" && FeatureRegistry.aiInstalled
                    && AssistantService.assistantEnabled)
                AssistantService.refreshCapabilities()
            if (resultMode === "files")
                LauncherService.searchFiles("", "recent", "home")
            if (resultMode === "clipboard")
                LauncherService.refreshClipboard()
            expandTimer.restart()
            revealTimer.restart()
            focusTimer.restart()
        } else {
            expandTimer.stop()
            revealTimer.stop()
            focusTimer.stop()
            statusTimer.stop()
            surfaceExpanded = false
            isClosing = true
            concealTimer.restart()
            closeTimer.restart()
        }
    }

    Connections {
        target: ShellState
        ignoreUnknownSignals: true

        function onLauncherPageChanged() {
            if (!root.isOpen || !parentBar
                    || ShellState.launcherScreenName !== parentBar.screen.name)
                return
            const requestedMode = root.normalizedMode(ShellState.launcherPage)
            if (root.resultMode === requestedMode)
                return
            root.resultMode = requestedMode
            root.queryText = ""
            searchField.text = ""
            root.statusMessage = ""
            root.applyLauncherView()
            Qt.callLater(() => root.applyRequestedQuery())
            if (requestedMode === "clipboard")
                LauncherService.refreshClipboard()
            if (requestedMode === "files")
                LauncherService.searchFiles("", "recent", "home")
            if (requestedMode === "local-ai" && FeatureRegistry.aiInstalled
                    && AssistantService.assistantEnabled)
                AssistantService.refreshCapabilities()
            if (requestedMode === "overview")
                Qt.callLater(() => overviewPage.forceActiveFocus())
            else
                Qt.callLater(() => searchField.forceActiveFocus())
        }

        function onLauncherViewChanged() {
            if (!root.isOpen || !parentBar
                    || ShellState.launcherScreenName !== parentBar.screen.name)
                return
            root.applyLauncherView()
        }
    }

    Timer {
        id: expandTimer
        interval: 12
        onTriggered: root.surfaceExpanded = true
    }
    Timer {
        id: revealTimer
        interval: root.launcherContentDelay
        onTriggered: root.contentReady = true
    }
    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (root.resultMode === "overview")
                overviewPage.forceActiveFocus()
            else
                searchField.forceActiveFocus()
        }
    }
    Timer {
        id: concealTimer
        interval: Math.max(0, root.launcherMorph - root.launcherContentDelay - root.launcherContentDuration)
        onTriggered: root.contentReady = false
    }
    Timer {
        id: closeTimer
        interval: root.launcherMorph + 16
        onTriggered: root.isClosing = false
    }
    Timer {
        id: statusTimer
        interval: 1800
        onTriggered: root.statusMessage = ""
    }

    HyprlandFocusGrab {
        active: root.isOpen
        windows: [root]
        onCleared: ShellState.closePanels()
    }

    Item {
        id: attachedSurface
        readonly property bool attached: Theme.panelsAttached
        readonly property bool topAttached: Appearance.barPosition === "top"
        readonly property bool bottomAttached: Appearance.barPosition === "bottom"
        readonly property bool leftAttached: Appearance.barPosition === "left"
        x: topAttached || bottomAttached
            ? Math.round((root.width - width) / 2)
            : (Appearance.barPosition === "left"
                ? Theme.panelInset
                : root.width - Theme.panelInset - width)
        y: topAttached ? Theme.panelInset
            : (bottomAttached ? root.height - Theme.panelInset - height
                : Math.round((root.height - height) / 2))
        width: root.surfaceExpanded
            ? root.targetBodyWidth + ((topAttached || bottomAttached)
                ? root.cornerSize * 2 : 0)
            : (topAttached || bottomAttached ? root.collapsedWidth : 0)
        height: root.surfaceExpanded
            ? root.targetBodyHeight + (topAttached || bottomAttached
                ? 0 : root.cornerSize * 2)
            : (topAttached || bottomAttached ? 0 : root.collapsedWidth)
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: root.surfaceExpanded && root.contentReady
                    ? Motion.panelResize : root.launcherMorph
                easing.type: Motion.morphCurve
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.surfaceExpanded && root.contentReady
                    ? Motion.panelResize : root.launcherMorph
                easing.type: Motion.morphCurve
            }
        }

        Shape {
            id: leftJoin
            anchors { top: parent.top; left: parent.left }
            width: root.cornerSize
            height: root.cornerSize
            preferredRendererType: Shape.CurveRenderer
            visible: attachedSurface.attached && attachedSurface.topAttached

            ShapePath {
                id: leftJoinPath
                readonly property real curve: 0.5522847498
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: Theme.panel
                startX: 0
                startY: 0
                PathLine { x: leftJoin.width; y: 0 }
                PathLine { x: leftJoin.width; y: leftJoin.height }
                PathCubic {
                    control1X: leftJoin.width
                    control1Y: leftJoin.height * (1 - leftJoinPath.curve)
                    control2X: leftJoin.width * leftJoinPath.curve
                    control2Y: 0
                    x: 0
                    y: 0
                }
            }
        }

        Shape {
            id: rightJoin
            anchors { top: parent.top; right: parent.right }
            width: root.cornerSize
            height: root.cornerSize
            preferredRendererType: Shape.CurveRenderer
            visible: attachedSurface.attached && attachedSurface.topAttached

            ShapePath {
                id: rightJoinPath
                readonly property real curve: 0.5522847498
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: Theme.panel
                startX: rightJoin.width
                startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: rightJoin.height }
                PathCubic {
                    control1X: 0
                    control1Y: rightJoin.height * (1 - rightJoinPath.curve)
                    control2X: rightJoin.width * (1 - rightJoinPath.curve)
                    control2Y: 0
                    x: rightJoin.width
                    y: 0
                }
            }
        }

        ConcaveJoin {
            x: 0
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-left"
            visible: attachedSurface.attached && attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "bottom-right"
            visible: attachedSurface.attached && attachedSurface.bottomAttached
        }
        ConcaveJoin {
            x: 0
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "left-top"
            visible: attachedSurface.attached && attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: 0
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "left-bottom"
            visible: attachedSurface.attached && attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: 0
            width: root.cornerSize
            height: root.cornerSize
            orientation: "right-top"
            visible: attachedSurface.attached && !attachedSurface.topAttached
                && !attachedSurface.bottomAttached
                && !attachedSurface.leftAttached
        }
        ConcaveJoin {
            x: attachedSurface.width - width
            y: attachedSurface.height - height
            width: root.cornerSize
            height: root.cornerSize
            orientation: "right-bottom"
            visible: attachedSurface.attached && !attachedSurface.topAttached
                && !attachedSurface.bottomAttached
                && !attachedSurface.leftAttached
        }

        Item {
            id: panelBody
            x: attachedSurface.topAttached || attachedSurface.bottomAttached
                ? root.cornerSize : 0
            y: attachedSurface.topAttached || attachedSurface.bottomAttached
                ? 0 : root.cornerSize
            width: Math.max(1, attachedSurface.width
                - ((attachedSurface.topAttached || attachedSurface.bottomAttached)
                    ? root.cornerSize * 2 : 0))
            height: Math.max(1, attachedSurface.height
                - (attachedSurface.topAttached || attachedSurface.bottomAttached
                    ? 0 : root.cornerSize * 2))
            clip: true

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: attachedSurface.attached && attachedSurface.topAttached

                ShapePath {
                    id: panelBodyPath
                    readonly property real bottomRadius: Math.min(Theme.panelRadius, panelBody.width / 2, panelBody.height / 2)
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillColor: Theme.panel
                    startX: 0
                    startY: 0
                    PathLine { x: panelBody.width; y: 0 }
                    PathLine { x: panelBody.width; y: panelBody.height - panelBodyPath.bottomRadius }
                    PathQuad {
                        controlX: panelBody.width
                        controlY: panelBody.height
                        x: panelBody.width - panelBodyPath.bottomRadius
                        y: panelBody.height
                    }
                    PathLine { x: panelBodyPath.bottomRadius; y: panelBody.height }
                    PathQuad {
                        controlX: 0
                        controlY: panelBody.height
                        x: 0
                        y: panelBody.height - panelBodyPath.bottomRadius
                    }
                    PathLine { x: 0; y: 0 }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: !attachedSurface.attached || !attachedSurface.topAttached
                radius: Theme.panelRadius
                color: Theme.panel
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && attachedSurface.bottomAttached
            }
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && attachedSurface.leftAttached
            }
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }
                width: Theme.panelRadius
                color: Theme.panel
                visible: attachedSurface.attached && !attachedSurface.topAttached
                    && !attachedSurface.bottomAttached
                    && !attachedSurface.leftAttached
            }

            Item {
                id: contentViewport
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 14
                }
                width: root.targetBodyWidth - 28
                height: root.targetBodyHeight - 28
                opacity: root.contentReady ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.launcherContentDuration
                        easing.type: root.isOpen ? Easing.OutCubic : Easing.InCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: contextualHeader
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            height: root.resultMode === "files"
                                ? Metrics.launcherFileHeaderHeight
                                : (root.resultMode === "clipboard" ? 104 : 68)
                            radius: Theme.radiusLarge
                            color: Theme.surfaceHigh
                            visible: root.contextualHeaderVisible
                            z: 2

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    spacing: 9

                                    IconButton {
                                        size: 44
                                        icon: "arrow_back"
                                        accessibleName: I18n.tr("assistant.backToCommands")
                                        onClicked: root.resetToRoot()
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 44
                                        radius: Theme.radiusMedium
                                        color: Theme.accentContainer

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: root.contextualIcon()
                                            size: 23
                                            color: Theme.accent
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -1
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.contextualTitle()
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 19
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.contextualSubtitle()
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Metrics.appTextCaption
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    spacing: Metrics.spaceXS
                                    visible: root.resultMode === "files"

                                    Repeater {
                                        model: [
                                            { key: "recent", title: I18n.tr("files.recent"), icon: "history" },
                                            { key: "name", title: I18n.tr("files.filename"), icon: "text_fields" },
                                            { key: "content", title: I18n.tr("files.content"), icon: "find_in_page" }
                                        ]
                                        delegate: Rectangle {
                                            id: searchModeChip
                                            required property var modelData
                                            readonly property bool selected: root.fileSearchMode === modelData.key
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Metrics.radiusS
                                            color: selected ? Theme.secondaryContainer : Theme.surfaceLow
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: Metrics.spaceXS
                                                MaterialIcon {
                                                    text: searchModeChip.modelData.icon
                                                    size: Metrics.iconS
                                                    color: searchModeChip.selected ? Theme.secondary : Theme.textMuted
                                                }
                                                Text {
                                                    text: searchModeChip.modelData.title
                                                    color: searchModeChip.selected ? Theme.secondary : Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextCaption
                                                    font.weight: Font.Bold
                                                }
                                            }
                                            TapHandler {
                                                onTapped: {
                                                    root.setFileSearchMode(searchModeChip.modelData.key)
                                                }
                                            }
                                        }
                                    }

                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    columns: 8
                                    rowSpacing: Metrics.space2XS
                                    columnSpacing: Metrics.spaceXS
                                    visible: root.resultMode === "files"

                                    Repeater {
                                        model: [
                                            { key: "home", title: I18n.tr("files.home") },
                                            { key: "desktop", title: I18n.tr("files.desktop") },
                                            { key: "documents", title: I18n.tr("files.documents") },
                                            { key: "downloads", title: I18n.tr("files.downloads") },
                                            { key: "music", title: I18n.tr("files.music") },
                                            { key: "pictures", title: I18n.tr("files.pictures") },
                                            { key: "videos", title: I18n.tr("files.videos") },
                                            { key: "projects", title: I18n.tr("files.projects") }
                                        ]
                                        delegate: Rectangle {
                                            id: locationChip
                                            required property var modelData
                                            readonly property bool selected: root.fileLocation === modelData.key
                                            Layout.fillWidth: true
                                             Layout.preferredHeight: 30
                                            radius: Metrics.radiusS
                                            color: selected ? Theme.accentContainer
                                                : (locationHover.hovered ? Theme.surfaceHover : Theme.surfaceLow)
                                            Text {
                                                anchors.centerIn: parent
                                                text: locationChip.modelData.title
                                                color: locationChip.selected ? Theme.accent : Theme.textMuted
                                                font.family: Theme.fontFamily
                                                 font.pixelSize: Metrics.appTextCaption
                                                 font.weight: Font.Bold
                                                 elide: Text.ElideRight
                                                 width: locationChip.width - Metrics.spaceS
                                                 horizontalAlignment: Text.AlignHCenter
                                            }
                                            HoverHandler { id: locationHover }
                                            TapHandler {
                                                onTapped: {
                                                    root.setFileLocation(locationChip.modelData.key)
                                                }
                                            }
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    spacing: 6
                                    visible: root.resultMode === "clipboard"
                                        || root.resultMode === "files"

                                    Repeater {
                                        model: root.resultMode === "files" ? [
                                            { key: "all", title: I18n.tr("files.all"), icon: "draft" },
                                            { key: "documents", title: I18n.tr("files.docs"), icon: "description" },
                                            { key: "images", title: I18n.tr("files.images"), icon: "image" },
                                            { key: "media", title: I18n.tr("files.media"), icon: "movie" },
                                            { key: "code", title: I18n.tr("files.code"), icon: "code" }
                                        ] : [
                                            { key: "clipboard", title: I18n.tr("launcher.clipboard"), icon: "content_paste" },
                                            { key: "symbols", title: I18n.tr("launcher.symbols"), icon: "emoji_symbols" }
                                        ]

                                        delegate: Rectangle {
                                            id: contextFilter
                                            required property var modelData
                                            readonly property bool selected:
                                                root.resultMode === "files"
                                                    ? root.fileFilter === modelData.key
                                                    : root.clipboardSection === modelData.key
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Theme.radiusSmall
                                            color: selected ? Theme.accentContainer
                                                : (filterHover.hovered ? Theme.surfaceHover : Theme.surfaceLow)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 5
                                                MaterialIcon {
                                                    text: contextFilter.modelData.icon
                                                    size: 15
                                                    color: contextFilter.selected
                                                        ? Theme.accent : Theme.textMuted
                                                }
                                                Text {
                                                    text: contextFilter.modelData.title
                                                    color: contextFilter.selected
                                                        ? Theme.accent : Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                     font.pixelSize: Metrics.appTextCaption
                                                    font.weight: Font.Bold
                                                }
                                            }

                                            HoverHandler { id: filterHover }
                                            TapHandler {
                                                onTapped: {
                                                    if (root.resultMode === "files")
                                                        root.fileFilter = contextFilter.modelData.key
                                                    else
                                                        root.clipboardSection = contextFilter.modelData.key
                                                }
                                            }
                                            Behavior on color {
                                                ColorAnimation { duration: Motion.fast }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    spacing: Metrics.spaceXS
                                    visible: root.resultMode === "files"

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.selectedFileAvailable
                                            ? root.selectedResult.path
                                            : I18n.tr("files.selectResult")
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                         font.pixelSize: Metrics.appTextCaption
                                        elide: Text.ElideMiddle
                                    }

                                    Repeater {
                                        model: [
                                            { title: I18n.tr("files.openFolder"), icon: "folder_open", action: "folder" },
                                            { title: I18n.tr("files.copyPath"), icon: "content_copy", action: "copy" }
                                        ]
                                        delegate: Rectangle {
                                            id: fileAction
                                            required property var modelData
                                            Layout.preferredWidth: 108
                                            Layout.fillHeight: true
                                            radius: Metrics.radiusS
                                            color: fileActionHover.hovered && root.selectedFileAvailable
                                                ? Theme.accentContainer : Theme.surfaceLow
                                            opacity: root.selectedFileAvailable ? 1 : 0.45
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: Metrics.spaceXS
                                                MaterialIcon {
                                                    text: fileAction.modelData.icon
                                                    size: Metrics.iconS
                                                    color: Theme.accent
                                                }
                                                Text {
                                                    text: fileAction.modelData.title
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                     font.pixelSize: Metrics.appTextCaption
                                                    font.weight: Font.Bold
                                                }
                                            }
                                            HoverHandler { id: fileActionHover }
                                            TapHandler {
                                                enabled: root.selectedFileAvailable
                                                onTapped: {
                                                    if (fileAction.modelData.action === "folder")
                                                        LauncherService.openContainingFolder(root.selectedResult)
                                                    else {
                                                        LauncherService.copyFilePath(root.selectedResult)
                                                        root.statusMessage = LauncherService.actionMessage
                                                        statusTimer.restart()
                                                    }
                                                }
                                            }
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            id: resultList
                            anchors.fill: parent
                            anchors.topMargin: contextualHeader.visible
                                ? contextualHeader.height + 10 : 0
                            visible: (root.resultMode !== "overview"
                                && root.resultMode !== "games"
                                && root.resultMode !== "wallpaper"
                                && root.resultMode !== "local-ai"
                                && !root.gridMode() && !root.symbolGridMode()
                                && !root.shellOutputVisible) || (root.shellQuery
                                    && !root.shellOutputVisible)
                            clip: true
                            spacing: 2
                            model: visible && !root.contextualHint ? root.results : []
                            currentIndex: root.selectedIndex
                            boundsBehavior: Flickable.StopAtBounds
                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: Motion.launcherContent

                            highlight: Rectangle {
                                radius: Theme.radiusMedium
                                color: Theme.accentContainer
                            }

                            delegate: Item {
                                id: commandDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: root.resultMode === "root" ? 46 : 54

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 10
                                        rightMargin: 10
                                    }
                                    spacing: 11
                                    scale: commandTap.pressed ? 0.985 : 1

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: Theme.radiusSmall
                                        color: commandDelegate.index === root.selectedIndex
                                            ? Theme.accent : "transparent"

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            size: 20
                                            color: commandDelegate.index === root.selectedIndex
                                                ? Theme.accentInk : Theme.textMuted
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: Motion.fast }
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: commandDelegate.index === root.selectedIndex
                                                ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.description || ""
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                HoverHandler {
                                    onHoveredChanged: {
                                        if (hovered)
                                            root.selectedIndex = commandDelegate.index
                                    }
                                }
                                TapHandler {
                                    id: commandTap
                                    onTapped: root.activate(commandDelegate.index)
                                }
                            }
                        }

                        ColumnLayout {
                            anchors {
                                top: contextualHeader.bottom
                                topMargin: Metrics.spaceL
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: Math.min(parent.width - Metrics.spaceXL * 2,
                                Math.round(360 * Metrics.scale))
                            spacing: Metrics.spaceS
                            visible: root.resultMode === "files" && root.contextualHint

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                radius: Metrics.radiusL
                                color: Theme.surfaceHigh
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: root.results.length > 0 ? root.results[0].icon : "search_off"
                                    size: Metrics.iconL
                                    color: Theme.accent
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.results.length > 0 ? root.results[0].title : I18n.tr("files.noResults")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.appTextTitle
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.results.length > 0 ? root.results[0].description
                                    : I18n.tr("files.tryAnotherSearch")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.appTextSupporting
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                        }

                        GridView {
                            id: appGrid
                            anchors.fill: parent
                            visible: root.gridMode() && !root.shellQuery
                            clip: true
                            model: visible ? root.results : []
                            cellWidth: width / 5
                            cellHeight: 86
                            currentIndex: root.selectedIndex
                            boundsBehavior: Flickable.StopAtBounds
                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: Motion.launcherContent

                            highlight: Rectangle {
                                radius: Theme.radiusMedium
                                color: Theme.surfaceHigh
                            }

                            delegate: Item {
                                id: appDelegate
                                required property var modelData
                                required property int index
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                ColumnLayout {
                                    anchors {
                                        fill: parent
                                        margins: 6
                                    }
                                    spacing: 5
                                    scale: appTap.pressed ? 0.96 : 1

                                    ApplicationIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        source: root.iconSource(modelData.icon)
                                        sourcePixelSize: 52
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: appDelegate.index === root.selectedIndex ? Theme.accent : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                HoverHandler {
                                    onHoveredChanged: {
                                        if (hovered)
                                            root.selectedIndex = appDelegate.index
                                    }
                                }
                                TapHandler {
                                    id: appTap
                                    onTapped: root.activate(appDelegate.index)
                                }
                            }
                        }

                        GridView {
                            id: symbolGrid
                            anchors.fill: parent
                            anchors.topMargin: contextualHeader.height + 10
                            visible: root.symbolGridMode()
                            clip: true
                            model: visible && !root.contextualHint ? root.results : []
                            cellWidth: width / 8
                            cellHeight: 64
                            currentIndex: root.selectedIndex
                            boundsBehavior: Flickable.StopAtBounds
                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: Motion.fast

                            highlight: Rectangle {
                                radius: Theme.radiusMedium
                                color: Theme.accentContainer
                            }

                            delegate: Item {
                                id: symbolDelegate
                                required property var modelData
                                required property int index
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight
                                scale: symbolTap.pressed ? 0.94 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.value || ""
                                    color: Theme.text
                                    font.pixelSize: 27
                                }

                                HoverHandler {
                                    onHoveredChanged: {
                                        if (hovered)
                                            root.selectedIndex = symbolDelegate.index
                                    }
                                }
                                TapHandler {
                                    id: symbolTap
                                    onTapped: root.activate(symbolDelegate.index)
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Motion.instant
                                        easing.type: Motion.expressiveCurve
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: shellOutputPanel
                            anchors {
                                top: contextualHeader.bottom
                                topMargin: 10
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            radius: Theme.radiusLarge
                            color: Theme.surfaceLow
                            visible: root.shellOutputVisible
                            clip: true

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 12
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: Theme.radiusSmall
                                        color: LauncherService.shellRunning
                                            ? Theme.accentContainer
                                            : (LauncherService.shellExitCode === 0
                                                ? Theme.accentContainer : Theme.tertiaryContainer)

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: LauncherService.shellRunning
                                                ? "progress_activity"
                                                : (LauncherService.shellExitCode === 0
                                                    ? "check_circle" : "error")
                                            size: 19
                                            color: LauncherService.shellRunning
                                                || LauncherService.shellExitCode === 0
                                                ? Theme.accent : Theme.danger
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -1
                                        Text {
                                            Layout.fillWidth: true
                                            text: LauncherService.pendingShellCommand || ""
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: LauncherService.shellRunning
                                                ? "Running…"
                                                : "Exited with code " + LauncherService.shellExitCode
                                            color: LauncherService.shellExitCode === 0
                                                ? Theme.textMuted : Theme.danger
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: shellOutputAction.implicitWidth + 20
                                        Layout.preferredHeight: 32
                                        radius: Theme.radiusSmall
                                        color: shellActionHover.hovered
                                            ? Theme.accentContainer : Theme.surfaceHigh

                                        Text {
                                            id: shellOutputAction
                                            anchors.centerIn: parent
                                            text: LauncherService.shellRunning ? "Stop" : "Clear"
                                            color: shellActionHover.hovered
                                                ? Theme.accent : Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                        HoverHandler { id: shellActionHover }
                                        TapHandler {
                                            onTapped: {
                                                if (LauncherService.shellRunning)
                                                    LauncherService.stopShellCommand()
                                                else
                                                    LauncherService.clearShellOutput()
                                            }
                                        }
                                    }
                                }

                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    contentWidth: width
                                    contentHeight: shellOutputText.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds

                                    Text {
                                        id: shellOutputText
                                        width: parent.width
                                        text: LauncherService.shellRunning
                                            ? I18n.tr("launcher.waitingForCommand")
                                            : (LauncherService.shellDisplay || "")
                                        color: Theme.text
                                        font.family: "monospace"
                                        font.pixelSize: 11
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }
                        }

                        Overview {
                            id: overviewPage
                            anchors.fill: parent
                            shellScreen: parentBar ? parentBar.screen : null
                            active: root.isOpen && root.resultMode === "overview"
                            enabled: active
                            opacity: active && root.contentReady ? 1 : 0
                            visible: opacity > 0
                            onBack: root.resetToRoot()

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: overviewPage.active ? Motion.pageEnter : Motion.pageExit
                                    easing.type: overviewPage.active ? Motion.pageCurve : Motion.pageExitCurve
                                }
                            }
                        }

                        Loader {
                            id: gamesPage
                            anchors.fill: parent
                            readonly property int requestedBodyWidth: Math.max(520,
                                Math.min(880, parentBar && parentBar.screen
                                    ? parentBar.screen.width - 100 : 880))
                            readonly property int requestedBodyHeight: 500
                            readonly property bool artworkPickerOpen: item
                                ? item.artworkPickerOpen : false
                            active: root.surfaceActive && root.resultMode === "games"
                            asynchronous: true
                            enabled: active
                            opacity: active && root.contentReady ? 1 : 0
                            visible: opacity > 0
                            sourceComponent: gamesComponent

                            function closeArtworkPicker() {
                                if (item)
                                    item.closeArtworkPicker()
                            }
                            function selectOffset(offset) {
                                if (item)
                                    item.selectOffset(offset)
                            }
                            function launchSelected() {
                                if (item)
                                    item.launchSelected()
                            }

                            onLoaded: {
                                item.shellScreen = Qt.binding(() => parentBar
                                    ? parentBar.screen : null)
                                item.query = Qt.binding(() => root.queryText)
                                item.active = Qt.binding(() => gamesPage.active
                                    && root.contentReady)
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: gamesPage.active ? Motion.pageEnter : Motion.pageExit
                                    easing.type: gamesPage.active ? Motion.pageCurve : Motion.pageExitCurve
                                }
                            }
                        }

                        Connections {
                            target: gamesPage.item
                            ignoreUnknownSignals: true
                            function onBack() { root.resetToRoot() }
                            function onRequestSearchFocus() { searchField.forceActiveFocus() }
                        }
                        Component { id: gamesComponent; GamesPage {} }

                        Loader {
                            id: wallpaperPage
                            anchors.fill: parent
                            readonly property int requestedBodyWidth: 720
                            readonly property int requestedBodyHeight: 610
                            active: root.surfaceActive && root.resultMode === "wallpaper"
                            asynchronous: true
                            enabled: active
                            opacity: active && root.contentReady ? 1 : 0
                            visible: opacity > 0
                            sourceComponent: wallpaperComponent

                            onLoaded: item.active = Qt.binding(() => wallpaperPage.active
                                && root.contentReady)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: wallpaperPage.active
                                        ? Motion.pageEnter : Motion.pageExit
                                    easing.type: wallpaperPage.active
                                        ? Motion.pageCurve : Motion.pageExitCurve
                                }
                            }
                        }

                        Connections {
                            target: wallpaperPage.item
                            ignoreUnknownSignals: true
                            function onBack() { root.resetToRoot() }
                        }
                        Component { id: wallpaperComponent; WallpaperPage {} }

                        Loader {
                            id: localAiPage
                            anchors.fill: parent
                            readonly property int requestedBodyWidth: 640
                            readonly property int requestedBodyHeight: 574
                            active: root.surfaceActive && root.resultMode === "local-ai"
                            asynchronous: true
                            enabled: active
                            opacity: active && root.contentReady ? 1 : 0
                            visible: opacity > 0
                            sourceComponent: localAiComponent

                            onLoaded: item.active = Qt.binding(() => localAiPage.active
                                && root.contentReady)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: localAiPage.active
                                        ? Motion.pageEnter : Motion.pageExit
                                    easing.type: localAiPage.active
                                        ? Motion.pageCurve : Motion.pageExitCurve
                                }
                            }
                        }

                        Connections {
                            target: localAiPage.item
                            ignoreUnknownSignals: true
                            function onBack() { root.resetToRoot() }
                            function onUseSuggestion(value) {
                                searchField.text = value
                                searchField.forceActiveFocus()
                            }
                        }
                        Component { id: localAiComponent; LocalAiPage {} }

                        ColumnLayout {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: contextualHeader.visible
                                ? (contextualHeader.height + 10) / 2 : 0
                            spacing: 8
                            visible: root.contextualHint
                                && !root.shellOutputVisible

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                radius: Theme.radiusLarge
                                color: Theme.accentContainer

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: root.results.length > 0
                                        ? root.results[0].icon : "search"
                                    size: 29
                                    color: Theme.accent
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.results.length > 0
                                    ? root.results[0].title : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.results.length > 0
                                    ? root.results[0].description : ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 7
                            visible: root.resultMode !== "overview"
                                && root.resultMode !== "games"
                                && root.resultMode !== "wallpaper"
                                && root.resultMode !== "local-ai"
                                && root.results.length === 0 && !root.contextualHint
                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "search_off"
                                size: 28
                                color: Theme.textMuted
                            }
                            Text {
                                text: I18n.tr("launcher.noResults")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: 5
                            }
                            width: statusLabel.implicitWidth + 24
                            height: 32
                            radius: Theme.radiusSmall
                            color: Theme.surfaceHigh
                            visible: root.statusMessage.length > 0
                            opacity: visible ? 1 : 0

                            Text {
                                id: statusLabel
                                anchors.centerIn: parent
                                text: root.statusMessage
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: Theme.radiusMedium
                        color: root.shellQuery ? Theme.accentContainer : Theme.surfaceLow

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 8
                            }
                            spacing: 8

                            MaterialIcon {
                                text: root.resultMode !== "root" && !root.shellQuery
                                    ? "arrow_back" : (root.shellQuery ? "terminal" : "search")
                                size: 18
                                color: root.shellQuery ? Theme.accent : Theme.textMuted

                                TapHandler {
                                    enabled: root.resultMode !== "root" && !root.shellQuery
                                    onTapped: {
                                        if (root.resultMode === "games" && gamesPage.artworkPickerOpen)
                                            gamesPage.closeArtworkPicker()
                                        else
                                            root.resetToRoot()
                                    }
                                }
                            }

                            Text {
                                text: root.shellQuery ? "$" : ">"
                                visible: root.resultMode === "root" || root.shellQuery
                                color: root.shellQuery ? Theme.accent : Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            TextInput {
                                id: searchField
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Theme.text
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                visible: root.resultMode !== "overview"
                                    && root.resultMode !== "wallpaper"
                                    && !(root.resultMode === "games" && gamesPage.artworkPickerOpen)

                                Text {
                                    anchors.fill: parent
                                    text: root.searchPlaceholder()
                                    color: Theme.textMuted
                                    font: searchField.font
                                    verticalAlignment: Text.AlignVCenter
                                    visible: searchField.text.length === 0
                                }

                                onTextChanged: {
                                    if (root.resultMode === "root" && text === ">") {
                                        root.resultMode = "shell"
                                        ShellState.launcherPage = "shell"
                                        Qt.callLater(() => searchField.text = "")
                                        return
                                    }
                                    root.queryText = text
                                    if (root.resultMode === "files") {
                                        if (text.length > 0 && root.fileSearchMode === "recent")
                                            root.fileSearchMode = "name"
                                        LauncherService.searchFiles(text,
                                            root.fileSearchMode, root.fileLocation)
                                    }
                                }

                                Keys.onPressed: event => {
                                    const gridColumns = root.symbolGridMode() ? 8 : 5
                                    if (root.resultMode === "files"
                                            && (event.modifiers & Qt.AltModifier)
                                            && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                                        root.setFileSearchMode(["recent", "name", "content"][event.key - Qt.Key_1])
                                        event.accepted = true
                                    } else if (root.resultMode === "files"
                                            && (event.modifiers & Qt.ControlModifier)
                                            && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                                        root.fileFilter = ["all", "documents", "images", "media", "code"][event.key - Qt.Key_1]
                                        event.accepted = true
                                    } else if (root.resultMode === "files"
                                            && (event.modifiers & Qt.AltModifier)
                                            && event.key === Qt.Key_Left) {
                                        root.cycleFileLocation(-1)
                                        event.accepted = true
                                    } else if (root.resultMode === "files"
                                            && (event.modifiers & Qt.AltModifier)
                                            && event.key === Qt.Key_Right) {
                                        root.cycleFileLocation(1)
                                        event.accepted = true
                                    } else if (root.resultMode === "games" && event.key === Qt.Key_Tab) {
                                        gamesPage.selectOffset((event.modifiers & Qt.ShiftModifier) !== 0 ? -1 : 1)
                                        event.accepted = true
                                    } else if (root.resultMode === "games" && text.length === 0
                                            && event.key === Qt.Key_Left) {
                                        gamesPage.selectOffset(-1)
                                        event.accepted = true
                                    } else if (root.resultMode === "games" && text.length === 0
                                            && event.key === Qt.Key_Right) {
                                        gamesPage.selectOffset(1)
                                        event.accepted = true
                                    } else if (root.resultMode === "games" && event.key === Qt.Key_Down) {
                                        gamesPage.selectOffset(1)
                                        event.accepted = true
                                    } else if (root.resultMode === "games" && event.key === Qt.Key_Up) {
                                        gamesPage.selectOffset(-1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down) {
                                        root.moveSelection((root.gridMode() && !root.shellQuery)
                                            || root.symbolGridMode() ? gridColumns : 1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.moveSelection((root.gridMode() && !root.shellQuery)
                                            || root.symbolGridMode() ? -gridColumns : -1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_PageDown) {
                                        root.moveSelection(5)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_PageUp) {
                                        root.moveSelection(-5)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Home) {
                                        root.selectedIndex = root.results.length > 0 ? 0 : -1
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_End) {
                                        root.selectedIndex = root.results.length - 1
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Tab
                                            && root.resultMode !== "games") {
                                        root.moveSelection((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Left
                                            && ((root.gridMode() && !root.shellQuery)
                                                || root.symbolGridMode())) {
                                        root.moveSelection(-1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Right
                                            && ((root.gridMode() && !root.shellQuery)
                                                || root.symbolGridMode())) {
                                        root.moveSelection(1)
                                        event.accepted = true
                                    } else if (root.resultMode === "files"
                                            && (event.modifiers & Qt.ControlModifier)
                                            && root.selectedFileAvailable
                                            && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                        LauncherService.openContainingFolder(root.results[root.selectedIndex])
                                        event.accepted = true
                                    } else if (root.resultMode === "files"
                                            && (event.modifiers & Qt.ControlModifier)
                                            && root.selectedFileAvailable
                                            && event.key === Qt.Key_C) {
                                        LauncherService.copyFilePath(root.results[root.selectedIndex])
                                        root.statusMessage = LauncherService.actionMessage
                                        statusTimer.restart()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.resultMode === "local-ai") {
                                            if (AssistantService.ask(text))
                                                searchField.text = ""
                                        } else if (root.resultMode === "games")
                                            gamesPage.launchSelected()
                                        else
                                            root.activate(root.selectedIndex)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.backOrClose()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Backspace && text.length === 0 && root.resultMode !== "root") {
                                        root.resetToRoot()
                                        event.accepted = true
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: root.resultMode === "overview"
                                    ? I18n.tr("launcher.overviewPrompt")
                                    : (root.resultMode === "wallpaper"
                                        ? I18n.tr("launcher.wallpaperPrompt")
                                        : I18n.tr("launcher.artworkPrompt"))
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                visible: root.resultMode === "overview"
                                    || root.resultMode === "wallpaper"
                                    || (root.resultMode === "games" && gamesPage.artworkPickerOpen)
                            }

                            MaterialIcon {
                                text: root.resultMode === "local-ai" ? "send" : "close"
                                size: 17
                                color: root.resultMode === "local-ai"
                                    ? (searchField.text.trim().length > 0
                                        ? Theme.accent : Theme.textMuted)
                                    : Theme.textMuted
                                TapHandler {
                                    enabled: root.resultMode !== "local-ai"
                                        || searchField.text.trim().length > 0
                                    onTapped: {
                                        if (root.resultMode === "local-ai") {
                                            if (AssistantService.ask(searchField.text))
                                                searchField.text = ""
                                        } else {
                                            ShellState.closePanels()
                                        }
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }
    }
}
