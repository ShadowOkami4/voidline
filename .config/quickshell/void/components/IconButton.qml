import QtQuick
import "../core"

// Material 3 Expressive icon button. It is round at rest, morphs to a rounded
// square while selected, and tightens further while pressed. Selected buttons
// use a tonal container and the filled glyph.
Item {
    id: root

    property string icon: ""
    property string accessibleName: ""
    property bool active: false
    property int size: 34
    signal clicked

    readonly property bool pressed: tap.pressed

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.38
    activeFocusOnTab: enabled

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName.length > 0 ? accessibleName : icon
    Accessible.onPressAction: root.clicked()

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: root.pressed ? parent.width * 1.08 : parent.width
        height: parent.height
        radius: root.pressed ? Math.min(height / 2, Metrics.pressedRadius)
            : (root.active ? Math.min(height / 2, Metrics.radiusM * 0.75) : height / 2)
        color: root.active ? Theme.accentContainer
            : (hover.hovered || root.activeFocus ? Theme.surfaceHover : "transparent")

        Behavior on radius {
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
        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        size: Math.round(root.size * 0.56)
        fill: root.active ? 1 : 0
        color: root.active ? Theme.accentContainerInk : Theme.textMuted

        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
    }

    Rectangle {
        anchors.fill: container
        anchors.margins: -Metrics.focusBorder * 1.5
        radius: container.radius + Metrics.focusBorder
        color: "transparent"
        visible: root.activeFocus && Appearance.focusIndicators
        border.width: Metrics.focusBorder
        border.color: Theme.secondary
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
    Keys.onSpacePressed: if (root.enabled) root.clicked()
    Keys.onReturnPressed: if (root.enabled) root.clicked()
}
