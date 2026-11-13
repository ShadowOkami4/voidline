pragma Singleton

import Quickshell
import QtQuick

// Material 3 Expressive motion scheme. "Spatial" curves overshoot slightly and
// are used for position/size/shape; "effects" curves never overshoot and are
// used for colour and opacity.
Singleton {
    readonly property real scale: Config.reduceMotion ? 0.001 : 1

    readonly property int spatialFast: Math.max(1, 350 * scale)
    readonly property int spatial: Math.max(1, 500 * scale)
    readonly property int spatialSlow: Math.max(1, 650 * scale)
    readonly property int effectsFast: Math.max(1, 150 * scale)
    readonly property int effects: Math.max(1, 200 * scale)
    readonly property int effectsSlow: Math.max(1, 300 * scale)

    readonly property var spatialFastCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1.00, 1, 1]
    readonly property var spatialSlowCurve: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var effectsFastCurve: [0.31, 0.94, 0.34, 1.00, 1, 1]
    readonly property var effectsCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
    readonly property var effectsSlowCurve: [0.34, 0.88, 0.34, 1.00, 1, 1]
}
