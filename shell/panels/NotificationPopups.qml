import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.services
import qs.widgets

// Popup stack on the primary screen. The window only exists while there is
// something to show, and only the cards take input.
PanelWindow {
    id: popups

    readonly property bool atTop: Style.notificationAnchor.startsWith("top")

    anchors { top: popups.atTop; bottom: !popups.atTop; right: true }
    margins { top: Style.panelGap; bottom: Style.panelGap; right: Style.panelGap }
    implicitWidth: 380
    implicitHeight: Math.max(1, list.contentHeight)
    color: "transparent"
    visible: Notifs.popups.length > 0 && Shell.panel !== "quick"
    WlrLayershell.namespace: "voidline-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    ListView {
        id: list
        anchors.fill: parent
        spacing: 8
        interactive: false
        verticalLayoutDirection: popups.atTop ? ListView.TopToBottom : ListView.BottomToTop
        model: Notifs.popups

        add: Transition {
            ParallelAnimation {
                Spring { property: "x"; from: 80; to: 0; duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve }
                Fade { property: "opacity"; from: 0; to: 1 }
            }
        }
        displaced: Transition { Spring { properties: "y" } }

        delegate: NotificationCard {
            required property var modelData
            width: list.width
            notification: modelData
            base: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)
            onDismissed: Notifs.dismissPopup(modelData.id)
        }
    }
}
