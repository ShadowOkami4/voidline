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

    readonly property int triggerWidth: Math.max(7, Metrics.spaceS)
    readonly property int triggerHeight: Metrics.edgeTriggerHeight
    readonly property int drawerBodyHeight: Metrics.powerDrawerHeight
    readonly property int joinSize: Metrics.concaveRadius
    readonly property bool isOpen: ShellState.isPowerMenuScreen(root.screen)
    readonly property bool openFromLeft: Appearance.barPosition === "right"
    readonly property int revealDirection: openFromLeft ? -1 : 1
    property string pendingAction: ""
    property string confirmedAction: ""
    property real revealProgress: 0

    implicitWidth: Metrics.powerDrawerWidth + joinSize
    anchors {
        top: true
        bottom: true
        left: root.openFromLeft
        right: !root.openFromLeft
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    visible: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-power-drawer"

    mask: Region {
        Region {
            x: root.openFromLeft ? 0 : root.width - root.triggerWidth
            y: Math.round((root.height - root.triggerHeight) / 2)
            width: root.triggerWidth
            height: root.triggerHeight
        }
        Region {
            x: Math.round(drawer.x)
            y: Math.round(drawer.y)
            width: drawer.width
            height: drawer.height
        }
    }

    HyprlandWindow.visibleMask: Region {
        Region {
            x: Math.round(drawer.x)
            y: Math.round(drawer.y)
            width: drawer.width
            height: drawer.height
        }
        Region {
            x: root.openFromLeft ? 0 : root.width - 4
            y: Math.round((root.height - 72) / 2)
            width: 4
            height: 72
        }
    }

    function holdOpen() {
        closeDelay.stop()
        ShellState.openPowerMenu(root.screen)
    }

    function scheduleClose() {
        if (!triggerHover.hovered && !drawerHover.hovered)
            closeDelay.restart()
    }

    function revealValue(offset) {
        return Math.max(0, Math.min(1, (revealProgress - offset) / (1 - offset)))
    }

    function actionTitle(action) {
        if (action === "logout") return I18n.tr("power.logOut")
        if (action === "reboot") return I18n.tr("power.restart")
        if (action === "poweroff") return I18n.tr("power.powerOff")
        return ""
    }

    function actionIcon(action) {
        if (action === "logout") return "logout"
        if (action === "reboot") return "restart_alt"
        if (action === "poweroff") return "power_settings_new"
        return "power_settings_new"
    }

    function actionDescription(action) {
        if (action === "logout") return I18n.tr("power.confirmLogout")
        if (action === "reboot") return I18n.tr("power.confirmRestart")
        if (action === "poweroff") return I18n.tr("power.confirmPowerOff")
        return I18n.tr("power.confirmContinue")
    }

    function requestAction(action) {
        if (action === "lock") {
            ShellState.closePowerMenu(root.screen)
            LockService.lock()
            return
        }
        if (action === "suspend") {
            confirmedAction = action
            ShellState.closePowerMenu(root.screen)
            actionDelay.restart()
            return
        }
        pendingAction = action
    }

    function confirmAction() {
        if (pendingAction.length === 0)
            return
        confirmedAction = pendingAction
        pendingAction = ""
        ShellState.closePowerMenu(root.screen)
        actionDelay.restart()
    }

    onIsOpenChanged: {
        if (isOpen) {
            resetPending.stop()
            revealProgress = 1
        } else {
            closeDelay.stop()
            revealProgress = 0
            resetPending.restart()
        }
    }

    Behavior on revealProgress {
        NumberAnimation {
            duration: root.isOpen ? Motion.drawerRevealEnter : Motion.drawerRevealExit
            easing.type: root.isOpen ? Motion.enterCurve : Motion.exitCurve
        }
    }

    Timer {
        id: closeDelay
        interval: Motion.hoverCloseDelay
        onTriggered: {
            if (!triggerHover.hovered && !drawerHover.hovered)
                ShellState.closePowerMenu(root.screen)
        }
    }

    Timer {
        id: resetPending
        interval: Motion.pageEnter
        onTriggered: root.pendingAction = ""
    }

    Timer {
        id: actionDelay
        interval: Motion.actionCommitDelay
        onTriggered: {
            const action = root.confirmedAction
            root.confirmedAction = ""
            SystemActionService.performSessionAction(action)
        }
    }

    Item {
        id: edgeTrigger
        x: root.openFromLeft ? 0 : root.width - root.triggerWidth
        y: Math.round((root.height - root.triggerHeight) / 2)
        width: root.triggerWidth
        height: root.triggerHeight
        z: 20

        HoverHandler {
            id: triggerHover
            onHoveredChanged: {
                if (hovered)
                    root.holdOpen()
                else
                    root.scheduleClose()
            }
        }
    }

    Rectangle {
        id: edgeHint
        anchors.left: root.openFromLeft ? parent.left : undefined
        anchors.right: root.openFromLeft ? undefined : parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: triggerHover.hovered && !root.isOpen ? 92 : 72
        radius: Metrics.hairlineRadius
        color: Theme.accent
        opacity: root.isOpen ? 0 : (triggerHover.hovered ? 0.92 : 0.26)

        Behavior on height {
            NumberAnimation {
                duration: Motion.launcherContent
                easing.type: Motion.standardCurve
            }
        }
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Item {
        id: drawer
        width: Metrics.powerDrawerWidth - Metrics.iconS + root.joinSize
        height: root.drawerBodyHeight + root.joinSize * 2
        x: root.openFromLeft
            ? (root.isOpen ? 0 : -width - 2)
            : (root.isOpen ? root.width - width : root.width + 2)
        y: Math.round((root.height - height) / 2)
        scale: 0.985 + root.revealProgress * 0.015
        opacity: 0.88 + root.revealProgress * 0.12
        transformOrigin: root.openFromLeft ? Item.Left : Item.Right

        Behavior on x {
            NumberAnimation {
                duration: root.isOpen ? Motion.drawerEnter : Motion.drawerExit
                easing.type: root.isOpen ? Motion.enterCurve : Motion.exitCurve
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.isOpen ? Motion.drawerEnter : Motion.drawerRevealExit
                easing.type: root.isOpen ? Motion.enterCurve : Motion.exitCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.isOpen ? Motion.exit : Motion.fast
                easing.type: root.isOpen ? Motion.enterCurve : Motion.exitCurve
            }
        }

        HoverHandler {
            id: drawerHover
            onHoveredChanged: {
                if (hovered)
                    closeDelay.stop()
                else
                    root.scheduleClose()
            }
        }

        Item {
            id: drawerSurface
            anchors {
                left: parent.left
                right: parent.right
            }
            y: root.joinSize
            height: root.drawerBodyHeight
            Shape {
                anchors.fill: parent
                visible: root.openFromLeft
                antialiasing: true

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.panel
                    startX: 0
                    startY: 0
                    PathLine { x: drawerSurface.width - Metrics.panelRadius; y: 0 }
                    PathQuad {
                        x: drawerSurface.width
                        y: Metrics.panelRadius
                        controlX: drawerSurface.width
                        controlY: 0
                    }
                    PathLine {
                        x: drawerSurface.width
                        y: drawerSurface.height - Metrics.panelRadius
                    }
                    PathQuad {
                        x: drawerSurface.width - Metrics.panelRadius
                        y: drawerSurface.height
                        controlX: drawerSurface.width
                        controlY: drawerSurface.height
                    }
                    PathLine { x: 0; y: drawerSurface.height }
                    PathLine { x: 0; y: 0 }
                }

            }

            Shape {
                anchors.fill: parent
                visible: !root.openFromLeft
                antialiasing: true

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.panel
                    startX: Metrics.panelRadius
                    startY: 0
                    PathLine { x: drawerSurface.width; y: 0 }
                    PathLine { x: drawerSurface.width; y: drawerSurface.height }
                    PathLine { x: Metrics.panelRadius; y: drawerSurface.height }
                    PathQuad {
                        x: 0
                        y: drawerSurface.height - Metrics.panelRadius
                        controlX: 0
                        controlY: drawerSurface.height
                    }
                    PathLine { x: 0; y: Metrics.panelRadius }
                    PathQuad {
                        x: Metrics.panelRadius
                        y: 0
                        controlX: 0
                        controlY: 0
                    }
                }

            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.panelPadding
                spacing: Metrics.spaceM

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        id: actionsPage
                        anchors.fill: parent
                        spacing: 10
                        enabled: root.pendingAction.length === 0
                        opacity: root.pendingAction.length === 0 ? root.revealValue(0.02) : 0
                        visible: opacity > 0.001
                        transform: Translate {
                            x: root.pendingAction.length > 0
                                ? -18 : root.revealDirection
                                    * (1 - root.revealValue(0.02)) * 22
                            Behavior on x {
                                NumberAnimation {
                                    duration: Motion.exit
                                    easing.type: Motion.standardCurve
                                }
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.launcherContent
                                easing.type: Motion.standardCurve
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 102
                            spacing: 10

                            Repeater {
                                model: [
                                    { action: "lock", title: I18n.tr("power.lock"), subtitle: I18n.tr("power.secureSession"), icon: "lock", enabled: true },
                                    { action: "suspend", title: I18n.tr("power.sleep"), subtitle: I18n.tr("power.suspendComputer"), icon: "bedtime", enabled: true }
                                ]

                                delegate: Rectangle {
                                    id: heroAction
                                    required property var modelData
                                    required property int index
                                    readonly property bool actionEnabled: modelData.enabled !== false
                                    readonly property bool emphasized: modelData.action === "suspend" && actionEnabled
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusLarge
                                    color: emphasized || (actionEnabled && heroHover.hovered)
                                        ? Theme.accentContainer : Theme.surfaceHigh
                                    scale: heroTap.pressed && actionEnabled ? 0.97 : 1
                                    opacity: root.revealValue(index * 0.09) * (actionEnabled ? 1 : 0.58)
                                    transform: Translate {
                                        x: root.revealDirection
                                            * (1 - root.revealValue(heroAction.index * 0.09)) * 24
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 3
                                        MaterialIcon {
                                            text: heroAction.modelData.icon
                                            size: 25
                                            color: heroAction.emphasized || (heroAction.actionEnabled && heroHover.hovered)
                                                ? Theme.accent : (heroAction.actionEnabled ? Theme.text : Theme.textMuted)
                                        }
                                        Item { Layout.fillHeight: true }
                                        Text {
                                            text: heroAction.modelData.title
                                            color: heroAction.emphasized || (heroAction.actionEnabled && heroHover.hovered)
                                                ? Theme.accent : (heroAction.actionEnabled ? Theme.text : Theme.textMuted)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: heroAction.modelData.subtitle
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }

                                    HoverHandler { id: heroHover; enabled: heroAction.actionEnabled }
                                    TapHandler {
                                        id: heroTap
                                        enabled: heroAction.actionEnabled && !SystemActionService.sessionActionRunning
                                        onTapped: root.requestAction(heroAction.modelData.action)
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
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: Theme.radiusMedium
                            color: SystemActionService.keepAwakeActive
                                ? Theme.accentContainer
                                : (keepAwakeHover.hovered ? Theme.surfaceHover : Theme.surfaceHigh)
                            scale: keepAwakeTap.pressed ? 0.985 : 1
                            opacity: root.revealValue(0.2)
                            transform: Translate {
                                x: root.revealDirection
                                    * (1 - root.revealValue(0.2)) * 24
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 9
                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: SystemActionService.keepAwakeActive
                                        ? width / 2 : Metrics.radiusS
                                    color: SystemActionService.keepAwakeActive
                                        ? Theme.accent : Theme.surfaceLow

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "coffee"
                                        size: 20
                                        color: SystemActionService.keepAwakeActive
                                            ? Theme.accentInk : Theme.textMuted
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.tr("power.keepAwake")
                                        color: SystemActionService.keepAwakeActive
                                            ? Theme.accent : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: SystemActionService.keepAwakeActive
                                            ? I18n.tr("power.keepAwakeActive")
                                            : I18n.tr("power.keepAwakeInactive")
                                        color: SystemActionService.keepAwakeActive
                                            ? Theme.accent : Theme.textMuted
                                        opacity: SystemActionService.keepAwakeActive ? 0.82 : 1
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            HoverHandler { id: keepAwakeHover }
                            TapHandler {
                                id: keepAwakeTap
                                enabled: !SystemActionService.keepAwakeStopping
                                onTapped: SystemActionService.toggleKeepAwake()
                            }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Behavior on border.width { NumberAnimation { duration: Motion.fast } }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.instant
                                    easing.type: Motion.standardCurve
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Repeater {
                                model: [
                                    { action: "logout", title: I18n.tr("power.logOut"), subtitle: I18n.tr("power.endSession"), icon: "logout", danger: false },
                                    { action: "reboot", title: I18n.tr("power.restart"), subtitle: I18n.tr("power.restartComputer"), icon: "restart_alt", danger: false },
                                    { action: "poweroff", title: I18n.tr("power.powerOff"), subtitle: I18n.tr("power.shutdownComputer"), icon: "power_settings_new", danger: true }
                                ]

                                delegate: Rectangle {
                                    id: listAction
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58
                                    radius: Theme.radiusMedium
                                    color: listHover.hovered
                                        ? (modelData.danger ? Theme.dangerContainer : Theme.surfaceHover)
                                        : Theme.surfaceLow
                                    scale: listTap.pressed ? 0.985 : 1
                                    opacity: root.revealValue(0.31 + index * 0.09)
                                    transform: Translate {
                                        x: root.revealDirection
                                            * (1 - root.revealValue(0.31 + listAction.index * 0.09)) * 26
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 9
                                        Rectangle {
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34
                                            radius: width / 2
                                            color: listAction.modelData.danger
                                                ? Theme.dangerContainer : Theme.accentContainer

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: listAction.modelData.icon
                                                size: 20
                                                fill: 1
                                                color: listAction.modelData.danger
                                                    ? Theme.dangerContainerInk : Theme.accentContainerInk
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 0
                                            Text {
                                                Layout.fillWidth: true
                                                text: listAction.modelData.title
                                                color: listAction.modelData.danger ? Theme.danger : Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: listAction.modelData.subtitle
                                                color: Theme.textMuted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }
                                        Item {
                                            Layout.preferredWidth: 28
                                            Layout.fillHeight: true

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: "chevron_right"
                                                size: 19
                                                fill: 1
                                                color: listAction.modelData.danger
                                                    ? Theme.dangerContainerInk : Theme.accentContainerInk
                                            }
                                        }
                                    }

                                    HoverHandler { id: listHover }
                                    TapHandler {
                                        id: listTap
                                        enabled: !SystemActionService.sessionActionRunning
                                        onTapped: root.requestAction(listAction.modelData.action)
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
                        }
                    }

                    ColumnLayout {
                        id: confirmationPage
                        anchors.fill: parent
                        enabled: root.pendingAction.length > 0
                        opacity: root.pendingAction.length > 0 ? 1 : 0
                        visible: opacity > 0.001
                        spacing: 14
                        transform: Translate {
                            x: root.pendingAction.length > 0 ? 0 : 22
                            Behavior on x {
                                NumberAnimation {
                                    duration: Motion.exit
                                    easing.type: Motion.standardCurve
                                }
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.launcherContent
                                easing.type: Motion.standardCurve
                            }
                        }

                        Item { Layout.fillHeight: true }
                        Rectangle {
                            id: confirmationIcon
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 86
                            Layout.preferredHeight: 86
                            // Morphs from a rounded square into a circle as it appears.
                            radius: root.pendingAction.length > 0 ? width / 2 : Metrics.radiusL
                            color: root.pendingAction === "poweroff"
                                ? Theme.dangerContainer : Theme.accentContainer
                            scale: root.pendingAction.length > 0 ? 1 : 0.82
                            Behavior on radius {
                                NumberAnimation {
                                    duration: Motion.springDefault
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialDefault
                                }
                            }
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.actionIcon(root.pendingAction)
                                size: 40
                                fill: 1
                                color: root.pendingAction === "poweroff"
                                    ? Theme.dangerContainerInk : Theme.accentContainerInk
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.springDefault
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialDefault
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.actionTitle(root.pendingAction)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 23
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.actionDescription(root.pendingAction)
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            spacing: 9
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: height / 2
                                color: cancelHover.hovered ? Theme.surfaceHover : Theme.surfaceHigh
                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.tr("common.cancel")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                                HoverHandler { id: cancelHover }
                                TapHandler { onTapped: root.pendingAction = "" }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                // Filled confirm button: error colour for power off.
                                radius: height / 2
                                color: root.pendingAction === "poweroff"
                                    ? Theme.danger : Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: root.actionTitle(root.pendingAction)
                                    color: root.pendingAction === "poweroff" ? Theme.dangerInk : Theme.accentInk
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                                TapHandler { onTapped: root.confirmAction() }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: SystemActionService.sessionActionError.length > 0
                    text: SystemActionService.sessionActionError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Canvas {
            id: topJoin
            anchors.top: parent.top
            anchors.left: root.openFromLeft ? parent.left : undefined
            anchors.right: root.openFromLeft ? undefined : parent.right
            width: root.joinSize
            height: root.joinSize
            antialiasing: true
            property color surfaceColor: Theme.panel
            property bool leftEdge: root.openFromLeft

            onSurfaceColorChanged: requestPaint()
            onLeftEdgeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                const context = getContext("2d")
                context.reset()
                context.fillStyle = surfaceColor
                context.fillRect(0, 0, width, height)
                context.globalCompositeOperation = "destination-out"
                context.beginPath()
                if (leftEdge) {
                    context.arc(width, 0, width, Math.PI * 0.5, Math.PI, false)
                    context.lineTo(width, 0)
                } else {
                    context.arc(0, 0, width, 0, Math.PI * 0.5, false)
                    context.lineTo(0, 0)
                }
                context.closePath()
                context.fill()
            }
        }

        Canvas {
            id: bottomJoin
            anchors.bottom: parent.bottom
            anchors.left: root.openFromLeft ? parent.left : undefined
            anchors.right: root.openFromLeft ? undefined : parent.right
            width: root.joinSize
            height: root.joinSize
            antialiasing: true
            property color surfaceColor: Theme.panel
            property bool leftEdge: root.openFromLeft

            onSurfaceColorChanged: requestPaint()
            onLeftEdgeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                const context = getContext("2d")
                context.reset()
                context.fillStyle = surfaceColor
                context.fillRect(0, 0, width, height)
                context.globalCompositeOperation = "destination-out"
                context.beginPath()
                if (leftEdge) {
                    context.arc(width, height, width, Math.PI, 1.5 * Math.PI, false)
                    context.lineTo(width, height)
                } else {
                    context.arc(0, height, width, 1.5 * Math.PI, 2 * Math.PI, false)
                    context.lineTo(0, height)
                }
                context.closePath()
                context.fill()
            }
        }
    }
}
