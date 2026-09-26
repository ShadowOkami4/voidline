pragma Singleton

import Quickshell
import QtQuick

QtObject {
    readonly property real durationScale: Appearance.animationDurationScale
    // Motion is interaction-driven. Nothing loops while the shell is idle.
    readonly property int instant: Appearance.reduceMotion ? 1 : Math.round(90 * durationScale)
    readonly property int fast: Appearance.reduceMotion ? 1 : Math.round(140 * durationScale)
    readonly property int enter: Appearance.reduceMotion ? 1 : Math.round(280 * durationScale)
    readonly property int exit: Appearance.reduceMotion ? 1 : Math.round(220 * durationScale)
    readonly property int panelEnter: Appearance.reduceMotion ? 1 : Math.round(420 * durationScale)
    readonly property int panelExit: Appearance.reduceMotion ? 1 : Math.round(340 * durationScale)
    readonly property int morphEnter: panelEnter
    readonly property int morphExit: panelExit
    readonly property int contentDelay: Appearance.reduceMotion ? 1 : Math.round(85 * durationScale)
    readonly property int pageEnter: Appearance.reduceMotion ? 1 : Math.round(280 * durationScale)
    readonly property int pageExit: Appearance.reduceMotion ? 1 : Math.round(210 * durationScale)
    readonly property int panelResize: Appearance.reduceMotion ? 1 : Math.round(340 * durationScale)
    readonly property int selectionSlide: Appearance.reduceMotion ? 1 : Math.round(320 * durationScale)
    readonly property int selectionPulse: Appearance.reduceMotion ? 1 : Math.round(260 * durationScale)
    readonly property int launcherMorph: Appearance.reduceMotion ? 1 : Math.round(320 * durationScale)
    readonly property int launcherContentDelay: Appearance.reduceMotion ? 1 : Math.round(75 * durationScale)
    readonly property int launcherContent: Appearance.reduceMotion ? 1 : Math.round(180 * durationScale)
    readonly property int listStagger: Appearance.reduceMotion ? 0 : Math.round(28 * durationScale)
    readonly property int hover: Appearance.reduceMotion ? 1 : Math.round(120 * durationScale)
    readonly property int dialogEnter: Appearance.reduceMotion ? 1 : Math.round(260 * durationScale)
    readonly property int dialogExit: Appearance.reduceMotion ? 1 : Math.round(180 * durationScale)
    readonly property int notificationEnter: Appearance.reduceMotion ? 1 : Math.round(320 * durationScale)
    readonly property int notificationExit: Appearance.reduceMotion ? 1 : Math.round(220 * durationScale)
    readonly property int drawerEnter: Appearance.reduceMotion ? 1 : Math.round(300 * durationScale)
    readonly property int drawerExit: Appearance.reduceMotion ? 1 : Math.round(190 * durationScale)
    readonly property int drawerRevealEnter: Appearance.reduceMotion ? 1 : Math.round(360 * durationScale)
    readonly property int drawerRevealExit: Appearance.reduceMotion ? 1 : Math.round(170 * durationScale)
    readonly property int barRelocateOut: Appearance.reduceMotion ? 1 : Math.round(125 * durationScale)
    readonly property int barRelocateIn: Appearance.reduceMotion ? 1 : Math.round(180 * durationScale)
    readonly property int hoverCloseDelay: Appearance.reduceMotion ? 1 : Math.round(420 * durationScale)
    readonly property int actionCommitDelay: Appearance.reduceMotion ? 1 : Math.round(230 * durationScale)
    readonly property int spinner: Appearance.reduceMotion ? 1 : Math.round(900 * durationScale)

    readonly property int standardCurve: Easing.OutCubic
    readonly property int enterCurve: Easing.OutQuart
    readonly property int exitCurve: Easing.InCubic
    readonly property int morphCurve: Easing.InOutCubic
    readonly property int pageCurve: Easing.OutQuint
    readonly property int pageExitCurve: Easing.InQuint
    readonly property int expressiveCurve: Easing.OutBack

    // Material 3 Expressive motion scheme. Spatial springs (position, size,
    // shape) overshoot slightly; effects springs (colour, opacity) never do.
    // Use with `easing.type: Easing.BezierSpline` and `easing.bezierCurve`.
    // With Reduce Motion, spatial curves fall back to the non-bouncy form.
    readonly property var spatialFast: Appearance.reduceMotion
        ? effectsFast : [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var spatialDefault: Appearance.reduceMotion
        ? effectsDefault : [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var spatialSlow: Appearance.reduceMotion
        ? effectsDefault : [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var effectsFast: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var effectsDefault: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var emphasizedDecelerate: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var emphasizedAccelerate: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property int springFast: Appearance.reduceMotion ? 1 : Math.round(350 * durationScale)
    readonly property int springDefault: Appearance.reduceMotion ? 1 : Math.round(500 * durationScale)
    readonly property int springSlow: Appearance.reduceMotion ? 1 : Math.round(650 * durationScale)
    readonly property int effectsFastDuration: Appearance.reduceMotion ? 1 : Math.round(150 * durationScale)
}
