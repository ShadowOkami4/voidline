import QtQuick
import qs.core
import qs.widgets

// Connected button group: pick one of a few options.
Rectangle {
    id: root

    // [{ value, label }]
    property var options: []
    property var value
    // Preferred width per option; when the group is stretched, options share it.
    property int segmentWidth: 92
    readonly property real seg: (width - 8) / Math.max(1, options.length)
    signal picked(var value)

    implicitWidth: options.length * segmentWidth + 8
    implicitHeight: 40
    radius: height / 2
    color: Theme.surfaceContainerHighest

    Row {
        anchors.fill: parent
        anchors.margins: 4
        Repeater {
            model: root.options
            Pressable {
                id: seg
                required property var modelData
                readonly property bool current: root.value === modelData.value
                width: root.seg
                height: parent.height
                color: current ? Theme.primary : "transparent"
                tint: current ? Theme.inkOnPrimary : Theme.ink
                restRadius: current ? Theme.cornerFull : Theme.cornerS
                Behavior on color { Tint {} }
                onClicked: root.picked(modelData.value)
                Label {
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    font.pixelSize: Theme.textLabel
                    font.weight: Font.DemiBold
                    color: seg.current ? Theme.inkOnPrimary : Theme.inkMuted
                }
            }
        }
    }
}
