import QtQuick
import qs.core
import qs.compositor
import qs.widgets

// Close, minimise and fill-the-screen for the active window, in the bar.
// Apps under a tiling window manager usually have no title bar buttons of
// their own, so these give the mouse a way to do it. A right click on the
// last one opens the snap layouts.
Row {
    id: root

    readonly property var win: Compositor.focusedWindow
    visible: Config.windowButtons && !!win
    spacing: 6

    component Dot: Rectangle {
        id: dot
        property color tone: Theme.primary
        property string icon: ""
        signal tapped(var mouse)
        width: 16
        height: 16
        radius: touch.pressed ? 5 : 8
        color: tone
        Behavior on radius { Spring {} }
        MIcon {
            anchors.centerIn: parent
            visible: hover.hovered || touch.containsMouse
            icon: dot.icon
            size: 12
            color: Theme.surface
        }
        MouseArea {
            id: touch
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => dot.tapped(mouse)
        }
    }
    // The glyphs show on all three while the pointer is over the group.
    HoverHandler { id: hover }

    Dot { tone: Theme.error; icon: "close"; onTapped: Compositor.closeWindow(root.win.id) }
    Dot { tone: Theme.tertiary; icon: "remove"; onTapped: Compositor.minimize(root.win.id) }
    Dot {
        tone: Theme.primary
        icon: "open_in_full"
        visible: Compositor.canSnap
        onTapped: mouse => {
            if (mouse.button === Qt.RightButton) Shell.toggle("snap", null)
            else Compositor.toggleMaximize(root.win.id)
        }
    }
}
