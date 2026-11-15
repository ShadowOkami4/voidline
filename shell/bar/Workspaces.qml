import QtQuick
import qs.core
import qs.compositor
import qs.widgets

// Workspace dots. The active one is a pill that travels between the dots:
// its front edge runs ahead and the back edge catches up, so it stretches
// on the way. Occupied dots are brighter than empty ones. Scroll to move
// between workspaces; right click for the overview.
Item {
    id: root

    readonly property var list: Compositor.workspaces
    readonly property int current: Math.max(0, list.findIndex(w => w.active))
    // A named workspace shows its name while it is the active one.
    readonly property string name: list[current] ? Config.workspaceName(list[current].index) : ""
    readonly property real pill: name.length > 0 ? caption.implicitWidth + 16 : 26
    readonly property int step: 14
    implicitWidth: Math.max(0, list.length - 1) * step + pill + 16
    implicitHeight: 28

    // The pill's two edges, set by hand so the direction is known first.
    property int way: 1
    property real head: 0
    property real tail: 26
    function place() {
        const left = current * step
        way = left >= head ? 1 : -1
        head = left
        tail = left + pill
    }
    onCurrentChanged: place()
    onPillChanged: place()
    Component.onCompleted: place()
    Behavior on head { NumberAnimation { duration: root.way > 0 ? Motion.spatial : Motion.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: root.way > 0 ? Motion.spatialCurve : Motion.effectsCurve } }
    Behavior on tail { NumberAnimation { duration: root.way > 0 ? Motion.effects : Motion.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: root.way > 0 ? Motion.effectsCurve : Motion.spatialCurve } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceContainerHigh
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Shell.toggle("switcher", null)
        onWheel: wheel => {
            const next = root.list[root.current + (wheel.angleDelta.y < 0 ? 1 : -1)]
            if (next) Compositor.focusWorkspace(next)
        }
    }

    Repeater {
        model: root.list
        Item {
            id: dot
            required property var modelData
            required property int index
            readonly property bool active: index === root.current
            x: 8 + index * root.step + (index > root.current ? root.pill - 8 : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            Behavior on x { Spring { duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: dot.modelData.occupied ? Theme.inkMuted : Theme.outlineVariant
                opacity: dot.active ? 0 : 1
                // Grows under the pointer, and pops when a window arrives.
                scale: reach.pressed ? 0.8 : (reach.containsMouse ? 1.6 : (dot.modelData.occupied ? 1 : 0.85))
                Behavior on scale { Spring {} }
                Behavior on color { Tint {} }
                Behavior on opacity { Fade {} }
            }
            MouseArea {
                id: reach
                anchors.fill: parent
                anchors.margins: -8
                enabled: !dot.active
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Shell.toggle("switcher", null)
                    else Compositor.focusWorkspace(dot.modelData)
                }
            }
        }
    }

    Rectangle {
        id: runner
        x: 8 + Math.min(root.head, root.tail - 8)
        width: Math.max(8, root.tail - root.head)
        height: root.name.length > 0 ? 18 : 8
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Theme.primary
        Behavior on height { Spring {} }
        clip: true
        Label {
            id: caption
            anchors.centerIn: parent
            text: root.name
            opacity: root.name.length > 0 && runner.width >= implicitWidth + 10 ? 1 : 0
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Theme.inkOnPrimary
            Behavior on opacity { Fade {} }
        }
    }
}
