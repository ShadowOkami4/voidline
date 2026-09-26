import QtQuick
import QtQuick.Layouts
import "../core"

// Android 16 Quick Settings tile. The round icon toggles the feature; the
// rest of the tile opens its detail page when `hasDetails` is set. Active
// tiles fill with the accent colour and become fully rounded.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool hasDetails: false
    signal toggled
    signal opened

    readonly property bool pressed: iconTap.pressed || bodyTap.pressed

    implicitHeight: Math.round(76 * Metrics.scale)
    opacity: available ? 1 : 0.4
    radius: pressed ? Metrics.radiusM : (active ? height / 2 : Metrics.radiusXL)
    color: active
        ? (bodyHover.hovered ? Theme.accentStrong : Theme.accent)
        : (bodyHover.hovered ? Theme.surfaceHover : Theme.surfaceContainerHighest)

    Behavior on radius {
        NumberAnimation {
            duration: Motion.springFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialFast
        }
    }
    Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.checked: active

    TapHandler {
        id: bodyTap
        enabled: root.available
        onTapped: root.hasDetails ? root.opened() : root.toggled()
    }
    HoverHandler {
        id: bodyHover
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Math.round(10 * Metrics.scale)
            rightMargin: Metrics.spaceL
        }
        spacing: Metrics.spaceM

        Rectangle {
            Layout.preferredWidth: Math.round(56 * Metrics.scale)
            Layout.preferredHeight: Layout.preferredWidth
            radius: iconTap.pressed ? Metrics.radiusM : width / 2
            color: root.active ? Qt.darker(Theme.accent, Theme.darkMode ? 1.12 : 1.08)
                : Theme.surfaceBright

            Behavior on radius {
                NumberAnimation {
                    duration: Motion.springFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialFast
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                size: Math.round(24 * Metrics.scale)
                fill: root.active ? 1 : 0
                color: root.active ? Theme.accentInk : Theme.text
            }

            TapHandler {
                id: iconTap
                enabled: root.available
                onTapped: root.toggled()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.active ? Theme.accentInk : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(15 * Metrics.scale)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                color: root.active ? Theme.accentInk : Theme.textMuted
                opacity: root.active ? 0.8 : 1
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(12 * Metrics.scale)
                elide: Text.ElideRight
            }
        }

        MaterialIcon {
            visible: root.hasDetails
            text: "chevron_right"
            size: Math.round(20 * Metrics.scale)
            color: root.active ? Theme.accentInk : Theme.textMuted
        }
    }
}
