import QtQuick 2.15

// Material 3 Expressive button for the login screen. Buttons are pills that
// tighten their corners while pressed (shape morph). Variants:
//   primary      filled with the accent colour
//   destructive  error container
//   flat         text button without a container
//   default      tonal container
Rectangle {
    id: root

    property string label: ""
    property string symbol: ""
    property bool primary: false
    property bool destructive: false
    property bool flat: false
    property bool selected: false
    property bool enabled: true
    property int cornerRadius: height / 2
    property int pressedRadius: Math.min(height / 2, 10)
    property color accent: "#8FB8AC"
    property color accentInk: "#0F2622"
    property color foreground: "#F1F5F3"
    property color muted: "#B8C4C0"
    property color surface: "#302D34"
    property color selectedSurface: "#334D48"
    property color danger: "#FFB4AB"
    property color dangerContainer: "#93000A"
    property color dangerInk: "#FFDAD6"
    // Retained for callers written against the previous outlined style.
    property color outline: "transparent"

    readonly property bool hovered: mouse.containsMouse || activeFocus
    readonly property color content: primary ? accentInk
        : (destructive ? dangerInk : (flat ? accent : foreground))

    signal clicked()

    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.38
    radius: mouse.pressed ? pressedRadius : cornerRadius
    color: {
        if (primary)
            return hovered ? Qt.lighter(accent, 1.08) : accent
        if (destructive)
            return hovered ? Qt.lighter(dangerContainer, 1.18) : dangerContainer
        if (flat)
            return hovered ? Qt.rgba(accent.r, accent.g, accent.b, 0.12) : "transparent"
        if (selected)
            return selectedSurface
        return hovered ? Qt.lighter(surface, 1.22) : surface
    }
    border.width: activeFocus ? 2 : 0
    border.color: primary ? foreground : (destructive ? dangerInk : accent)

    Row {
        anchors.centerIn: parent
        spacing: root.symbol.length > 0 && root.label.length > 0 ? 8 : 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.symbol.length > 0
            text: root.symbol
            color: root.content
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label.length > 0
            text: root.label
            color: root.content
            font.family: config.fontFamily || "Roboto Flex"
            font.pixelSize: 14
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

    // Spatial spring for the shape morph; effects curve for colour.
    Behavior on radius {
        NumberAnimation {
            duration: 350
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.42, 1.67, 0.21, 0.9, 1, 1]
        }
    }
    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
}
