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
    // Only so a reply can be typed; it takes the keyboard when clicked into.
    WlrLayershell.keyboardFocus: Notifs.held.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    ListView {
        id: list
        anchors.fill: parent
        spacing: 8
        interactive: false
        verticalLayoutDirection: popups.atTop ? ListView.TopToBottom : ListView.BottomToTop
        // Follows the popups one by one, so each slides in and out on its own.
        model: KeyedModel { keys: Notifs.popups.map(n => n.id) }

        add: Transition {
            ParallelAnimation {
                Spring { property: "x"; from: 80; to: 0; duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve }
                Fade { property: "opacity"; from: 0; to: 1 }
            }
        }
        remove: Transition {
            ParallelAnimation {
                Spring { property: "x"; to: 120; duration: Motion.spatialFast }
                Fade { property: "opacity"; to: 0 }
            }
        }
        displaced: Transition { Spring { properties: "y"; duration: Motion.spatial; easing.bezierCurve: Motion.spatialCurve } }

        delegate: NotificationCard {
            required property string key
            // Kept after the notification leaves, while it slides out.
            property var modelData: Notifs.list.find(n => String(n.id) === key) ?? null
            onModelDataChanged: if (modelData) kept = modelData
            property var kept: null
            width: list.width
            visible: !!kept
            notification: kept
            base: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)
            onDismissed: if (kept) Notifs.dismissPopup(kept.id)
        }
    }
}
