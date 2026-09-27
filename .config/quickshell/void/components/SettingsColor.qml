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

    // Collapsed it is a normal list row with the colour as its icon; the
    // swatches and hex field only appear once the row is opened.
    property bool expanded: false
    readonly property int textIndent: Metrics.spaceXL + Math.round(40 * Metrics.scale) + Metrics.spaceM
    readonly property int rowHeight: Metrics.settingRowHeight

    implicitHeight: rowHeight + (expanded ? Metrics.minimumHitSize + Metrics.spaceL : 0)
    color: "transparent"
    opacity: enabled ? 1 : 0.46
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.springFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialFast
        }
    }

    function previewColor(source) {
        const match = String(source || "").match(
            /^rgba?\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\)$/)
        return match ? "#" + match[1] : Theme.danger
    }

    onValueChanged: {
        if (!editor.activeFocus)
            editor.text = value
    }

    Rectangle {
        anchors { fill: headerRow; leftMargin: Metrics.spaceS; rightMargin: Metrics.spaceS }
        radius: Metrics.radiusL
        color: headerHover.hovered && root.enabled ? Theme.withAlpha(Theme.text, 0.06) : "transparent"
    }

    RowLayout {
        id: headerRow
        x: 0
        width: parent.width
        height: root.rowHeight
        spacing: Metrics.spaceM

        Item { Layout.preferredWidth: Metrics.spaceXL - Metrics.spaceM }
        Rectangle {
            Layout.preferredWidth: Math.round(40 * Metrics.scale)
            Layout.preferredHeight: Math.round(40 * Metrics.scale)
            radius: width / 2
            color: root.previewColor(root.value)
            border.width: Metrics.border
            border.color: Theme.outlineSoft
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
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle.length > 0 ? root.subtitle : root.value
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.appTextBody
                elide: Text.ElideRight
            }
        }
        MaterialIcon {
            text: root.expanded ? "expand_less" : "expand_more"
            size: Math.round(24 * Metrics.scale)
            color: Theme.textMuted
        }
        Item { Layout.preferredWidth: Metrics.spaceXL - Metrics.spaceM }

        HoverHandler { id: headerHover; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            enabled: root.enabled
            onTapped: root.expanded = !root.expanded
        }
    }

    Item {
        x: root.textIndent
        y: root.rowHeight
        width: parent.width - root.textIndent - Metrics.spaceXL
        height: Metrics.minimumHitSize
        visible: root.expanded
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.effectsFastDuration } }

        RowLayout {
            anchors.fill: parent
            spacing: Metrics.spaceXS

            Repeater {
                model: root.presets
                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: Math.round(40 * Metrics.scale)
                    Layout.preferredHeight: Math.round(40 * Metrics.scale)
                    radius: width / 2
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
