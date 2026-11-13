import QtQuick
import qs.core

// Expressive spatial animation (position, size, shape). Overshoots slightly.
NumberAnimation {
    duration: Motion.spatialFast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.spatialFastCurve
}
