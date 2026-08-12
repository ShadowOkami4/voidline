import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"

FocusScope {
    id: root

    property var shellScreen
    property bool active: false
    property var selectedWorkspace: null
    property int selectedWindowIndex: 0

    signal back()

    readonly property int availableWidth: shellScreen ? shellScreen.width : 1920
    readonly property int availableHeight: shellScreen ? shellScreen.height : 1080
    readonly property string screenName: shellScreen ? shellScreen.name : ""
    readonly property var workspaceList: {
        const values = Hyprland.workspaces.values || []
        const items = []
        for (let index = 0; index < values.length; ++index) {
            const workspace = values[index]
            if (!workspace)
                continue
            const scratchpad = isScratchpad(workspace)
            if (!scratchpad && workspace.id <= 0)
                continue
            // Desktops belong to this panel's monitor. Scratchpads are global
            // overlays, so keep them reachable even while they are hidden or
            // were last shown on another monitor.
            if (!scratchpad && screenName.length > 0 && workspace.monitor
                    && workspace.monitor.name !== screenName)
                continue
            items.push(workspace)
        }
        items.sort((left, right) => {
            const leftScratchpad = isScratchpad(left)
            const rightScratchpad = isScratchpad(right)
            if (leftScratchpad !== rightScratchpad)
                return leftScratchpad ? 1 : -1
            if (!leftScratchpad)
                return left.id - right.id
            const leftName = scratchpadName(left)
            const rightName = scratchpadName(right)
            const leftNumber = Number(leftName)
            const rightNumber = Number(rightName)
            if (!Number.isNaN(leftNumber) && !Number.isNaN(rightNumber))
                return leftNumber - rightNumber
            return leftName.localeCompare(rightName)
        })
        return items
    }
    readonly property var desktopList: workspaceList.filter(workspace => !isScratchpad(workspace))
    readonly property var scratchpadList: workspaceList.filter(workspace => isScratchpad(workspace))
    readonly property var windowList: selectedWorkspace && selectedWorkspace.toplevels
        ? selectedWorkspace.toplevels.values : []
    readonly property int stableContentWidth: Math.max(340,
        Math.min(1140, availableWidth - 160))
    readonly property int columnCapacity: stableContentWidth >= 1000 ? 3
        : stableContentWidth >= 680 ? 2 : 1
    readonly property int gridColumns: Math.max(1,
        Math.min(columnCapacity, Math.max(1, windowList.length)))
    readonly property int maxCardWidth: gridColumns === 3 ? 348
        : gridColumns === 2 ? 430 : 510
    readonly property int maxPreviewHeight: gridColumns === 3 ? 204
        : gridColumns === 2 ? 246 : 292
    readonly property int cardFooterHeight: 64
    readonly property int cardCellHeight: maxPreviewHeight + cardFooterHeight + 24

    // Launcher adds 14 px on every edge and a 42 px command footer. Keeping
    // those dimensions here lets its attached surface morph to the settled
    // overview size before this page is revealed.
    readonly property int requestedBodyWidth: stableContentWidth + 28
    readonly property int requestedBodyHeight: Math.max(420,
        Math.min(820, availableHeight - Theme.barHeight - 34))

    focus: active

    function isScratchpad(workspace) {
        if (!workspace)
            return false
        const name = String(workspace.name || "")
        return workspace.id < 0 || name.indexOf("special:") === 0
    }

    function scratchpadName(workspace) {
        if (!workspace)
            return ""
        const name = String(workspace.name || "")
        return name.indexOf("special:") === 0 ? name.slice(8) : name
    }

    function workspaceLabel(workspace) {
        if (!workspace)
            return "Workspace"
        if (isScratchpad(workspace)) {
            const name = scratchpadName(workspace)
            return name.length > 0 ? "Scratchpad " + name : "Scratchpad"
        }
        const name = String(workspace.name || "")
        return name.indexOf("name:") === 0 ? name.slice(5) : "Desktop " + workspace.id
    }

    function quotedLuaString(value) {
        return String(value || "").replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")
    }

    function revealScratchpad(workspace) {
        if (!isScratchpad(workspace) || workspace.active)
            return
        Hyprland.dispatch('hl.dsp.workspace.toggle_special("'
            + quotedLuaString(scratchpadName(workspace)) + '")')
    }

    function activateWorkspace(workspace) {
        if (!workspace)
            return
        if (isScratchpad(workspace))
            revealScratchpad(workspace)
        else
            workspace.activate()
    }

    function ensureWorkspace() {
        if (Hyprland.focusedWorkspace && workspaceList.indexOf(Hyprland.focusedWorkspace) >= 0) {
            selectedWorkspace = Hyprland.focusedWorkspace
            return
        }
        if (selectedWorkspace && workspaceList.indexOf(selectedWorkspace) >= 0)
            return
        selectedWorkspace = workspaceList.length > 0 ? workspaceList[0] : null
    }

    function selectWorkspace(workspace) {
        if (!workspace)
            return
        selectedWorkspace = workspace
        selectedWindowIndex = workspace.toplevels.values.length > 0 ? 0 : -1
        forceActiveFocus()
    }

    function selectWorkspaceOffset(offset) {
        if (workspaceList.length === 0)
            return
        let index = workspaceList.indexOf(selectedWorkspace)
        if (index < 0)
            index = 0
        selectWorkspace(workspaceList[(index + offset + workspaceList.length) % workspaceList.length])
    }

    function moveWindowSelection(offset) {
        if (windowList.length === 0)
            return
        selectedWindowIndex = (selectedWindowIndex + offset + windowList.length) % windowList.length
        windowGrid.positionViewAtIndex(selectedWindowIndex, GridView.Contain)
    }

    function activateWindow(toplevel) {
        if (!toplevel)
            return
        if (toplevel.workspace)
            revealScratchpad(toplevel.workspace)
        if (toplevel.wayland)
            toplevel.wayland.activate()
        else if (toplevel.workspace)
            activateWorkspace(toplevel.workspace)
        ShellState.closePanels()
    }

    function activateSelectedWindow() {
        if (windowList.length > 0 && selectedWindowIndex >= 0 && selectedWindowIndex < windowList.length) {
            activateWindow(windowList[selectedWindowIndex])
        } else if (selectedWorkspace) {
            activateWorkspace(selectedWorkspace)
            ShellState.closePanels()
        }
    }

    function createWorkspace() {
        Hyprland.dispatch('hl.dsp.focus({ workspace = "emptynm" })')
        workspaceRefresh.restart()
        forceActiveFocus()
    }

    function appIcon(toplevel) {
        if (!toplevel)
            return ""
        const data = toplevel.lastIpcObject || ({})
        const appClass = data.class || data.initialClass || ""
        if (appClass.length === 0)
            return ""
        const entry = DesktopEntries.heuristicLookup(appClass)
        if (!entry || !entry.icon)
            return ""
        return entry.icon.startsWith("/") ? "file://" + entry.icon
            : (Quickshell.hasThemeIcon(entry.icon)
                ? Quickshell.iconPath(entry.icon) : "")
    }

    function windowAspect(toplevel) {
        if (!toplevel)
            return 1.6
        const data = toplevel.lastIpcObject || ({})
        const size = data.size || []
        return size.length >= 2 && size[1] > 0 ? size[0] / size[1] : 1.6
    }

    onActiveChanged: {
        if (!active)
            return
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        ensureWorkspace()
        selectedWindowIndex = windowList.length > 0 ? 0 : -1
        focusTimer.restart()
    }

    onWorkspaceListChanged: {
        if (active)
            ensureWorkspace()
    }

    onWindowListChanged: {
        selectedWindowIndex = windowList.length > 0
            ? Math.min(Math.max(0, selectedWindowIndex), windowList.length - 1) : -1
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: root.forceActiveFocus()
    }

    Timer {
        id: workspaceRefresh
        interval: 120
        onTriggered: {
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            root.ensureWorkspace()
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            root.back()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            root.moveWindowSelection((event.modifiers & Qt.ShiftModifier) !== 0 ? -1 : 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left && (event.modifiers & Qt.ControlModifier)) {
            root.selectWorkspaceOffset(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right && (event.modifiers & Qt.ControlModifier)) {
            root.selectWorkspaceOffset(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.moveWindowSelection(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.moveWindowSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.moveWindowSelection(-root.gridColumns)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            root.moveWindowSelection(root.gridColumns)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateSelectedWindow()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: Theme.radiusLarge
            color: Theme.surfaceHigh

            IconButton {
                id: overviewBack
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 44
                icon: "arrow_back"
                accessibleName: "Back to commands"
                onClicked: root.back()
            }
            Rectangle {
                id: overviewHeaderIcon
                anchors {
                    left: overviewBack.right
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 48
                height: 48
                radius: Theme.radiusMedium
                color: Theme.accentContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "view_cozy"
                    size: 23
                    color: Theme.accent
                }
            }
            Text {
                id: overviewHints
                anchors {
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                text: "Ctrl + ← → workspaces   Tab windows   Enter open"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                visible: root.width > 820
            }
            ColumnLayout {
                anchors {
                    left: overviewHeaderIcon.right
                    leftMargin: 10
                    right: overviewHints.visible ? overviewHints.left : parent.right
                    rightMargin: overviewHints.visible ? 14 : 12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: "Overview"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.windowList.length + (root.windowList.length === 1 ? " live window" : " live windows")
                        + " · " + root.desktopList.length + (root.desktopList.length === 1 ? " desktop" : " desktops")
                        + (root.scratchpadList.length > 0
                            ? " · " + root.scratchpadList.length
                                + (root.scratchpadList.length === 1 ? " scratchpad" : " scratchpads")
                            : "")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        ListView {
            id: workspaceStrip
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: root.workspaceList
            boundsBehavior: Flickable.StopAtBounds

            footer: Rectangle {
                width: newDesktopContent.implicitWidth + 24
                height: 42
                radius: Theme.radiusMedium
                color: newDesktopHover.hovered ? Theme.accentContainer : Theme.surface
                border.width: 1
                border.color: newDesktopHover.hovered ? Theme.accent : Theme.outlineSoft

                RowLayout {
                    id: newDesktopContent
                    anchors.centerIn: parent
                    spacing: 7
                    MaterialIcon {
                        text: "add"
                        size: 17
                        color: newDesktopHover.hovered ? Theme.accent : Theme.textMuted
                    }
                    Text {
                        text: "New desktop"
                        color: newDesktopHover.hovered ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                HoverHandler { id: newDesktopHover }
                TapHandler { onTapped: root.createWorkspace() }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            delegate: Rectangle {
                id: workspacePill
                required property var modelData
                required property int index
                readonly property bool selected: root.selectedWorkspace === modelData
                readonly property bool scratchpad: root.isScratchpad(modelData)
                width: workspaceContent.implicitWidth + 24
                height: 42
                radius: Theme.radiusMedium
                color: selected ? Theme.accentContainer
                    : (workspaceHover.hovered ? Theme.surfaceHover : Theme.surface)
                border.width: selected ? 0 : 1
                border.color: Theme.outlineSoft
                scale: workspaceTap.pressed ? 0.97 : 1

                RowLayout {
                    id: workspaceContent
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialIcon {
                        text: workspacePill.scratchpad ? "picture_in_picture_alt"
                            : (modelData.focused ? "desktop_windows" : "crop_square")
                        size: 17
                        color: workspacePill.selected
                            ? Theme.accent : Theme.textMuted
                    }
                    Text {
                        text: root.workspaceLabel(modelData)
                        color: workspacePill.selected ? Theme.text : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: workspacePill.selected ? Font.Bold : Font.Medium
                    }
                    Rectangle {
                        width: 22
                        height: 22
                        radius: Theme.radiusSmall
                        color: workspacePill.selected ? Theme.accent : Theme.surfaceLow
                        Text {
                            anchors.centerIn: parent
                            text: modelData.toplevels.values.length
                            color: workspacePill.selected ? Theme.accentInk : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                HoverHandler { id: workspaceHover }
                TapHandler {
                    id: workspaceTap
                    onTapped: root.selectWorkspace(modelData)
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.instant
                        easing.type: Motion.standardCurve
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: windowGrid
                anchors.fill: parent
                clip: true
                model: root.windowList
                cellWidth: width / root.gridColumns
                cellHeight: root.cardCellHeight
                currentIndex: root.selectedWindowIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Motion.launcherContent
                cacheBuffer: cellHeight
                topMargin: Math.max(0, (height
                    - Math.ceil(root.windowList.length / root.gridColumns) * cellHeight) / 2)
                bottomMargin: topMargin

                delegate: Item {
                    id: windowCard
                    required property var modelData
                    required property int index
                    readonly property var ipcData: modelData.lastIpcObject || ({})
                    readonly property int rowIndex: Math.floor(index / root.gridColumns)
                    readonly property int itemsInRow: Math.min(root.gridColumns,
                        root.windowList.length - rowIndex * root.gridColumns)
                    readonly property real rowOffset: Math.max(0,
                        (root.gridColumns - itemsInRow) * width / 2)
                    readonly property bool inViewport: y + height >= windowGrid.contentY - 8
                        && y <= windowGrid.contentY + windowGrid.height + 8
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    opacity: root.active ? 1 : 0

                    transform: Translate { x: windowCard.rowOffset }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 16, root.maxCardWidth)
                        height: root.maxPreviewHeight + root.cardFooterHeight
                        radius: Theme.radiusLarge
                        color: windowCard.index === root.selectedWindowIndex
                            ? Theme.surfaceHigh : Theme.surface
                        border.width: windowCard.index === root.selectedWindowIndex ? 2 : 1
                        border.color: windowCard.index === root.selectedWindowIndex
                            ? Theme.accent : Theme.outlineSoft
                        clip: true
                        scale: cardTap.pressed ? 0.975
                            : (windowCard.index === root.selectedWindowIndex ? 1 : 0.985)

                        Rectangle {
                            id: previewFrame
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                margins: 6
                            }
                            height: root.maxPreviewHeight - 6
                            radius: Theme.radiusMedium
                            color: Theme.surfaceLow
                            clip: true

                            ScreencopyView {
                                id: livePreview
                                anchors.centerIn: parent
                                readonly property real sourceRatio: sourceSize.height > 0
                                    ? sourceSize.width / sourceSize.height : 0
                                width: sourceRatio > 0
                                    ? Math.min(parent.width, parent.height * sourceRatio) : parent.width
                                height: sourceRatio > 0
                                    ? Math.min(parent.height, parent.width / sourceRatio) : parent.height
                                captureSource: root.active && windowCard.inViewport
                                    && modelData && modelData.wayland ? modelData.wayland : null
                                // A newly assigned source captures one still frame. Only the
                                // selected card keeps streaming, avoiding N simultaneous
                                // toplevel-export loops on window-heavy workspaces.
                                live: root.active && windowCard.inViewport
                                    && windowCard.index === root.selectedWindowIndex
                                paintCursor: false
                                constraintSize: Qt.size(width, height)
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: !livePreview.hasContent
                                ApplicationIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    source: root.appIcon(modelData)
                                    sourcePixelSize: 48
                                }
                                Text {
                                    text: "Preparing live preview"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                anchors { top: parent.top; right: parent.right; margins: 9 }
                                width: 32
                                height: 32
                                radius: Theme.radiusSmall
                                color: closeHover.hovered ? Theme.danger : Qt.rgba(0, 0, 0, 0.58)
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "close"
                                    size: 17
                                    color: closeHover.hovered ? Theme.accentInk : "white"
                                }
                                HoverHandler { id: closeHover }
                                TapHandler {
                                    onTapped: {
                                        if (modelData.wayland)
                                            modelData.wayland.close()
                                        root.forceActiveFocus()
                                    }
                                }
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    bottom: parent.bottom
                                    margins: 10
                                }
                                width: selectedLabel.implicitWidth + 18
                                height: 28
                                radius: Theme.radiusSmall
                                color: Qt.rgba(0, 0, 0, 0.66)
                                visible: windowCard.index === root.selectedWindowIndex

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    MaterialIcon {
                                        text: "keyboard_return"
                                        size: 14
                                        color: Theme.accent
                                    }
                                    Text {
                                        id: selectedLabel
                                        text: "Open"
                                        color: "white"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Motion.fast
                                        easing.type: Motion.enterCurve
                                    }
                                }
                            }
                        }

                        RowLayout {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: 12
                                rightMargin: 12
                            }
                            height: root.cardFooterHeight
                            spacing: 10
                            ApplicationIcon {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                source: root.appIcon(modelData)
                                sourcePixelSize: 40
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || "Window"
                                    color: windowCard.index === root.selectedWindowIndex
                                        ? Theme.accent : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (windowCard.ipcData.class || "Application")
                                        + " · " + root.workspaceLabel(root.selectedWorkspace)
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                            MaterialIcon {
                                text: "arrow_outward"
                                size: 18
                                color: windowCard.index === root.selectedWindowIndex
                                    ? Theme.accent : Theme.textMuted
                            }
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: Theme.radiusLarge
                                rightMargin: Theme.radiusLarge
                            }
                            height: windowCard.index === root.selectedWindowIndex ? 3 : 0
                            radius: 2
                            color: Theme.accent

                            Behavior on height {
                                NumberAnimation {
                                    duration: Motion.fast
                                    easing.type: Motion.enterCurve
                                }
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    root.selectedWindowIndex = windowCard.index
                            }
                        }
                        TapHandler {
                            id: cardTap
                            onTapped: root.activateWindow(modelData)
                        }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Motion.selectionPulse
                                easing.type: Motion.enterCurve
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.pageEnter
                            easing.type: Motion.pageCurve
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: root.windowList.length === 0
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 68
                    radius: Theme.radiusLarge
                    color: Theme.accentContainer
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "desktop_access_disabled"
                        size: 31
                        color: Theme.accent
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No windows on this workspace"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Choose another desktop above or create a new one"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
