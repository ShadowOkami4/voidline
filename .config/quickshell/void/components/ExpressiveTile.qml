import QtQuick
import "../core"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool prominent: false
    property bool showChevron: true
    property color containerColor: active ? Theme.accentContainer : Theme.surface
    property color iconColor: active ? Theme.accent : Theme.text
    property color titleColor: active ? Theme.accentContainerInk : Theme.text
    signal clicked

    implicitHeight: prominent ? 116 : 104
    opacity: available ? 1 : 0.48
    scale: tap.pressed ? 0.975 : 1

    Rectangle {
        anchors.fill: parent
        radius: tap.pressed ? Metrics.radiusM
            : (root.prominent || root.active ? Metrics.radiusXL : Metrics.radiusL)
        color: hover.hovered
            ? (root.active ? Qt.tint(root.containerColor, Theme.withAlpha(Theme.accent, 0.08))
                : Theme.surfaceHigh)
            : root.containerColor

        Behavior on radius {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
    }

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            margins: 12
        }
        width: root.prominent ? 44 : 36
        height: width
        // Active icon containers morph from a rounded square into a circle.
        radius: root.active ? width / 2 : Metrics.radiusS
        color: root.active ? root.iconColor : Theme.surfaceHover

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
            size: root.prominent ? 24 : 20
            fill: root.active ? 1 : 0
            color: root.active ? Theme.accentInk : root.iconColor
        }
    }

    MaterialIcon {
        visible: root.showChevron
        anchors {
            top: parent.top
            right: parent.right
            margins: 14
        }
        text: "arrow_outward"
        size: 18
        color: Theme.textMuted
    }

    Text {
        anchors {
            left: parent.left
            right: parent.right
            bottom: subtitleText.top
            leftMargin: 14
            rightMargin: 10
            bottomMargin: 1
        }
        text: root.title
        color: root.titleColor
        font.family: Theme.fontFamily
        font.pixelSize: root.prominent ? 15 : 13
        font.weight: Font.Bold
        elide: Text.ElideRight
    }

    Text {
        id: subtitleText
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 14
            rightMargin: 10
            bottomMargin: 10
        }
        text: root.subtitle
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    HoverHandler { id: hover }

    TapHandler {
        id: tap
        enabled: root.available
        onTapped: root.clicked()
    }

    Behavior on scale {
        NumberAnimation {
            duration: Motion.springFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialFast
        }
    }
}
