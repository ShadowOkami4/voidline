import QtQuick
import qs.core

ColorAnimation {
    duration: Motion.effects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.effectsCurve
}
