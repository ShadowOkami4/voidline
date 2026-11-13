import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// Titled card that groups related settings.
ColumnLayout {
    id: root

    property string title: ""
    default property alias rows: body.data

    Layout.fillWidth: true
    spacing: 8

    Label {
        Layout.leftMargin: 6
        visible: root.title.length > 0
        text: root.title
        font.pixelSize: Theme.textLabel
        font.weight: Font.Bold
        color: Theme.primary
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight
        radius: Theme.cornerXL
        color: Theme.surfaceContainer

        ColumnLayout {
            id: body
            width: parent.width
            spacing: 0
        }
    }
}
