import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// M3 Expressive segmented list: related items sit in one group with a 2px gap.
// The group's outer corners are large and the inner ones small; SegItem works
// out its own corners from its position.
ColumnLayout {
    id: root

    property string title: ""
    default property alias items: body.data

    Layout.fillWidth: true
    spacing: 10

    Label {
        Layout.leftMargin: 8
        visible: root.title.length > 0
        text: root.title
        font.pixelSize: Theme.textBody
        font.weight: Font.Bold
        color: Theme.primary
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 2
    }
}
