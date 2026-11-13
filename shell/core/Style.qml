pragma Singleton

import Quickshell
import QtQuick

// A style is a layout preset, not a colour theme. Every surface reads its
// geometry from here, so adding a style means adding one branch per property
// (and, if it needs a new bar arrangement, one layout file in bar/).
Singleton {
    readonly property string name: Config.style
    readonly property bool voidline: name === "voidline"
    readonly property bool windows: name === "windows"
    readonly property bool macos: name === "macos"

    // Bar
    readonly property string barEdge: windows ? "bottom" : "top"
    readonly property int barHeight: windows ? 52 : (macos ? 34 : 44)
    readonly property color barColor: macos ? Theme.alpha(Theme.surface, 0.78) : Theme.surfaceContainerLow

    // Voidline: the bar continues into a thin frame around the screen and
    // panels grow out of it, joined with concave curves.
    readonly property bool framed: voidline
    readonly property int frameWidth: framed ? 6 : 0
    readonly property int frameRadius: 22
    readonly property bool attachedPanels: voidline

    // macOS: floating dock at the bottom.
    readonly property bool dock: macos
    readonly property int dockHeight: 68

    // Where panels open: "top-center" | "top-right" | "bottom-center" |
    // "bottom-right" | "center"
    readonly property string launcherAnchor: voidline ? "top-center" : (windows ? "bottom-center" : "center")
    readonly property string quickAnchor: windows ? "bottom-right" : "top-right"
    readonly property string notificationAnchor: windows ? "bottom-right" : "top-right"
    readonly property int panelGap: 10
}
