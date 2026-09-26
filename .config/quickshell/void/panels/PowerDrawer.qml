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
            ? (root.isOpen ? Theme.panelSideGap : -width - 2)
            : (root.isOpen ? root.width - width - Theme.panelSideGap : root.width + 2)
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
            // Outside the frame style the drawer floats as a rounded card.
            Rectangle {
                anchors.fill: parent
                visible: !Theme.panelsAttached
                radius: Metrics.panelRadius
                color: Theme.panel
            }

            Shape {
                anchors.fill: parent
                visible: Theme.panelsAttached && root.openFromLeft
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
                visible: Theme.panelsAttached && !root.openFromLeft
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
                        spacing: Metrics.spaceS
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

                        // Slim M3 Expressive power list: one pill per action,
                        // Power off as the single filled (error) action, and
                        // Keep awake as a switch below a divider.
                        Repeater {
                            model: [
                                { action: "lock", title: I18n.tr("power.lock"), icon: "lock" },
                                { action: "suspend", title: I18n.tr("power.sleep"), icon: "bedtime" },
                                { action: "logout", title: I18n.tr("power.logOut"), icon: "logout" },
                                { action: "reboot", title: I18n.tr("power.restart"), icon: "restart_alt" },
                                { action: "poweroff", title: I18n.tr("power.powerOff"), icon: "power_settings_new" }
                            ]

                            delegate: Rectangle {
                                id: actionRow
                                required property var modelData
                                required property int index
                                readonly property bool danger: modelData.action === "poweroff"
                                readonly property color ink: danger ? Theme.dangerInk : Theme.text

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(52 * Metrics.scale)
                                radius: rowTap.pressed ? Metrics.radiusM : height / 2
                                color: danger ? (rowHover.hovered ? Qt.lighter(Theme.danger, 1.08) : Theme.danger)
                                    : (rowHover.hovered ? Theme.surfaceHover : Theme.surfaceContainerHighest)
                                opacity: root.revealValue(index * 0.06)
                                    * (SystemActionService.sessionActionRunning ? 0.5 : 1)
                                transform: Translate {
                                    x: root.revealDirection
                                        * (1 - root.revealValue(actionRow.index * 0.06)) * 24
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.title

                                Behavior on radius {
                                    NumberAnimation {
                                        duration: Motion.springFast
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Motion.spatialFast
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(8 * Metrics.scale)
                                    anchors.rightMargin: Metrics.spaceL
                                    spacing: Metrics.spaceM

                                    Rectangle {
                                        Layout.preferredWidth: Math.round(36 * Metrics.scale)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: width / 2
                                        color: actionRow.danger ? Theme.withAlpha(actionRow.ink, 0.16)
                                            : Theme.surfaceContainer

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: actionRow.modelData.icon
                                            size: Math.round(20 * Metrics.scale)
                                            fill: 1
                                            color: actionRow.danger ? actionRow.ink : Theme.accent
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: actionRow.modelData.title
                                        color: actionRow.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.round(15 * Metrics.scale)
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }

                                HoverHandler {
                                    id: rowHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    id: rowTap
                                    enabled: !SystemActionService.sessionActionRunning
                                    onTapped: root.requestAction(actionRow.modelData.action)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Metrics.divider
                            color: Theme.outlineVariant
                            opacity: root.revealValue(0.3)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: Math.round(44 * Metrics.scale)
                            Layout.leftMargin: Math.round(8 * Metrics.scale)
                            spacing: Metrics.spaceM
                            opacity: root.revealValue(0.3) * (SystemActionService.keepAwakeStopping ? 0.5 : 1)

                            MaterialIcon {
                                Layout.preferredWidth: Math.round(36 * Metrics.scale)
                                horizontalAlignment: Text.AlignHCenter
                                text: "coffee"
                                size: Math.round(20 * Metrics.scale)
                                fill: SystemActionService.keepAwakeActive ? 1 : 0
                                color: SystemActionService.keepAwakeActive ? Theme.accent : Theme.textMuted
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.tr("power.keepAwake")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.round(14 * Metrics.scale)
                                elide: Text.ElideRight
                            }
                            ToggleSwitch {
                                checked: SystemActionService.keepAwakeActive
                                enabled: !SystemActionService.keepAwakeStopping
                                showIcons: true
                                onToggled: SystemActionService.toggleKeepAwake()
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
                            // Nested layouts fill height by default; keep the
                            // buttons at their intended size.
                            Layout.fillHeight: false
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
            visible: Theme.panelsAttached
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
            visible: Theme.panelsAttached
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
