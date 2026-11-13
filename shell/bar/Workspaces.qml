import QtQuick
import qs.core
import qs.compositor
import qs.widgets

// Workspace dots. The active one stretches into a pill; occupied ones are
// brighter than empty ones. Scroll to move between workspaces.
Item {
    id: root

    readonly property var list: Compositor.workspaces
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceContainerHigh
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.list
            Rectangle {
                id: dot
                required property var modelData
                width: modelData.active ? 26 : 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.active ? Theme.primary
                    : (modelData.occupied ? Theme.inkMuted : Theme.outlineVariant)
                Behavior on width { Spring {} }
                Behavior on color { Tint {} }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(dot.modelData)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const i = root.list.findIndex(w => w.active)
            const next = root.list[i + (wheel.angleDelta.y < 0 ? 1 : -1)]
            if (next) Compositor.focusWorkspace(next)
        }
    }
}
