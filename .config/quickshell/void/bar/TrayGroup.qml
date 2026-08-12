import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"

Item {
    id: root

    property var barWindow
    property string barPosition: "top"
    property bool vertical: false
    property int page: 0
    readonly property var trayItems: SystemTray.items.values || []
    readonly property int itemCount: trayItems.length
    readonly property int capacity: vertical ? 3 : 5
    readonly property int pageCount: Math.max(1, Math.ceil(itemCount / capacity))
    readonly property int firstVisible: Math.min(page * capacity,
        Math.max(0, itemCount - 1))

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    visible: itemCount > 0

    onItemCountChanged: {
        if (page >= pageCount)
            page = Math.max(0, pageCount - 1)
    }

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.capacity + 1
        rows: root.vertical ? root.capacity + 1 : 1
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: root.trayItems

            delegate: TrayItem {
                required property var modelData
                required property int index
                trayItem: modelData
                barWindow: root.barWindow
                barPosition: root.barPosition
                visible: index >= root.firstVisible
                    && index < root.firstVisible + root.capacity
            }
        }

        Item {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            visible: root.pageCount > 1

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMedium
                color: overflowHover.hovered ? Theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
            MaterialIcon {
                anchors.centerIn: parent
                text: root.vertical ? "more_vert" : "more_horiz"
                size: 18
                color: Theme.textMuted
            }
            HoverHandler { id: overflowHover }
            TapHandler {
                onTapped: root.page = (root.page + 1) % root.pageCount
            }
            WheelHandler {
                onWheel: event => {
                    const delta = event.angleDelta.y !== 0
                        ? event.angleDelta.y : event.angleDelta.x
                    root.page = (root.page + (delta < 0 ? 1 : -1)
                        + root.pageCount) % root.pageCount
                    event.accepted = true
                }
            }
        }
    }
}
