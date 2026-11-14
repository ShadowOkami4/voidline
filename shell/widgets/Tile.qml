import QtQuick
import QtQuick.Layouts
import qs.core

// Quick-settings toggle tile. Off: pill on a neutral container.
// On: squarer shape in the primary colour (the expressive shape change
// carries the state, not just the colour).
Pressable {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    // Shows an arrow on the right; clicking it emits more() instead of clicked().
    property bool hasMore: false
    signal more()

    implicitHeight: 64
    color: active ? Theme.primary : Theme.surfaceContainerHighest
    tint: active ? Theme.inkOnPrimary : Theme.ink
    restRadius: active ? Theme.cornerLInc : Theme.cornerFull
    pressedRadius: Theme.cornerL
    Behavior on color { Tint {} }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: root.hasMore ? 50 : 16
        spacing: 12

        MIcon {
            icon: root.icon
            size: 22
            filled: root.active
            color: root.active ? Theme.inkOnPrimary : Theme.ink
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                color: root.active ? Theme.inkOnPrimary : Theme.ink
            }
            Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                font.pixelSize: Theme.textLabel
                color: root.active ? Theme.inkOnPrimary : Theme.inkMuted
                opacity: 0.85
            }
        }
    }

    Rectangle {
        visible: root.hasMore
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: moreArea.pressed ? Theme.cornerM : 20
        color: Theme.alpha(root.active ? Theme.inkOnPrimary : Theme.ink, moreArea.pressed ? 0.22 : (moreArea.containsMouse ? 0.14 : 0.08))
        Behavior on radius { Spring {} }
        MIcon {
            anchors.centerIn: parent
            icon: "chevron_right"
            size: 22
            color: root.active ? Theme.inkOnPrimary : Theme.ink
        }
        MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.more()
        }
    }
}
