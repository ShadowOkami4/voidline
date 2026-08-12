import QtQuick
import "../core"

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    signal toggled(bool checked)

    implicitWidth: 58
    implicitHeight: 34
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHover
        border.width: root.activeFocus ? Metrics.focusBorder : Metrics.border
        border.color: root.activeFocus ? Theme.secondary
            : (root.checked ? Theme.accentStrong : Theme.outline)

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    Rectangle {
        width: 24
        height: 24
        radius: 12
        x: root.checked ? root.width - width - 5 : 5
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? Theme.accentInk : Theme.textMuted
        scale: tap.pressed ? 0.88 : 1

        Behavior on x {
            NumberAnimation { duration: Motion.fast; easing.type: Motion.enterCurve }
        }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.instant } }
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.toggled(!root.checked)
    }
    HoverHandler { id: hover }
    Keys.onSpacePressed: if (root.enabled) root.toggled(!root.checked)
    Keys.onEnterPressed: if (root.enabled) root.toggled(!root.checked)
    Keys.onReturnPressed: if (root.enabled) root.toggled(!root.checked)
}
