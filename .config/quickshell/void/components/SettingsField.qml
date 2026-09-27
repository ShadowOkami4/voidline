import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: "edit"
    property string value: ""
    property string placeholder: ""
    property string errorText: ""
    property bool secret: false
    property bool enabled: true
    property bool revealSecret: false
    signal accepted(string value)

    implicitHeight: Math.round((subtitle.length > 0 || errorText.length > 0
        ? 142 : 126) * Metrics.scale)
    radius: 0
    color: "transparent"
    opacity: enabled ? 1 : 0.56

    onValueChanged: {
        if (!field.activeFocus)
            field.text = value
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: Metrics.spaceXL
        }
        spacing: Metrics.spaceS

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spaceM
            Rectangle {
                Layout.preferredWidth: Math.round(40 * Metrics.scale)
                Layout.preferredHeight: Math.round(40 * Metrics.scale)
                radius: width / 2
                color: field.activeFocus ? Theme.accentContainer : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    size: Math.round(24 * Metrics.scale)
                    color: field.activeFocus ? Theme.accent : Theme.textMuted
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.titleSubtitleGap
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextTitle
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.errorText.length > 0 ? root.errorText : root.subtitle
                    color: root.errorText.length > 0 ? Theme.danger : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextCaption
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            // The input lines up with the row text, not the icon.
            Layout.leftMargin: Math.round(40 * Metrics.scale) + Metrics.spaceM
            spacing: Metrics.spaceS

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.controlM
                radius: Metrics.tileRadius
                color: field.activeFocus ? Theme.surfaceHigh : Theme.groupSurfaceRaised
                border.width: field.activeFocus || root.errorText.length > 0
                    ? Metrics.focusBorder : Metrics.border
                border.color: root.errorText.length > 0 ? Theme.danger
                    : (field.activeFocus ? Theme.accent : Theme.outlineSoft)
                clip: true

                TextInput {
                    id: field
                    anchors {
                        left: parent.left
                        right: revealButton.visible ? revealButton.left : parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Metrics.spaceM
                        rightMargin: Metrics.spaceS
                    }
                    text: root.value
                    enabled: root.enabled
                    color: Theme.text
                    selectionColor: Theme.accentContainer
                    selectedTextColor: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextBody
                    echoMode: root.secret && !root.revealSecret
                        ? TextInput.Password : TextInput.Normal
                    clip: true
                    activeFocusOnTab: true
                    onAccepted: root.accepted(text)

                    Text {
                        anchors.fill: parent
                        visible: field.text.length === 0 && !field.activeFocus
                        text: root.placeholder
                        color: Theme.textMuted
                        font: field.font
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    id: revealButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: Metrics.spaceXS
                    }
                    visible: root.secret
                    icon: root.revealSecret ? "visibility_off" : "visibility"
                    accessibleName: root.revealSecret
                        ? I18n.tr("common.hidePassword") : I18n.tr("common.showPassword")
                    onClicked: root.revealSecret = !root.revealSecret
                }

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            Rectangle {
                Layout.preferredWidth: Math.round(78 * Metrics.scale)
                Layout.preferredHeight: Metrics.controlM
                radius: Metrics.buttonRadius
                color: applyTap.pressed ? Theme.accentStrong : Theme.accentContainer
                border.width: Metrics.border
                border.color: Theme.withAlpha(Theme.accent, 0.42)
                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("common.apply")
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextCaption
                    font.weight: Font.Bold
                }
                TapHandler {
                    id: applyTap
                    enabled: root.enabled
                    onTapped: root.accepted(field.text)
                }
                Behavior on color { ColorAnimation { duration: Motion.instant } }
            }
        }
    }

    SettingsDivider { }
}
