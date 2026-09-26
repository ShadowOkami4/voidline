import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

FocusScope {
    id: root

    property alias text: input.text
    property string placeholder: I18n.tr("settings.search")
    // Shows the user's avatar at the end of the field (Android 16 style).
    property bool showAvatar: false
    signal accepted(string text)
    signal avatarClicked

    implicitHeight: Math.round(56 * Metrics.scale)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: input.activeFocus ? Theme.surfaceBright : Theme.surfaceContainerHighest
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.accent

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Metrics.spaceL
            rightMargin: root.showAvatar ? Metrics.spaceS : Metrics.spaceM
        }
        spacing: 11

        MaterialIcon {
            text: "search"
            size: 22
            color: input.activeFocus ? Theme.accent : Theme.textMuted
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.text
            selectionColor: Theme.accentContainer
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.appTextTitle
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

        RoundedImage {
            visible: root.showAvatar
            Layout.preferredWidth: Math.round(40 * Metrics.scale)
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            source: ProfileImageService.avatarSource
            fallbackIcon: "person"
            fallbackColor: Theme.accentContainer
            fallbackIconSize: Math.round(width * 0.55)
            fallbackIconColor: Theme.accentContainerInk

            TapHandler { onTapped: root.avatarClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    TapHandler {
        onTapped: input.forceActiveFocus()
    }
}
