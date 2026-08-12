import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool showToggle: false
    property bool toggleChecked: false
    property bool toggleEnabled: true
    signal back
    signal toggled(bool checked)

    implicitHeight: subtitle.length > 0 ? 72 : 58

    RowLayout {
        anchors.fill: parent
        spacing: 12

        IconButton {
            icon: "arrow_back"
            accessibleName: "Back"
            size: 42
            onClicked: root.back()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 28
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        ToggleSwitch {
            visible: root.showToggle
            checked: root.toggleChecked
            enabled: root.toggleEnabled
            onToggled: checked => root.toggled(checked)
        }
    }
}
