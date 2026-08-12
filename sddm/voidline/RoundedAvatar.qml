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
    property int cornerRadius: 30

    radius: cornerRadius
    color: surface
    border.width: 1
    border.color: accent

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
