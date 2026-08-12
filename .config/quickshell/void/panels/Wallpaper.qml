import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"
import "../services"

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "voidline-wallpaper"
    color: Theme.background

    Image {
        anchors.fill: parent
        source: WallpaperService.currentPath.length > 0
            ? "file://" + WallpaperService.currentPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }
}
