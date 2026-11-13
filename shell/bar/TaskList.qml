import Quickshell.Widgets
import QtQuick
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Running windows as icons (Windows taskbar and macOS dock).
// Click: focus, or minimise if already focused, or restore if minimised.
// Middle click: close. Minimised windows are dimmed with a hollow indicator.
Row {
    id: root

    property int iconSize: 28
    property int cell: 44
    // "bar": indicator line under the icon. "dot": small dot (dock).
    property string indicator: "bar"
    spacing: 4

    Repeater {
        model: Compositor.windows

        Pressable {
            id: task
            required property var modelData
            width: root.cell
            height: root.cell
            restRadius: Theme.cornerM
            pressedRadius: Theme.cornerS
            color: modelData.focused ? Theme.alpha(Theme.ink, 0.10) : "transparent"
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            Behavior on color { Tint {} }

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) Compositor.closeWindow(modelData.id)
                else Compositor.activate(modelData)
            }

            AppIcon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                size: root.iconSize
                icon: Apps.iconNameFor(task.modelData.appId)
                name: task.modelData.appId
                opacity: task.modelData.minimized ? 0.45 : 1
                scale: task.pressed ? 0.86 : 1
                Behavior on scale { Spring {} }
                Behavior on opacity { Fade {} }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                height: root.indicator === "dot" ? 4 : 3
                width: root.indicator === "dot" ? 4 : (task.modelData.focused ? 18 : 6)
                radius: 2
                color: task.modelData.focused ? Theme.primary
                    : (task.modelData.minimized ? "transparent" : Theme.inkMuted)
                border.width: task.modelData.minimized ? 1 : 0
                border.color: Theme.inkMuted
                Behavior on width { Spring {} }
                Behavior on color { Tint {} }
            }
        }
    }
}
