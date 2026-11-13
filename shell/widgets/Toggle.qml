import QtQuick
import qs.core

// M3 Expressive switch: the handle grows when on, stretches while pressed and
// carries a check or cross icon.
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
        id: handle
        readonly property int size: area.pressed ? 28 : 24
        width: area.pressed ? size + 6 : size
        height: size
        radius: height / 2
        x: root.checked ? parent.width - width - 4 + (area.pressed ? 2 : 0) : 4 - (area.pressed ? 2 : 0)
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? Theme.inkOnPrimary : Theme.outline
        Behavior on x { Spring {} }
        Behavior on width { Spring {} }
        Behavior on height { Spring {} }
        Behavior on color { Tint {} }

        MIcon {
            anchors.centerIn: parent
            icon: root.checked ? "check" : "close"
            size: 16
            color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
