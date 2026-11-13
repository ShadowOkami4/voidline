import QtQuick
import qs.core

// Effects animation (opacity). Never overshoots.
NumberAnimation {
    duration: Motion.effects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.effectsCurve
}
