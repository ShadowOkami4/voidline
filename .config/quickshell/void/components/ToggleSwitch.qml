import QtQuick
import "../core"

// Material 3 Expressive switch: an outlined track whose handle grows from a
// small dot (off) to a full handle with a check glyph (on), squeezes wider
// while pressed, and travels on a spatial spring.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool showIcons: true
    signal toggled(bool checked)

    readonly property real trackWidth: Math.round(52 * Metrics.scale)
    readonly property real trackHeight: Math.round(32 * Metrics.scale)
    readonly property bool pressed: tap.pressed
    readonly property real handleSize: Math.round(
        (pressed ? 28 : (checked ? 24 : 16)) * Metrics.scale)

    implicitWidth: trackWidth
    implicitHeight: trackHeight
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.38

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: root.trackWidth
        height: root.trackHeight
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHigh
        border.width: root.checked ? 0 : Math.max(2, Math.round(2 * Metrics.scale))
        border.color: Theme.outline

        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
    }

    // State layer halo around the handle on hover/focus/press.
    Rectangle {
        width: Math.round(40 * Metrics.scale)
        height: width
        radius: width / 2
        x: handle.x + handle.width / 2 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? Theme.accent : Theme.text
        opacity: !root.enabled ? 0
            : (root.pressed ? 0.12 : ((hover.hovered || root.activeFocus) ? 0.08 : 0))

        Behavior on opacity { NumberAnimation { duration: Motion.effectsFastDuration } }
    }

    Rectangle {
        id: handle
        width: root.handleSize
        height: root.handleSize
        radius: height / 2
        x: root.checked ? track.x + track.width - width - (root.trackHeight - height) / 2
            : track.x + (root.trackHeight - height) / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked
            ? (root.pressed || hover.hovered ? Theme.accentContainerInk : Theme.accentInk)
            : (root.pressed || hover.hovered ? Theme.textMuted : Theme.outline)

        Behavior on x {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

        MaterialIcon {
            anchors.centerIn: parent
            visible: root.showIcons
            opacity: root.checked ? 1 : 0
            scale: root.checked ? 1 : 0.4
            text: "check"
            fill: 1
            size: Math.round(16 * Metrics.scale)
            color: Theme.accent

            Behavior on opacity { NumberAnimation { duration: Motion.effectsFastDuration } }
            Behavior on scale {
                NumberAnimation {
                    duration: Motion.springFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialFast
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: track
        width: track.width + Metrics.focusBorder * 4
        height: track.height + Metrics.focusBorder * 4
        radius: height / 2
        color: "transparent"
        visible: root.activeFocus && Appearance.focusIndicators
        border.width: Metrics.focusBorder
        border.color: Theme.secondary
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.toggled(!root.checked)
    }
    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    Keys.onSpacePressed: if (root.enabled) root.toggled(!root.checked)
    Keys.onEnterPressed: if (root.enabled) root.toggled(!root.checked)
    Keys.onReturnPressed: if (root.enabled) root.toggled(!root.checked)
}
