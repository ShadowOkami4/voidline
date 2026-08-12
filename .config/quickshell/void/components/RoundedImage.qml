import QtQuick
import QtQuick.Effects
import "../core"

Item {
    id: root

    property url source
    property real radius: Theme.radiusLarge
    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize: Qt.size(width * 2, height * 2)
    property string fallbackIcon: "image"
    property color fallbackColor: Theme.surfaceLow
    property real imageScale: 1
    property real imageOffsetX: 0
    property real imageOffsetY: 0
    readonly property int status: image.status

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fallbackColor

        MaterialIcon {
            anchors.centerIn: parent
            text: root.fallbackIcon
            size: Math.min(42, Math.max(22, Math.min(parent.width, parent.height) * 0.2))
            color: Theme.textMuted
            visible: image.status !== Image.Ready
        }
    }

    Item {
        id: clippedImage
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundedMask
        }

        Image {
            id: image
            anchors.fill: parent
            source: root.source
            sourceSize: root.sourceSize
            asynchronous: true
            cache: true
            fillMode: root.fillMode
            smooth: true
            mipmap: true
            scale: root.imageScale
            transform: Translate {
                x: root.imageOffsetX
                y: root.imageOffsetY
            }
        }
    }

    Item {
        id: roundedMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "white"
        }
    }
}
