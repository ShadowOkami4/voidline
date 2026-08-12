import Quickshell
import QtQuick
import "../core"

Item {
    id: root

    property url source
    property int sourcePixelSize: Math.max(width, height) * 2
    readonly property bool usingFallback: appImage.status !== Image.Ready

    Image {
        id: appImage
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.sourcePixelSize, root.sourcePixelSize)
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Theme.radiusMedium, width * 0.28)
        color: Theme.accentContainer
        border.width: 1
        border.color: Theme.withAlpha(Theme.accent, 0.34)
        visible: root.usingFallback

        Image {
            id: defaultApplicationIcon
            anchors {
                fill: parent
                margins: Math.max(5, parent.width * 0.14)
            }
            source: Quickshell.hasThemeIcon("application-default-icon")
                ? Quickshell.iconPath("application-default-icon") : ""
            sourceSize: Qt.size(root.sourcePixelSize, root.sourcePixelSize)
            smooth: true
            mipmap: true
            visible: status === Image.Ready
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "apps"
            size: Math.max(17, Math.min(parent.width, parent.height) * 0.52)
            color: Theme.accent
            visible: !defaultApplicationIcon.visible
        }
    }
}
