import QtQuick
import qs.core

// A small field for a time of day ("22:00"). Accepts 22, 2200, 22.00 and
// 22:00; anything else snaps back to what it was.
Rectangle {
    id: root

    property string value: "00:00"
    signal picked(string value)

    function tidy(text) {
        const m = String(text).trim().match(/^(\d{1,2})(?:[:. ]?(\d{2}))?$/)
        if (!m || Number(m[1]) > 23 || Number(m[2] || 0) > 59) return ""
        return (Number(m[1]) < 10 ? "0" : "") + Number(m[1]) + ":" + (m[2] || "00")
    }

    implicitWidth: 92
    implicitHeight: 42
    radius: input.activeFocus ? Theme.cornerM : height / 2
    color: Theme.surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 0
    border.color: Theme.primary
    Behavior on radius { Spring {} }

    onValueChanged: if (!input.activeFocus) input.text = value

    TextInput {
        id: input
        anchors.fill: parent
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        maximumLength: 5
        text: root.value
        color: Theme.ink
        selectionColor: Theme.primaryContainer
        font.family: Theme.font
        font.pixelSize: Theme.textBody
        font.weight: Font.DemiBold
        onActiveFocusChanged: if (activeFocus) selectAll()
        onEditingFinished: {
            const t = root.tidy(text)
            if (t.length > 0 && t !== root.value) root.picked(t)
            text = t.length > 0 ? t : root.value
        }
    }
}
