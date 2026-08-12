import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls as Controls
import "../components"
import "../core"

Item {
    id: root

    required property var trayItem
    property var barWindow
    property string barPosition: "top"
    property int itemSize: 30
    property bool tooltipReady: false

    implicitWidth: itemSize
    implicitHeight: itemSize
    scale: primaryTap.pressed ? 0.94 : 1

    readonly property bool attention:
        trayItem && trayItem.status === Status.NeedsAttention
    readonly property string tooltipText: {
        if (!trayItem)
            return ""
        const title = trayItem.tooltipTitle || trayItem.title || trayItem.id || "Background application"
        const description = trayItem.tooltipDescription || ""
        return description.length > 0 ? title + "\n" + description : title
    }

    function menuPoint() {
        const point = root.mapToItem(null, 0, 0)
        if (barPosition === "bottom")
            return Qt.point(point.x + width / 2, point.y)
        if (barPosition === "left")
            return Qt.point(point.x + width, point.y + height / 2)
        if (barPosition === "right")
            return Qt.point(point.x, point.y + height / 2)
        return Qt.point(point.x + width / 2, point.y + height)
    }

    function showMenu() {
        if (!trayItem || !trayItem.hasMenu || !barWindow)
            return false
        return contextMenu.show(trayItem.menu)
    }

    VoidContextMenu {
        id: contextMenu
        anchorItem: root
        hostWindow: root.barWindow
        menu: root.trayItem ? root.trayItem.menu : null
        placement: root.barPosition
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: root.attention ? Theme.tertiaryContainer
            : (hover.hovered ? Theme.surfaceHover : "transparent")
        border.width: root.attention ? 1 : 0
        border.color: Theme.tertiary
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Image {
        id: appIcon
        anchors.centerIn: parent
        width: 19
        height: 19
        source: root.trayItem ? root.trayItem.icon : ""
        sourceSize: Qt.size(38, 38)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: source.toString().length > 0 && status === Image.Ready
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: !appIcon.visible
        text: root.attention ? "notification_important" : "deployed_code"
        size: 18
        color: root.attention ? Theme.tertiary : Theme.textMuted
    }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            margins: 3
        }
        width: 5
        height: 5
        radius: 3
        color: Theme.tertiary
        visible: root.attention
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered)
                tooltipDelay.restart()
            else {
                tooltipDelay.stop()
                root.tooltipReady = false
            }
        }
    }

    Timer {
        id: tooltipDelay
        interval: 450
        onTriggered: root.tooltipReady = true
    }

    Controls.ToolTip {
        visible: root.tooltipReady && root.tooltipText.length > 0
        text: root.tooltipText
        x: root.barPosition === "left" ? root.width + 7
            : (root.barPosition === "right" ? -implicitWidth - 7
                : (root.width - implicitWidth) / 2)
        y: root.barPosition === "top" ? root.height + 7
            : (root.barPosition === "bottom" ? -implicitHeight - 7
                : (root.height - implicitHeight) / 2)
        padding: 9

        contentItem: Text {
            text: root.tooltipText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 10
            lineHeight: 1.12
        }
        background: Rectangle {
            radius: Theme.radiusMedium
            color: Theme.surfaceHigh
            border.width: 1
            border.color: Theme.outlineSoft
        }
    }

    TapHandler {
        id: primaryTap
        acceptedButtons: Qt.LeftButton
        onTapped: {
            root.tooltipReady = false
            if (root.trayItem.onlyMenu) {
                root.showMenu()
            } else {
                root.trayItem.activate()
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            root.tooltipReady = false
            if (!root.showMenu())
                root.trayItem.secondaryActivate()
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.trayItem.secondaryActivate()
    }

    WheelHandler {
        onWheel: event => {
            const horizontal = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
            const delta = horizontal ? event.angleDelta.x : event.angleDelta.y
            if (delta !== 0)
                root.trayItem.scroll(delta, horizontal)
            event.accepted = true
        }
    }

    Behavior on scale {
        NumberAnimation { duration: Motion.instant; easing.type: Easing.OutCubic }
    }
}
