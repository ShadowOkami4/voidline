import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    required property Item anchorItem
    property var hostWindow
    property var menu
    property string placement: "top"
    property var menuStack: []
    property bool revealed: false
    readonly property bool open: popup.visible

    function show(menuHandle) {
        const handle = menuHandle || menu
        if (!handle || !hostWindow)
            return false
        menuStack = [handle]
        opener.menu = handle
        revealed = false
        popup.anchor.window = hostWindow
        popup.visible = true
        popupPosition.restart()
        return true
    }

    function hide() {
        revealed = false
        closeDelay.restart()
    }

    function enterSubmenu(entry) {
        if (!entry || !entry.hasChildren)
            return
        menuStack = menuStack.concat([entry])
        opener.menu = entry
        popupPosition.restart()
    }

    function leaveSubmenu() {
        if (menuStack.length <= 1)
            return
        menuStack = menuStack.slice(0, menuStack.length - 1)
        opener.menu = menuStack[menuStack.length - 1]
        popupPosition.restart()
    }

    function positionPopup() {
        if (!hostWindow || !anchorItem)
            return
        const point = anchorItem.mapToItem(null, 0, 0)
        let nextX = point.x + anchorItem.width / 2 - popup.width / 2
        let nextY = point.y + anchorItem.height + 6
        if (placement === "bottom")
            nextY = point.y - popup.height - 6
        else if (placement === "left") {
            nextX = point.x + anchorItem.width + 6
            nextY = point.y + anchorItem.height / 2 - popup.height / 2
        } else if (placement === "right") {
            nextX = point.x - popup.width - 6
            nextY = point.y + anchorItem.height / 2 - popup.height / 2
        }
        // The bar's layer window is intentionally thin on one axis. Clamping
        // both coordinates to that window would move a bottom/side menu back
        // into the bar. Clamp only along the full-screen axis and preserve the
        // outward offset on the attached edge.
        if (placement === "top" || placement === "bottom")
            nextX = Math.max(8, Math.min(hostWindow.width - popup.width - 8, nextX))
        else
            nextY = Math.max(8, Math.min(hostWindow.height - popup.height - 8, nextY))
        popup.anchor.rect.x = nextX
        popup.anchor.rect.y = nextY
        openDelay.restart()
    }

    QsMenuOpener {
        id: opener
        menu: root.menu
    }

    Timer {
        id: popupPosition
        interval: 0
        onTriggered: root.positionPopup()
    }

    Timer {
        id: openDelay
        interval: 0
        onTriggered: root.revealed = true
    }

    Timer {
        id: closeDelay
        interval: Appearance.reduceMotion ? 0 : Motion.fast
        onTriggered: popup.visible = false
    }

    PopupWindow {
        id: popup
        implicitWidth: Metrics.contextMenuWidth
        implicitHeight: Math.min(500, Math.max(54,
            menuColumn.implicitHeight + 16))
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (!visible) {
                root.revealed = false
                root.menuStack = []
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Metrics.panelRadius
            color: Theme.panelRaised
            border.width: Metrics.border
            border.color: Theme.outlineSoft
            opacity: root.revealed ? 1 : 0
            scale: root.revealed ? 1 : 0.96
            clip: true

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.reduceMotion ? 0 : Motion.fast
                    easing.type: Motion.standardCurve
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.reduceMotion ? 0 : Motion.fast
                    easing.type: Motion.enterCurve
                }
            }

            Flickable {
                anchors { fill: parent; margins: 8 }
                contentWidth: width
                contentHeight: menuColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: menuColumn
                    width: parent.width
                    spacing: 2

                    Rectangle {
                        width: parent.width
                        height: root.menuStack.length > 1 ? 42 : 0
                        visible: height > 0
                        radius: Theme.radiusMedium
                        color: backHover.hovered ? Theme.surfaceHover : "transparent"
                        clip: true

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            MaterialIcon {
                                text: "arrow_back"
                                size: 18
                                color: Theme.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.menuStack.length > 1
                                    ? String(root.menuStack[root.menuStack.length - 1].text || "")
                                    : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                        HoverHandler { id: backHover }
                        TapHandler { onTapped: root.leaveSubmenu() }
                    }

                    Repeater {
                        model: opener.children

                        delegate: Item {
                            id: menuEntry
                            required property var modelData
                            width: menuColumn.width
                            height: modelData.isSeparator ? 9 : 44

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 7
                                    rightMargin: 7
                                }
                                height: 1
                                visible: menuEntry.modelData.isSeparator
                                color: Theme.divider
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !menuEntry.modelData.isSeparator
                                radius: Theme.radiusMedium
                                color: entryHover.hovered && menuEntry.modelData.enabled
                                    ? Theme.surfaceHover : "transparent"
                                opacity: menuEntry.modelData.enabled ? 1 : 0.45
                                clip: true

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 10
                                        rightMargin: 10
                                    }
                                    spacing: 9

                                    Item {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22

                                        Image {
                                            id: entryImage
                                            anchors.centerIn: parent
                                            width: 19
                                            height: 19
                                            source: menuEntry.modelData.icon || ""
                                            sourceSize: Qt.size(32, 32)
                                            visible: source.toString().length > 0
                                                && status === Image.Ready
                                        }
                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            visible: !entryImage.visible
                                                && (menuEntry.modelData.checkState === Qt.Checked
                                                    || menuEntry.modelData.checkState === Qt.PartiallyChecked)
                                            text: menuEntry.modelData.checkState === Qt.PartiallyChecked
                                                ? "remove" : "check"
                                            size: 18
                                            color: Theme.accent
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: menuEntry.modelData.text || ""
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    MaterialIcon {
                                        visible: menuEntry.modelData.hasChildren
                                        text: "chevron_right"
                                        size: 18
                                        color: Theme.textMuted
                                    }
                                }

                                HoverHandler { id: entryHover }
                                TapHandler {
                                    enabled: menuEntry.modelData.enabled
                                    onTapped: {
                                        if (menuEntry.modelData.hasChildren) {
                                            root.enterSubmenu(menuEntry.modelData)
                                        } else {
                                            menuEntry.modelData.triggered()
                                            root.hide()
                                        }
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.reduceMotion ? 0 : Motion.fast
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
