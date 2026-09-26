import QtQuick
import "../core"

Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property bool enabled: true
    property bool muted: false
    property bool iconInteractive: true
    property string title: ""
    property string subtitle: ""
    property string valueText: Math.round(normalized * 100) + "%"
    property string icon: "volume_up"
    property color containerColor: "transparent"
    property color activeColor: Theme.accent
    // Retained as public styling hooks for existing page declarations.
    property color leadingColor: Theme.surfaceHigh
    property color leadingIconColor: muted ? Theme.textMuted : activeColor
    signal moved(real value)
    signal iconClicked

    readonly property real normalized: Math.max(0, Math.min(1,
        (value - from) / Math.max(0.001, to - from)))
    readonly property real displayedValue: muted ? 0 : normalized

    implicitHeight: Metrics.sliderHeight
    opacity: enabled ? 1 : 0.42

    function updateAt(position) {
        const span = Math.max(1, track.width - track.edgeInset * 2)
        const fraction = Math.max(0, Math.min(1, (position - track.edgeInset) / span))
        moved(from + fraction * (to - from))
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: root.containerColor

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MaterialIcon {
        id: leadingIcon
        anchors {
            left: parent.left
            leftMargin: Metrics.contentInset
            top: parent.top
            topMargin: Metrics.spaceM
        }
        text: root.icon
        size: iconArea.pressed ? Metrics.iconM : Metrics.iconL
        color: root.muted ? Theme.textMuted : root.leadingIconColor

        Behavior on size { NumberAnimation { duration: Motion.instant } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: Metrics.contentInset + Metrics.iconL + Metrics.spaceS
            top: parent.top
            topMargin: Metrics.spaceS
            right: valueLabel.left
            rightMargin: Metrics.spaceM
        }
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.textTitle
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: Metrics.contentInset + Metrics.iconL + Metrics.spaceS
            top: parent.top
            topMargin: Metrics.spaceS + Metrics.textTitle + Metrics.titleSubtitleGap
            right: parent.right
            rightMargin: Metrics.contentInset
        }
        text: root.subtitle
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.textCaption
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    Text {
        id: valueLabel
        anchors {
            top: parent.top
            topMargin: Metrics.spaceS
            right: parent.right
            rightMargin: Metrics.contentInset
        }
        text: root.valueText
        color: root.muted ? Theme.textMuted : root.activeColor
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.textSupporting
        font.weight: Font.Bold

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Item {
        id: track
        anchors {
            left: parent.left
            leftMargin: Metrics.contentInset
            right: parent.right
            rightMargin: Metrics.contentInset
            bottom: parent.bottom
            bottomMargin: Metrics.spaceS
        }
        height: Math.round(32 * Metrics.scale)
        clip: true

        readonly property real edgeInset: 2.5
        readonly property real gapSize: Math.round(6 * Metrics.scale)
        property real barHeight: Math.round((dragArea.pressed ? 20 : 16) * Metrics.scale)
        readonly property real innerRadius: Math.max(2, Math.round(2 * Metrics.scale))

        Behavior on barHeight {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        readonly property real thumbCenter: edgeInset
            + Math.max(0, width - edgeInset * 2) * activeSegment.visualValue

        Rectangle {
            id: activeSegment
            property real visualValue: root.displayedValue

            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: Math.max(0, track.thumbCenter - track.gapSize)
            height: track.barHeight
            // M3 Expressive track: round outer end, tight corners at the handle.
            topLeftRadius: Math.min(height / 2, width / 2)
            bottomLeftRadius: topLeftRadius
            topRightRadius: Math.min(track.innerRadius, width / 2)
            bottomRightRadius: topRightRadius
            color: root.activeColor

            Behavior on visualValue {
                enabled: !dragArea.pressed
                NumberAnimation { duration: Motion.fast; easing.type: Motion.standardCurve }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.min(parent.width, track.thumbCenter + track.gapSize)
            width: Math.max(0, parent.width - x)
            height: track.barHeight
            topLeftRadius: Math.min(track.innerRadius, width / 2)
            bottomLeftRadius: topLeftRadius
            topRightRadius: Math.min(height / 2, width / 2)
            bottomRightRadius: topRightRadius
            color: Theme.withAlpha(root.activeColor, Theme.darkMode ? 0.22 : 0.26)

        }

        Rectangle {
            anchors {
                right: parent.right
                rightMargin: Math.round(6 * Metrics.scale)
                verticalCenter: parent.verticalCenter
            }
            width: Math.round(4 * Metrics.scale)
            height: width
            radius: width / 2
            visible: activeSegment.visualValue < 0.96
            color: root.activeColor
        }

        Rectangle {
            id: handle
            x: track.thumbCenter - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: dragArea.pressed ? 2 : 4
            height: Math.round(30 * Metrics.scale)
            radius: width / 2
            color: root.muted ? Theme.textMuted : root.activeColor

            Behavior on width {
                NumberAnimation {
                    duration: Motion.springFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialFast
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    MouseArea {
        id: iconArea
        anchors {
            left: parent.left
            top: parent.top
        }
        width: 44
        height: 42
        enabled: root.enabled && root.iconInteractive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.iconClicked()
    }

    MouseArea {
        id: dragArea
        anchors {
            left: track.left
            right: track.right
            top: parent.top
            topMargin: 38
            bottom: parent.bottom
        }
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.updateAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.updateAt(mouse.x)
        }
    }
}
