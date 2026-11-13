import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// One setting: icon, title, optional description, and a control on the right.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string description: ""
    default property alias control: slot.data

    Layout.fillWidth: true
    Layout.leftMargin: 18
    Layout.rightMargin: 18
    Layout.topMargin: 12
    Layout.bottomMargin: 12
    spacing: 16

    MIcon {
        icon: root.icon
        size: 22
        color: Theme.inkMuted
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Label {
            Layout.fillWidth: true
            text: root.title
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.description
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textLabel
            color: Theme.inkMuted
        }
    }

    Item {
        id: slot
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        Layout.alignment: Qt.AlignVCenter
    }
}
