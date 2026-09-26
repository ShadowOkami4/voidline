import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    signal clicked

    implicitWidth: 112
    implicitHeight: 82
    opacity: available ? 1 : 0.45
    scale: tap.pressed ? 0.97 : 1

    // Material 3 Expressive shape morph: inactive tiles are rounded squares,
    // active tiles become filled pills, and a press tightens the corners.
    Rectangle {
        anchors.fill: parent
        radius: tap.pressed ? Metrics.radiusM
            : (root.active ? height / 2 : Metrics.tileRadius)
        color: root.active
            ? (hover.hovered ? Theme.accentStrong : Theme.accent)
            : (hover.hovered ? Theme.surfaceHover : Theme.surface)

        Behavior on radius {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 5

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            size: 25
            fill: root.active ? 1 : 0
            color: root.active ? Theme.accentInk : Theme.text
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: root.active ? Theme.accentInk : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.subtitle
            color: root.active ? Theme.accentInk : Theme.textMuted
            opacity: root.active ? 0.8 : 1
            font.family: Theme.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
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
