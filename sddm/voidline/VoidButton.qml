import QtQuick 2.15

Rectangle {
    id: root

    property string label: ""
    property string symbol: ""
    property bool primary: false
    property bool destructive: false
    property bool enabled: true
    property int cornerRadius: 16
    property color accent: "#8FB8AC"
    property color foreground: "#F1F5F3"
    property color muted: "#B8C4C0"
    property color surface: "#D925302F"
    property color outline: "#5272817C"

    signal clicked()

    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.42
    radius: cornerRadius
    color: {
        if (primary)
            return mouse.pressed ? Qt.darker(accent, 1.10)
                : (mouse.containsMouse || activeFocus
                    ? Qt.lighter(accent, 1.05) : accent)
        if (destructive && (mouse.containsMouse || activeFocus))
            return "#5CD56562"
        return mouse.pressed ? "#688FB8AC"
            : (mouse.containsMouse || activeFocus ? "#5272817C" : surface)
    }
    border.width: primary ? 0 : 1
    border.color: destructive && (mouse.containsMouse || activeFocus)
        ? "#D56562" : outline

    Row {
        anchors.centerIn: parent
        spacing: root.symbol.length > 0 && root.label.length > 0 ? 8 : 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.symbol.length > 0
            text: root.symbol
            color: root.primary ? "#14201E" : root.foreground
            font.family: "Material Symbols Rounded"
            font.pixelSize: 19
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label.length > 0
            text: root.label
            color: root.primary ? "#14201E" : root.foreground
            font.family: config.fontFamily || "Roboto Flex"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus()
            root.clicked()
        }
    }

    Keys.onSpacePressed: {
        if (enabled)
            clicked()
    }
    Keys.onReturnPressed: {
        if (enabled)
            clicked()
    }
    Keys.onEnterPressed: {
        if (enabled)
            clicked()
    }

    Behavior on color {
        ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
}
