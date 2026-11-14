import QtQuick
import qs.core
import qs.widgets

// Dropdown menu: shows the current choice, opens a list underneath on click.
// The list is drawn on top of the whole window (not inside the surrounding
// layout), so it never gets cut off; clicking anywhere else closes it.
Pressable {
    id: root

    // [{ value, label }]
    property var options: []
    property var value
    property bool open: false
    signal picked(var value)

    function same(a, b) { return typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 0.011 : a === b }
    readonly property var current: options.find(o => same(o.value, value)) ?? null

    implicitWidth: 220
    implicitHeight: 46
    color: Theme.surfaceContainerHighest
    restRadius: open ? Theme.cornerM : Theme.cornerFull
    pressedRadius: Theme.cornerM
    border.width: open ? 2 : 0
    border.color: Theme.primary
    onClicked: open = !open
    onVisibleChanged: if (!visible) open = false

    Label {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: arrow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.current ? root.current.label : ""
        font.weight: Font.DemiBold
    }
    MIcon {
        id: arrow
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        icon: "expand_more"
        size: 22
        color: Theme.inkMuted
        rotation: root.open ? 180 : 0
        Behavior on rotation { Spring {} }
    }

    Item {
        id: layer
        parent: root.Window.contentItem
        anchors.fill: parent
        visible: root.open
        z: 9999

        // Where the button is inside the window, worked out when opening.
        property point at: Qt.point(0, 0)
        onVisibleChanged: if (visible && parent) at = root.mapToItem(parent, 0, 0)
        readonly property real menuHeight: Math.min(list.contentHeight + 12, 320)
        readonly property bool above: at.y + root.height + 6 + menuHeight > height - 8 && at.y - 6 - menuHeight > 8

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.open = false
            onWheel: root.open = false
        }

        Rectangle {
            id: menu
            x: Math.max(8, Math.min(layer.width - width - 8, layer.at.x))
            y: layer.above ? layer.at.y - 6 - height : layer.at.y + root.height + 6
            width: Math.max(root.width, 180)
            height: layer.menuHeight
            radius: Theme.cornerL
            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.outlineVariant
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            transformOrigin: layer.above ? Item.Bottom : Item.Top
            Behavior on opacity { Fade {} }
            Behavior on scale { Spring {} }

            MouseArea { anchors.fill: parent }      // clicks on the menu itself do not close it

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.options
                delegate: Pressable {
                    id: row
                    required property var modelData
                    readonly property bool current: root.same(modelData.value, root.value)
                    width: list.width
                    height: 42
                    color: current ? Theme.secondaryContainer : "transparent"
                    restRadius: current ? Theme.cornerFull : Theme.cornerM
                    pressedRadius: Theme.cornerS
                    onClicked: { root.open = false; root.picked(modelData.value) }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: tick.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.label
                        font.weight: row.current ? Font.Bold : Font.Normal
                        color: row.current ? Theme.inkOnSecondaryContainer : Theme.ink
                    }
                    MIcon {
                        id: tick
                        visible: row.current
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "check"
                        size: 18
                        color: Theme.inkOnSecondaryContainer
                    }
                }
            }
        }
    }
}
