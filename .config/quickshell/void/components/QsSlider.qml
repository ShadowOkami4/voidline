import QtQuick
import "../core"

// Android 16 thick slider: the icon sits inside the active track, a narrow
// handle separates it from the inactive track. Clicking the icon end calls
// iconClicked (for example to mute).
Item {
    id: root

    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool available: true
    property bool iconInteractive: false
    signal moved(real value)
    signal iconClicked

    readonly property real shown: muted ? 0 : Math.max(0, Math.min(1, value))
    readonly property real minimumActive: height
    readonly property real handleX: minimumActive + (width - minimumActive - 8) * visual

    property real visual: shown
    Behavior on visual {
        enabled: !drag.pressed
        NumberAnimation {
            duration: Motion.springFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialFast
        }
    }

    implicitHeight: Math.round(44 * Metrics.scale)
    opacity: available ? 1 : 0.4

    function update(x) {
        const span = Math.max(1, width - minimumActive - 8)
        moved(Math.max(0, Math.min(1, (x - minimumActive) / span)))
    }

    Rectangle {
        id: activeTrack
        x: 0
        width: Math.max(root.minimumActive, root.handleX - 4)
        height: parent.height
        topLeftRadius: height / 2
        bottomLeftRadius: height / 2
        topRightRadius: Math.min(Metrics.pressedRadius, width / 2)
        bottomRightRadius: topRightRadius
        color: root.muted ? Theme.surfaceHover : Theme.accent

        MaterialIcon {
            anchors {
                left: parent.left
                leftMargin: Math.round(13 * Metrics.scale)
                verticalCenter: parent.verticalCenter
            }
            text: root.icon
            size: Math.round(21 * Metrics.scale)
            fill: 1
            color: root.muted ? Theme.textMuted : Theme.accentInk
        }
    }

    Rectangle {
        x: root.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: drag.pressed ? 2 : 4
        height: parent.height + Math.round(8 * Metrics.scale)
        radius: width / 2
        color: root.muted ? Theme.textMuted : Theme.accent
    }

    Rectangle {
        x: root.handleX + 4
        width: Math.max(0, parent.width - x)
        height: parent.height
        topRightRadius: height / 2
        bottomRightRadius: height / 2
        topLeftRadius: Math.min(Metrics.pressedRadius, width / 2)
        bottomLeftRadius: topLeftRadius
        color: Theme.surfaceContainerHighest

        Rectangle {
            anchors {
                right: parent.right
                rightMargin: Math.round(20 * Metrics.scale)
                verticalCenter: parent.verticalCenter
            }
            visible: parent.width > 40
            width: 6
            height: 6
            radius: 3
            color: Theme.accent
        }
    }

    MouseArea {
        id: drag
        // True when the press started on the icon end of an interactive
        // slider; that press toggles (mute) instead of seeking.
        property bool iconPress: false
        anchors.fill: parent
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            iconPress = root.iconInteractive && mouse.x < root.minimumActive
            if (!iconPress)
                root.update(mouse.x)
        }
        onPositionChanged: mouse => {
            if (pressed && !iconPress)
                root.update(mouse.x)
        }
        onClicked: {
            if (iconPress)
                root.iconClicked()
        }
    }
    WheelHandler {
        enabled: root.available
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
