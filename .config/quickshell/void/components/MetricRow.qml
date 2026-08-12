import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string label: ""
    property string value: ""

    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spaceS

        Text {
            id: labelText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.label
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.textSupporting
            elide: Text.ElideRight
        }

        Text {
            id: valueText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.textSupporting
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
        }
    }
}
