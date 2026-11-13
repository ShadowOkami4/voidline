import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core

// Full-screen transparent layer that hosts the launcher and quick settings.
// It exists only while a panel is open (or animating out); clicking outside a
// panel or pressing Esc closes it. This works the same on every compositor,
// with no compositor-specific focus grabbing.
PanelWindow {
    id: host

    readonly property bool mine: Shell.screen === screen || (!Shell.screen && screen === Quickshell.screens[0])
    readonly property bool wanted: mine && Shell.panel !== ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: wanted || launcher.showing || quick.showing
    WlrLayershell.namespace: "voidline-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Shell.close()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.close()

        Launcher { id: launcher; open: host.mine && Shell.panel === "launcher" }
        QuickSettings { id: quick; open: host.mine && Shell.panel === "quick" }
    }
}
