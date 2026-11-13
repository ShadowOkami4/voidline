import QtQuick
import qs.core

// M3 switch. The handle grows when on and stretches while pressed.
Item {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline
        Behavior on color { Tint {} }
    }

    Rectangle {
        readonly property int size: area.pressed ? 28 : (root.checked ? 24 : 16)
        width: area.pressed ? size + 4 : size
        height: size
        radius: height / 2
        x: root.checked ? parent.width - width - (32 - size) / 2 : (32 - size) / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? Theme.inkOnPrimary : Theme.outline
        Behavior on x { Spring {} }
        Behavior on width { Spring {} }
        Behavior on height { Spring {} }
        Behavior on color { Tint {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
