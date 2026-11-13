import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core

// Optional: drawn only when a wallpaper is set in the config. Otherwise the
// compositor's own background (or another wallpaper tool) stays in charge.
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.surface
    WlrLayershell.namespace: "voidline-wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    Image {
        anchors.fill: parent
        source: "file://" + Config.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: parent.width
        sourceSize.height: parent.height
    }
}
