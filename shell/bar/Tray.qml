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

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                    if (modelData.hasMenu) {
                        const p = item.mapToItem(null, 0, item.height)
                        modelData.display(root.window, p.x, p.y)
                    }
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
