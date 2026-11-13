import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.compositor
import qs.widgets

// macOS style: floating dock with the launcher and running windows.
PanelWindow {
    id: dock

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Style.dockHeight + 10
    exclusiveZone: Style.dockHeight + 6
    color: "transparent"
    WlrLayershell.namespace: "voidline-dock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: plate }

    Rectangle {
        id: plate
        anchors.horizontalCenter: parent.horizontalCenter
        y: 2
        width: row.implicitWidth + 20
        height: Style.dockHeight
        radius: Theme.cornerXL
        color: Theme.alpha(Theme.surfaceContainer, 0.82)
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.6)
        Behavior on width { Spring {} }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: "apps"
                size: 48
                iconSize: 28
                tonal: true
                restRadius: Theme.cornerL
                selected: Shell.panel === "launcher"
                onClicked: Shell.toggle("launcher", dock.screen)
            }

            Rectangle {
                visible: Compositor.windows.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 32
                color: Theme.outlineVariant
            }

            TaskList {
                anchors.verticalCenter: parent.verticalCenter
                iconSize: 38
                cell: 52
                indicator: "dot"
            }
        }
    }
}
