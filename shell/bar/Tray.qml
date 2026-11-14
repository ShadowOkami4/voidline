import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import qs.core
import qs.widgets

Row {
    id: root

    required property var window
    spacing: 2
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Pressable {
            id: item
            required property var modelData
            width: 28
            height: 28
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            selected: Shell.panel === "tray" && Shell.trayItem === modelData
            // Scrolling over an icon is passed on (volume for players, for example).
            wheelEnabled: true
            onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                    if (modelData.hasMenu) Shell.openTray(modelData, root.window.screen)
                } else if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate()
                } else {
                    modelData.activate()
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: item.modelData.icon
            }
        }
    }
}
