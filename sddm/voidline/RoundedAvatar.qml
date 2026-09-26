import QtQuick 2.15
import QtGraphicalEffects 1.15

Rectangle {
    id: root

    property string source: ""
    property string fallbackSource: ""
    property string fallbackText: "V"
    property color accent: "#8FB8AC"
    property color foreground: "#F1F5F3"
    property color surface: "#3A8FB8AC"
    property int frameWidth: 4
    // Circular by default, matching the Material 3 Expressive lock screen:
    // an accent ring with a small gap around the image.
    property int cornerRadius: width / 2
    property int ringWidth: Math.max(2, Math.round(width / 36))

    radius: cornerRadius
    color: "transparent"
    border.width: ringWidth
    border.color: accent

    Rectangle {
        anchors {
            fill: parent
            margins: root.frameWidth
        }
        radius: Math.max(0, root.cornerRadius - root.frameWidth)
        color: root.surface
    }

    Item {
        id: imageFrame
        anchors {
            fill: parent
            margins: root.frameWidth
        }

        Image {
            id: fallbackImage
            anchors.fill: parent
            source: root.fallbackSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: false
        }

        Image {
            id: avatarImage
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: false
        }

        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: Math.max(0, root.cornerRadius - root.frameWidth)
            color: "white"
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: fallbackImage
            maskSource: avatarMask
            visible: avatarImage.status !== Image.Ready
                && fallbackImage.status === Image.Ready
        }

        OpacityMask {
            anchors.fill: parent
            source: avatarImage
            maskSource: avatarMask
            visible: avatarImage.status === Image.Ready
        }
    }

    Text {
        anchors.centerIn: parent
        visible: avatarImage.status !== Image.Ready
            && fallbackImage.status !== Image.Ready
        text: root.fallbackText
        color: root.foreground
        font.family: config.fontFamily || "Roboto Flex"
        font.pixelSize: Math.round(root.height * 0.38)
        font.weight: Font.Bold
    }
}
