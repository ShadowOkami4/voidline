import QtQuick
import qs.core
import qs.services
import qs.widgets

// Network / volume / battery cluster. Opens quick settings.
Pressable {
    id: root

    required property var screen
    property bool contained: true

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 30
    selected: Shell.panel === "quick"
    color: selected ? Theme.primaryContainer : (contained ? Theme.surfaceContainerHigh : "transparent")
    restRadius: selected ? Theme.cornerM : Theme.cornerFull
    Behavior on color { Tint {} }

    readonly property color ink: selected ? Theme.inkOnPrimaryContainer : Theme.inkMuted

    onClicked: Shell.toggle("quick", screen)
    onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 9

        MIcon { icon: Network.icon; size: 17; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
        MIcon { icon: Audio.icon; size: 17; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
        Row {
            visible: Battery.available
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            MIcon {
                icon: Battery.icon
                size: 17
                filled: true
                color: Battery.percent <= 15 && !Battery.charging ? Theme.error : root.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                text: Battery.percent + "%"
                font.pixelSize: Theme.textLabel
                font.weight: Font.DemiBold
                color: root.ink
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
