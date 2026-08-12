import QtQuick
import QtQuick.Layouts
import "../core"

FocusScope {
    id: root

    property alias text: input.text
    property string placeholder: I18n.tr("settings.search")
    signal accepted(string text)

    implicitHeight: 54

    Rectangle {
        anchors.fill: parent
        radius: Theme.pillRadius
        color: input.activeFocus ? Theme.groupSurfaceRaised : Theme.groupSurface
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.accent

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 17
            rightMargin: 12
        }
        spacing: 11

        MaterialIcon {
            text: "search"
            size: 21
            color: input.activeFocus ? Theme.accent : Theme.textMuted
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.text
            selectionColor: Theme.accentContainer
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            clip: true
            onAccepted: root.accepted(text)

            Text {
                anchors.fill: parent
                visible: input.text.length === 0 && !input.activeFocus
                text: root.placeholder
                color: Theme.textMuted
                font: input.font
            }
        }

        IconButton {
            visible: input.text.length > 0
            icon: "close"
            accessibleName: I18n.tr("common.clearSearch")
            onClicked: input.text = ""
        }
    }

    TapHandler {
        onTapped: input.forceActiveFocus()
    }
}
