import QtQuick
import QtQuick.Layouts
import "../core"

// One segment of the notification stack: round app icon, app name, title,
// body, up to two actions, and a dismiss button. Neighbouring cards share
// tight corners; the stack's ends are fully rounded.
Rectangle {
    id: root

    property var notification: null
    property bool first: false
    property bool last: false
    signal dismissed
    signal actionInvoked(var action)

    readonly property var actions: notification && notification.actions
        ? notification.actions : []

    implicitHeight: content.implicitHeight + Metrics.spaceL * 2
    color: hover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    topLeftRadius: first ? Metrics.radiusXL : Math.round(6 * Metrics.scale)
    topRightRadius: topLeftRadius
    bottomLeftRadius: last ? Metrics.radiusXL : Math.round(6 * Metrics.scale)
    bottomRightRadius: bottomLeftRadius

    Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
    HoverHandler { id: hover }

    function iconSource(value) {
        const icon = String(value || "")
        if (icon.length === 0)
            return ""
        if (icon.startsWith("/") || icon.startsWith("file:"))
            return icon.startsWith("file:") ? icon : "file://" + icon
        return "image://icon/" + icon
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Metrics.spaceL
        }
        spacing: Metrics.spaceM

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Math.round(40 * Metrics.scale)
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: Theme.accentContainer

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: Math.round(24 * Metrics.scale)
                height: width
                source: root.notification ? root.iconSource(root.notification.appIcon) : ""
                sourceSize: Qt.size(48, 48)
                visible: status === Image.Ready
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: "notifications"
                size: Math.round(22 * Metrics.scale)
                fill: 1
                color: Theme.accentContainerInk
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spaceXS

                Text {
                    Layout.fillWidth: true
                    text: root.notification ? (root.notification.appName || "") : ""
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(12 * Metrics.scale)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: Math.round(32 * Metrics.scale)
                    height: Math.round(24 * Metrics.scale)
                    radius: height / 2
                    color: closeHover.hovered ? Theme.surfaceBright : Theme.surfaceContainerHighest
                    Accessible.role: Accessible.Button
                    Accessible.name: I18n.tr("notifications.dismiss")

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        size: Math.round(16 * Metrics.scale)
                    }
                    HoverHandler {
                        id: closeHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler { onTapped: root.dismissed() }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notification
                    ? (root.notification.summary || I18n.tr("notifications.notification")) : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(15 * Metrics.scale)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.notification ? (root.notification.body || "") : ""
                textFormat: Text.PlainText
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(13 * Metrics.scale)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Row {
                visible: root.actions.length > 0
                Layout.topMargin: Metrics.spaceS
                spacing: Metrics.spaceS

                Repeater {
                    model: Math.min(2, root.actions.length)

                    Rectangle {
                        required property int index
                        readonly property var action: root.actions[index]
                        width: actionLabel.implicitWidth + Math.round(32 * Metrics.scale)
                        height: Math.round(36 * Metrics.scale)
                        radius: actionTap.pressed ? Metrics.pressedRadius : height / 2
                        color: index === 0 ? Theme.accent : Theme.surfaceContainerHighest

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.action ? parent.action.text : ""
                            color: parent.index === 0 ? Theme.accentInk : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(13 * Metrics.scale)
                            font.weight: Font.DemiBold
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: actionTap
                            onTapped: root.actionInvoked(parent.action)
                        }
                    }
                }
            }
        }
    }
}
