import QtQuick
import QtQuick.Layouts
import qs.core
import qs.widgets

// A SegItem with a value read-out and a full-width slider underneath.
SegItem {
    id: root

    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property string suffix: ""
    property int decimals: 0
    signal changed(real value)

    Label {
        text: root.value.toFixed(root.decimals) + root.suffix
        font.pixelSize: Theme.textTitle + 2
        font.weight: Font.Black
        color: Theme.primary
    }

    extra: ExpSlider {
        Layout.fillWidth: true
        implicitHeight: 36
        value: (root.value - root.from) / (root.to - root.from)
        onMoved: v => {
            const raw = root.from + v * (root.to - root.from)
            const snapped = Math.round(raw / root.step) * root.step
            if (Math.abs(snapped - root.value) > 0.0001) root.changed(snapped)
        }
    }
}
