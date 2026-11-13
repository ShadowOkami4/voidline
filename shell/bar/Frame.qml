import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.widgets

// Voidline style only: a thin frame on the left, right and bottom edges that
// continues the bar, with rounded inner corners at the bottom.
Scope {
    id: root
    required property var screen

    PanelWindow {
        screen: root.screen
        anchors { left: true; top: true; bottom: true }
        implicitWidth: Style.frameWidth
        exclusiveZone: Style.frameWidth
        color: Style.barColor
        WlrLayershell.namespace: "voidline-frame"
    }

    PanelWindow {
        screen: root.screen
        anchors { right: true; top: true; bottom: true }
        implicitWidth: Style.frameWidth
        exclusiveZone: Style.frameWidth
        color: Style.barColor
        WlrLayershell.namespace: "voidline-frame"
    }

    PanelWindow {
        screen: root.screen
        anchors { left: true; right: true; bottom: true }
        implicitHeight: Style.frameWidth + Style.frameRadius
        exclusiveZone: Style.frameWidth
        color: "transparent"
        WlrLayershell.namespace: "voidline-frame"
        mask: Region { item: strip }

        Rectangle {
            id: strip
            anchors.bottom: parent.bottom
            width: parent.width
            height: Style.frameWidth
            color: Style.barColor
        }
        ConcaveJoin { x: Style.frameWidth; corner: "bl"; fill: Style.barColor }
        ConcaveJoin { x: parent.width - width - Style.frameWidth; corner: "br"; fill: Style.barColor }
    }
}
