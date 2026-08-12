import QtQuick
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: "tune"
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property string suffix: ""
    property bool enabled: true
    signal changed(real value)

    implicitHeight: Metrics.sliderHeight
    radius: 0
    color: "transparent"
    border.width: 0
    opacity: enabled ? 1 : 0.46

    function snapped(value) {
        const bounded = Math.max(from, Math.min(to, value))
        return Math.round(bounded / Math.max(0.001, step)) * step
    }

    ExpressiveSlider {
        anchors.fill: parent
        enabled: root.enabled
        icon: root.icon
        title: root.title
        subtitle: root.subtitle
        from: root.from
        to: root.to
        value: root.value
        valueText: {
            const displayed = Math.abs(root.step - Math.round(root.step)) < 0.001
                ? Math.round(root.value) : Number(root.value).toFixed(1)
            return displayed + root.suffix
        }
        iconInteractive: false
        onMoved: value => root.changed(root.snapped(value))
    }

    SettingsDivider { }
}
