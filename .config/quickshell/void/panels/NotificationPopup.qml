import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

PanelWindow {
    id: root

    readonly property bool activeForScreen: NotificationService.popupVisible
        && NotificationService.popupNotification !== null
        && screen && screen.name === NotificationService.popupScreenName
    readonly property var notification: activeForScreen
        ? NotificationService.popupNotification : null

    anchors {
        top: true
        right: true
    }
    margins {
        top: Appearance.barPosition === "top" ? Theme.barHeight + 10 : 12
        right: Appearance.barPosition === "right" ? Theme.barHeight + 10 : 12
    }
    implicitWidth: 420
    implicitHeight: 220
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voidline-notification-popup"
    visible: true
    color: "transparent"

    mask: Region {
        x: root.activeForScreen ? 0 : root.width
        y: root.activeForScreen ? Math.max(0, popupCard.y) : 0
        width: root.activeForScreen ? root.width : 0
        height: root.activeForScreen ? popupCard.height : 0
    }

    function iconSource(value) {
        const icon = String(value || "")
        if (icon.length === 0)
            return ""
        if (icon.startsWith("/") || icon.startsWith("file:"))
            return icon.startsWith("file:") ? icon : "file://" + icon
        return "image://icon/" + icon
    }

    Rectangle {
        id: popupCard
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
        }
        height: 188
        y: root.activeForScreen ? 0 : -height - 18
        opacity: root.activeForScreen ? 1 : 0
        scale: root.activeForScreen ? 1 : 0.97
        radius: Theme.radiusExtraLarge
        color: Theme.panel
        border.width: 1
        border.color: Theme.outlineSoft

        Rectangle {
            id: visualAlertRing
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 3
            border.color: Theme.accent
            opacity: 0
            z: 5
        }

        SequentialAnimation {
            running: root.activeForScreen && Appearance.visualAlerts
            loops: 2
            NumberAnimation {
                target: visualAlertRing
                property: "opacity"
                to: 1
                duration: Motion.fast
            }
            NumberAnimation {
                target: visualAlertRing
                property: "opacity"
                to: 0
                duration: Motion.fast
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.activeForScreen ? Motion.enter : Motion.exit
                easing.type: root.activeForScreen ? Motion.enterCurve : Motion.exitCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.activeForScreen ? Motion.enter : Motion.fast
                easing.type: root.activeForScreen ? Motion.enterCurve : Motion.exitCurve
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.activeForScreen ? Motion.enter : Motion.exit
                easing.type: root.activeForScreen ? Motion.enterCurve : Motion.exitCurve
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: Theme.radiusMedium
                    color: Theme.accentContainer

                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: root.notification
                            ? root.iconSource(root.notification.appIcon) : ""
                        sourceSize: Qt.size(32, 32)
                        visible: source.toString().length > 0 && status === Image.Ready
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "notifications"
                        size: 22
                        color: Theme.accent
                        visible: !appIcon.visible
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: root.notification
                            ? (root.notification.appName || "Notification") : ""
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.notification
                            ? (root.notification.summary || "Notification") : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    size: 38
                    icon: "close"
                    accessibleName: I18n.tr("notifications.dismiss")
                    onClicked: NotificationService.dismissPopup()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.notification ? (root.notification.body || "") : ""
                textFormat: Text.PlainText
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: text.length > 0
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 8
                visible: root.notification && root.notification.actions.length > 0

                Item { Layout.fillWidth: true }
                Repeater {
                    model: root.notification
                        ? Math.min(2, root.notification.actions.length) : 0
                    delegate: Rectangle {
                        required property int index
                        readonly property var actionData: root.notification.actions[index]
                        Layout.preferredWidth: actionText.implicitWidth + 24
                        Layout.preferredHeight: 36
                        radius: Theme.radiusMedium
                        color: actionHover.hovered
                            ? Theme.accentContainer : Theme.surfaceHigh
                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: actionData.text
                            color: actionHover.hovered ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                        HoverHandler { id: actionHover }
                        TapHandler {
                            onTapped: NotificationService.invokePopupAction(actionData)
                        }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                }
            }
        }
    }
}
