import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"

PanelWindow {
    id: root

    property string mode: "screen"
    property string selectedType: ""
    property string selectedPayload: ""
    property string selectedLabel: ""
    property var windowEntries: []
    property bool rememberChoice: false
    property bool closing: false
    property string pendingAction: ""
    property bool snapshotReady: false

    readonly property var waylandToplevels:
        ToplevelManager.toplevels.values || []
    readonly property int cardWidth: Math.min(920, width - 48)
    readonly property int cardHeight: Math.min(680, height - 48)
    readonly property bool selectionReady:
        (selectedType === "screen" || selectedType === "window")
            && selectedPayload.length > 0
    readonly property string primaryLabel: mode === "region"
        ? "Select region"
        : (selectedType === "window" ? "Share window" : "Share screen")
    readonly property string primaryIcon: mode === "region"
        ? "crop_free" : "present_to_all"

    function focusedScreen() {
        const requested = Hyprland.focusedMonitor
            ? String(Hyprland.focusedMonitor.name || "") : ""
        const screens = Quickshell.screens || []
        for (let index = 0; index < screens.length; ++index) {
            if (screens[index] && screens[index].name === requested)
                return screens[index]
        }
        return screens.length > 0 ? screens[0] : null
    }

    function setMode(value) {
        if (["screen", "window", "region"].indexOf(value) < 0)
            return
        mode = value
        selectedType = ""
        selectedPayload = ""
        selectedLabel = ""
        contentEntrance.restart()
        pickerFocus.forceActiveFocus()
    }

    function selectItem(type, payload, label) {
        selectedType = String(type || "")
        selectedPayload = String(payload || "")
        selectedLabel = String(label || "")
    }

    function parseSnapshot(contents) {
        const result = []
        const lines = String(contents || "").split("\n")
        for (let index = 0; index < lines.length; ++index) {
            const fields = lines[index].split("\t")
            if (fields[0] === "meta") {
                rememberChoice = fields[1] === "1"
            } else if (fields[0] === "window" && fields.length >= 4) {
                result.push({
                    handle: fields[1],
                    appId: fields[2],
                    title: fields.slice(3).join(" ")
                })
            }
        }
        windowEntries = result
        snapshotReady = true
    }

    function previewSource(entry) {
        if (!entry)
            return null
        const title = String(entry.title || "")
        const appId = String(entry.appId || "")
        let appMatch = null

        for (let index = 0; index < waylandToplevels.length; ++index) {
            const candidate = waylandToplevels[index]
            if (!candidate)
                continue
            const candidateTitle = String(candidate.title || "")
            const candidateAppId = String(candidate.appId || "")
            if (candidateTitle === title
                    && (candidateAppId === appId || appId.length === 0))
                return candidate
            if (!appMatch && appId.length > 0
                    && candidateAppId.toLowerCase() === appId.toLowerCase())
                appMatch = candidate
        }
        return appMatch
    }

    function appIcon(entry) {
        const appId = String(entry && entry.appId ? entry.appId : "")
        return appId.length > 0 ? "image://icon/" + appId : ""
    }

    function requestCommit() {
        if (mode === "region") {
            pendingAction = "region"
        } else {
            if (!selectionReady)
                return
            pendingAction = "select"
        }
        closing = true
        actionDelay.restart()
    }

    function cancel() {
        if (closing)
            return
        pendingAction = "cancel"
        closing = true
        actionDelay.restart()
    }

    screen: focusedScreen()
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: !closing
    visible: true

    // Keep the layer surface alive until the helper has atomically written its
    // result. Hiding the last window here makes QApplication exit before the
    // asynchronous Process gets a chance to run, which XDPH reports as
    // "selection -1". An empty input/visible region lets slurp receive the
    // pointer while the region picker is active without destroying this window.
    mask: Region {
        x: 0
        y: 0
        width: root.closing ? 0 : root.width
        height: root.closing ? 0 : root.height
    }
    HyprlandWindow.visibleMask: Region {
        x: 0
        y: 0
        width: root.closing ? 0 : root.width
        height: root.closing ? 0 : root.height
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-share-picker"
    WlrLayershell.keyboardFocus: root.closing
        ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.shadow, 0.58)
        opacity: root.closing ? 0 : 1

        TapHandler {
            onTapped: (eventPoint, button) => {
                // TapHandler can receive a passive grab alongside handlers
                // inside the dialog. Only dismiss when the release really was
                // outside the card.
                const point = eventPoint.position
                if (point.x < pickerCard.x
                        || point.x > pickerCard.x + pickerCard.width
                        || point.y < pickerCard.y
                        || point.y > pickerCard.y + pickerCard.height)
                    root.cancel()
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.exitCurve
            }
        }
    }

    FocusScope {
        id: pickerFocus
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.cancel()
        Keys.onReturnPressed: root.requestCommit()
        Keys.onEnterPressed: root.requestCommit()

        Rectangle {
            id: pickerCard
            anchors.centerIn: parent
            width: root.cardWidth
            height: root.cardHeight
            radius: Theme.radiusExtraLarge
            color: Theme.panel
            border.width: 1
            border.color: Theme.outlineSoft
            clip: true
            opacity: root.closing ? 0 : 1
            scale: root.closing ? 0.975 : 1

            TapHandler {
                // Keep taps inside the dialog from reaching the dismiss layer.
                onTapped: {}
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.closing ? Motion.fast : Motion.enter
                    easing.type: root.closing
                        ? Motion.exitCurve : Motion.enterCurve
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.closing ? Motion.fast : Motion.enter
                    easing.type: root.closing
                        ? Motion.exitCurve : Motion.expressiveCurve
                }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.panelPadding
                }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Theme.radiusMedium
                        color: Theme.accentContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "screen_share"
                            size: 25
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: "Choose what to share"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 23
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Discord or OBS will only receive the source you select"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 34
                        radius: Theme.pillRadius
                        color: Theme.groupSurfaceRaised

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                text: "shield_lock"
                                size: 16
                                color: Theme.accent
                            }
                            Text {
                                text: "Private preview"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    IconButton {
                        size: 40
                        icon: "close"
                        accessibleName: "Cancel screen sharing"
                        onClicked: root.cancel()
                    }
                }

                SlidingChoice {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    options: ["screen", "window", "region"]
                    optionLabels: ["Entire screen", "Application window", "Region"]
                    value: root.mode
                    maxColumns: 3
                    onSelected: value => root.setMode(value)
                }

                Item {
                    id: contentFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: 1

                    SequentialAnimation {
                        id: contentEntrance
                        NumberAnimation {
                            target: contentFrame
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Motion.pageEnter
                            easing.type: Motion.enterCurve
                        }
                    }

                    GridView {
                        id: screenGrid
                        anchors.fill: parent
                        visible: root.mode === "screen"
                        opacity: visible ? 1 : 0
                        model: Quickshell.screens
                        cellWidth: width / Math.max(1,
                            Math.min(2, count))
                        cellHeight: Math.min(248, height)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        topMargin: Math.max(0,
                            (height - Math.ceil(count / 2) * cellHeight) / 2)

                        delegate: Item {
                            id: screenCell
                            required property var modelData
                            required property int index
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight
                            readonly property bool selected:
                                root.selectedType === "screen"
                                    && root.selectedPayload === modelData.name

                            Rectangle {
                                anchors {
                                    fill: parent
                                    margins: 7
                                }
                                radius: Theme.radiusLarge
                                color: screenCell.selected
                                    ? Theme.surfaceHigh
                                    : (screenHover.hovered
                                        ? Theme.surfaceHover : Theme.surface)
                                border.width: screenCell.selected ? 2 : 1
                                border.color: screenCell.selected
                                    ? Theme.accent : Theme.outlineSoft
                                clip: true
                                scale: screenTap.pressed ? 0.975 : 1

                                Rectangle {
                                    id: screenPreviewFrame
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        margins: 7
                                    }
                                    height: parent.height - 60
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceLow
                                    clip: true

                                    ScreencopyView {
                                        id: screenPreview
                                        anchors.centerIn: parent
                                        readonly property real sourceRatio:
                                            sourceSize.height > 0
                                                ? sourceSize.width
                                                    / sourceSize.height : 0
                                        width: sourceRatio > 0
                                            ? Math.min(parent.width,
                                                parent.height * sourceRatio)
                                            : parent.width
                                        height: sourceRatio > 0
                                            ? Math.min(parent.height,
                                                parent.width / sourceRatio)
                                            : parent.height
                                        captureSource: root.mode === "screen"
                                            ? screenCell.modelData : null
                                        live: false
                                        paintCursor: false
                                        constraintSize: Qt.size(width, height)
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        visible: !screenPreview.hasContent
                                        spacing: 6
                                        MaterialIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "monitor"
                                            size: 32
                                            color: Theme.textMuted
                                        }
                                        Text {
                                            text: "Preparing preview"
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: 14
                                        rightMargin: 14
                                        bottomMargin: 9
                                    }
                                    spacing: 8
                                    MaterialIcon {
                                        text: screenCell.selected
                                            ? "check_circle" : "monitor"
                                        size: 19
                                        color: screenCell.selected
                                            ? Theme.accent : Theme.textMuted
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: screenCell.modelData.name
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: screenCell.modelData.width + " × "
                                                + screenCell.modelData.height
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                HoverHandler { id: screenHover }
                                TapHandler {
                                    id: screenTap
                                    onTapped: root.selectItem("screen",
                                        screenCell.modelData.name,
                                        screenCell.modelData.name)
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

                    GridView {
                        id: windowGrid
                        anchors.fill: parent
                        visible: root.mode === "window"
                        opacity: visible ? 1 : 0
                        model: root.windowEntries
                        cellWidth: width / (width >= 760 ? 3 : 2)
                        cellHeight: 182
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: cellHeight

                        delegate: Item {
                            id: windowCell
                            required property var modelData
                            required property int index
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight
                            readonly property var capture:
                                root.previewSource(modelData)
                            readonly property bool selected:
                                root.selectedType === "window"
                                    && root.selectedPayload
                                        === String(modelData.handle)

                            Rectangle {
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                radius: Theme.radiusLarge
                                color: windowCell.selected
                                    ? Theme.surfaceHigh
                                    : (windowHover.hovered
                                        ? Theme.surfaceHover : Theme.surface)
                                border.width: windowCell.selected ? 2 : 1
                                border.color: windowCell.selected
                                    ? Theme.accent : Theme.outlineSoft
                                clip: true
                                scale: windowTap.pressed ? 0.97 : 1

                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        margins: 6
                                    }
                                    height: parent.height - 52
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceLow
                                    clip: true

                                    ScreencopyView {
                                        id: windowPreview
                                        anchors.centerIn: parent
                                        readonly property real sourceRatio:
                                            sourceSize.height > 0
                                                ? sourceSize.width
                                                    / sourceSize.height : 0
                                        width: sourceRatio > 0
                                            ? Math.min(parent.width,
                                                parent.height * sourceRatio)
                                            : parent.width
                                        height: sourceRatio > 0
                                            ? Math.min(parent.height,
                                                parent.width / sourceRatio)
                                            : parent.height
                                        captureSource: root.mode === "window"
                                            ? windowCell.capture : null
                                        live: false
                                        paintCursor: false
                                        constraintSize: Qt.size(width, height)
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        visible: !windowPreview.hasContent
                                        Image {
                                            id: windowAppIcon
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34
                                            source: root.appIcon(windowCell.modelData)
                                            sourceSize: Qt.size(40, 40)
                                            visible: source.toString().length > 0
                                                && status === Image.Ready
                                        }
                                        MaterialIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "web_asset"
                                            size: 29
                                            color: Theme.textMuted
                                            visible: !windowAppIcon.visible
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
                                        bottomMargin: 8
                                    }
                                    spacing: 7
                                    MaterialIcon {
                                        text: windowCell.selected
                                            ? "check_circle" : "web_asset"
                                        size: 17
                                        color: windowCell.selected
                                            ? Theme.accent : Theme.textMuted
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: windowCell.modelData.title
                                                || "Untitled window"
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: windowCell.modelData.appId
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                HoverHandler { id: windowHover }
                                TapHandler {
                                    id: windowTap
                                    onTapped: root.selectItem("window",
                                        String(windowCell.modelData.handle),
                                        windowCell.modelData.title)
                                }

                                Behavior on color {
                                    ColorAnimation { duration: Motion.fast }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: Motion.instant }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.snapshotReady
                                && root.windowEntries.length === 0
                            text: "No shareable windows are open"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: !root.snapshotReady
                            spacing: 8
                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "progress_activity"
                                size: 28
                                color: Theme.accent
                            }
                            Text {
                                text: "Loading windows"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: root.mode === "region"
                        opacity: visible ? 1 : 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(590, parent.width - 40)
                            height: Math.min(292, parent.height - 20)
                            radius: Theme.radiusExtraLarge
                            color: regionHover.hovered
                                ? Theme.surfaceHover : Theme.surface
                            border.width: 2
                            border.color: Theme.accent
                            scale: regionTap.pressed ? 0.975 : 1

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 26
                                }
                                spacing: 10

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 70
                                    Layout.preferredHeight: 70
                                    radius: Theme.radiusLarge
                                    color: Theme.accentContainer

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "crop_free"
                                        size: 36
                                        color: Theme.accent
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Share a custom region"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Draw around the exact part of the desktop you want to share. Press Escape to return here."
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 7
                                    MaterialIcon {
                                        text: "gesture"
                                        size: 17
                                        color: Theme.accent
                                    }
                                    Text {
                                        text: "Click, drag, and release"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            HoverHandler { id: regionHover }
                            TapHandler {
                                id: regionTap
                                onTapped: root.requestCommit()
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.divider
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ToggleSwitch {
                            checked: root.rememberChoice
                            onToggled: checked =>
                                root.rememberChoice = checked
                        }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "Remember this choice"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "The requesting app may reuse this source"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 42
                        radius: Theme.radiusMedium
                        color: cancelHover.hovered
                            ? Theme.surfaceHover : Theme.surface
                        scale: cancelTap.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        HoverHandler { id: cancelHover }
                        TapHandler {
                            id: cancelTap
                            onTapped: root.cancel()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 164
                        Layout.preferredHeight: 42
                        radius: Theme.radiusMedium
                        color: {
                            if (root.mode !== "region"
                                    && !root.selectionReady)
                                return Theme.surfaceLow
                            return primaryHover.hovered
                                ? Theme.accentStrong : Theme.accent
                        }
                        opacity: root.mode === "region"
                            || root.selectionReady ? 1 : 0.45
                        scale: primaryTap.pressed ? 0.96 : 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 7
                            MaterialIcon {
                                text: root.primaryIcon
                                size: 18
                                color: Theme.accentInk
                            }
                            Text {
                                text: root.primaryLabel
                                color: Theme.accentInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        HoverHandler { id: primaryHover }
                        TapHandler {
                            id: primaryTap
                            enabled: root.mode === "region"
                                || root.selectionReady
                            onTapped: root.requestCommit()
                        }

                        Behavior on color {
                            ColorAnimation { duration: Motion.fast }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: Motion.fast }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: Motion.instant }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: snapshotProcess
        command: ["sh", Paths.shellRoot
            + "/scripts/share-picker.sh", "snapshot"]
        running: true
        stdout: StdioCollector { id: snapshotOutput }
        onExited: (exitCode, exitStatus) => {
            root.parseSnapshot(snapshotOutput.text)
        }
    }

    Process {
        id: selectionProcess
        command: ["sh", Paths.shellRoot
            + "/scripts/share-picker.sh", "select",
            root.selectedType, root.selectedPayload,
            root.rememberChoice ? "1" : "0"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Qt.quit()
            } else {
                console.warn("Share picker selection helper failed:", exitCode)
                root.closing = false
                root.pendingAction = ""
                pickerFocus.forceActiveFocus()
            }
        }
    }

    Process {
        id: regionProcess
        command: ["sh", Paths.shellRoot
            + "/scripts/share-picker.sh", "region",
            root.rememberChoice ? "1" : "0"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Qt.quit()
            } else {
                root.closing = false
                root.pendingAction = ""
                pickerFocus.forceActiveFocus()
            }
        }
    }

    Timer {
        id: actionDelay
        interval: Motion.fast
        repeat: false
        onTriggered: {
            if (root.pendingAction === "select") {
                selectionProcess.running = true
            } else if (root.pendingAction === "region") {
                regionProcess.running = true
            } else {
                Qt.quit()
            }
        }
    }

    Component.onCompleted: {
        pickerFocus.forceActiveFocus()
    }
}
