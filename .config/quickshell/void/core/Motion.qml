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
}
