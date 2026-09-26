import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool vertical: false

    implicitWidth: vertical ? 24 : indicatorRow.implicitWidth + 12
    implicitHeight: vertical ? indicatorColumn.implicitHeight + 12 : 24

    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 6
        visible: !root.vertical

        Repeater {
            model: 5
            Rectangle {
                required property int index
                readonly property bool activeWorkspace: Hyprland.focusedWorkspace !== null
                    && Hyprland.focusedWorkspace.id === index + 1
                // M3 Expressive: the focused workspace stretches into a pill.
                Layout.preferredWidth: activeWorkspace ? 24 : 8
                Layout.preferredHeight: 8
                radius: 4
                color: activeWorkspace ? Theme.accent
                    : (workspaceHover.hovered ? Theme.text : Theme.outline)
                HoverHandler { id: workspaceHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: Hyprland.dispatch('hl.dsp.focus({ workspace = "'
                        + (index + 1) + '" })')
                }
                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                    duration: Motion.springFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialFast
                }
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    ColumnLayout {
        id: indicatorColumn
        anchors.centerIn: parent
        spacing: 6
        visible: root.vertical

        Repeater {
            model: 5
            Rectangle {
                required property int index
                readonly property bool activeWorkspace: Hyprland.focusedWorkspace !== null
                    && Hyprland.focusedWorkspace.id === index + 1
                Layout.preferredWidth: 8
                Layout.preferredHeight: activeWorkspace ? 24 : 8
                radius: 4
                color: activeWorkspace ? Theme.accent
                    : (verticalWorkspaceHover.hovered ? Theme.text : Theme.outline)
                HoverHandler { id: verticalWorkspaceHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: Hyprland.dispatch('hl.dsp.focus({ workspace = "'
                        + (index + 1) + '" })')
                }
                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                    duration: Motion.springFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialFast
                }
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }
}
