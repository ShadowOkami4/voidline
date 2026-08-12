import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string value: "rgba(000000ff)"
    property bool enabled: true
    property var presets: [
        "rgba(8fb8acff)", "rgba(9caedbff)", "rgba(c3a5c9ff)",
        "rgba(d0ad87ff)", "rgba(e2b7f4ee)", "rgba(00000050)"
    ]
    signal changed(string value)

    readonly property bool inputValid:
        /^rgba?\([0-9a-fA-F]{6}([0-9a-fA-F]{2})?\)$/.test(editor.text.trim())

    implicitHeight: 112
    color: "transparent"
    opacity: enabled ? 1 : 0.46

    function previewColor(source) {
        const match = String(source || "").match(
            /^rgba?\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\)$/)
        return match ? "#" + match[1] : Theme.danger
    }

    onValueChanged: {
        if (!editor.activeFocus)
            editor.text = value
    }

    ColumnLayout {
        anchors { fill: parent; margins: Metrics.cardPadding }
        spacing: Metrics.labelControlGap

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spaceS

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.titleSubtitleGap
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.textCaption
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: Metrics.controlS
                Layout.preferredHeight: Metrics.controlS
                radius: Metrics.iconContainerRadius
                color: root.previewColor(root.value)
                border.width: Metrics.border
                border.color: Theme.outlineSoft
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.minimumHitSize
            spacing: Metrics.spaceXS

            Repeater {
                model: root.presets
                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: Metrics.controlS
                    Layout.preferredHeight: Metrics.controlS
                    radius: Metrics.iconContainerRadius
                    color: root.previewColor(modelData)
                    border.width: String(modelData).toLowerCase()
                        === root.value.toLowerCase() ? Metrics.focusBorder : Metrics.border
                    border.color: String(modelData).toLowerCase()
                        === root.value.toLowerCase() ? Theme.accent : Theme.outlineSoft
                    scale: presetTap.pressed ? 0.92 : 1

                    TapHandler {
                        id: presetTap
                        enabled: root.enabled
                        onTapped: root.changed(String(modelData))
                    }
                    Behavior on scale { NumberAnimation { duration: Motion.instant } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Metrics.buttonRadius
                color: Theme.surfaceLow
                border.width: editor.activeFocus || !root.inputValid
                    ? Metrics.focusBorder : Metrics.border
                border.color: !root.inputValid ? Theme.danger
                    : (editor.activeFocus ? Theme.accent : Theme.outlineSoft)

                TextInput {
                    id: editor
                    anchors {
                        fill: parent
                        leftMargin: Metrics.inputPaddingX
                        rightMargin: applyButton.width + Metrics.spaceS
                    }
                    text: root.value
                    enabled: root.enabled
                    color: Theme.text
                    selectionColor: Theme.accentContainer
                    selectedTextColor: Theme.text
                    font.family: "monospace"
                    font.pixelSize: Metrics.textSupporting
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 18
                    onAccepted: {
                        if (root.inputValid)
                            root.changed(text.trim())
                    }
                }

                IconButton {
                    id: applyButton
                    anchors { right: parent.right; rightMargin: Metrics.spaceXS; verticalCenter: parent.verticalCenter }
                    size: Metrics.minimumHitSize
                    icon: root.inputValid ? "check" : "error"
                    active: root.inputValid && editor.text.trim().toLowerCase()
                        !== root.value.toLowerCase()
                    enabled: root.enabled && root.inputValid
                    accessibleName: I18n.tr("common.apply")
                    onClicked: root.changed(editor.text.trim())
                }
            }
        }
    }
}
