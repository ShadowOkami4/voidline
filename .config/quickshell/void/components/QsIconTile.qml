import QtQuick
import "../core"

// Compact icon-only Quick Settings tile; becomes a filled pill when active.
Rectangle {
    id: root

    property string icon: ""
    property string accessibleName: ""
    property bool active: false
    property bool available: true
    signal clicked

    implicitWidth: Math.round(76 * Metrics.scale)
    implicitHeight: Math.round(64 * Metrics.scale)
    opacity: available ? 1 : 0.4
    radius: tap.pressed ? Metrics.radiusS : (active ? height / 2 : Math.round(22 * Metrics.scale))
    color: active ? (hover.hovered ? Theme.accentStrong : Theme.accent)
        : (hover.hovered ? Theme.surfaceHover : Theme.surfaceContainerHighest)

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.checked: active

    Behavior on radius {
        NumberAnimation {
            duration: Motion.springFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialFast
        }
    }
    Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        size: Math.round(24 * Metrics.scale)
        fill: root.active ? 1 : 0
        color: root.active ? Theme.accentInk : Theme.text
    }

    HoverHandler {
        id: hover
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        enabled: root.available
        onTapped: root.clicked()
    }
}
